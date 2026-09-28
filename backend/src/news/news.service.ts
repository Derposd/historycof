import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { and, desc, eq, lt, sql } from 'drizzle-orm';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { DB, Db } from '../db/database.module';
import { NewsPost, newsPosts } from '../db/schema';
import { PushService } from '../push/push.service';

export interface NewsInput {
  title: string;
  body: string;
  imageUrl?: string | null;
  pinned?: boolean;
}

export interface PublicNews {
  id: string;
  title: string;
  body: string;
  imageUrl: string | null;
  pinned: boolean;
  publishedAt: string;
}

const toPublic = (p: NewsPost): PublicNews => ({
  id: p.id,
  title: p.title,
  body: p.body,
  imageUrl: p.imageUrl,
  pinned: p.pinned,
  publishedAt: (p.publishedAt ?? p.createdAt).toISOString(),
});

@Injectable()
export class NewsService {
  private readonly logger = new Logger(NewsService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly push: PushService,
  ) {}

  /**
   * Лента для приложения: закреплённые посты — только на первой странице, дальше
   * хронология по publishedAt с курсором `before` (ISO-дата последнего поста).
   */
  async feed(limit: number, before?: string): Promise<{ items: PublicNews[]; nextBefore: string | null }> {
    const published = eq(newsPosts.status, 'published');
    const pinned = before
      ? []
      : await this.db
          .select()
          .from(newsPosts)
          .where(and(published, eq(newsPosts.pinned, true)))
          .orderBy(desc(newsPosts.publishedAt));

    const cursor = before ? new Date(before) : null;
    const rows = await this.db
      .select()
      .from(newsPosts)
      .where(
        and(
          published,
          eq(newsPosts.pinned, false),
          cursor && !Number.isNaN(cursor.getTime()) ? lt(newsPosts.publishedAt, cursor) : undefined,
        ),
      )
      .orderBy(desc(newsPosts.publishedAt), desc(newsPosts.id))
      .limit(limit + 1);

    const hasMore = rows.length > limit;
    const page = rows.slice(0, limit);
    return {
      items: [...pinned, ...page].map(toPublic),
      nextBefore: hasMore ? page[page.length - 1].publishedAt!.toISOString() : null,
    };
  }

  async getPublished(id: string): Promise<PublicNews> {
    const [p] = await this.db
      .select()
      .from(newsPosts)
      .where(and(eq(newsPosts.id, id), eq(newsPosts.status, 'published')));
    if (!p) throw new NotFoundException('Новость не найдена');
    return toPublic(p);
  }

  // ─── Админка ───

  listAll(status?: 'draft' | 'published'): Promise<NewsPost[]> {
    return this.db
      .select()
      .from(newsPosts)
      .where(status ? eq(newsPosts.status, status) : undefined)
      .orderBy(desc(newsPosts.pinned), sql`coalesce(${newsPosts.publishedAt}, ${newsPosts.createdAt}) desc`);
  }

  async get(id: string): Promise<NewsPost> {
    const [p] = await this.db.select().from(newsPosts).where(eq(newsPosts.id, id));
    if (!p) throw new NotFoundException('Новость не найдена');
    return p;
  }

  async create(input: NewsInput, authorId: string): Promise<NewsPost> {
    const [p] = await this.db
      .insert(newsPosts)
      .values({
        title: input.title.trim(),
        body: input.body.trim(),
        imageUrl: input.imageUrl ?? null,
        pinned: input.pinned ?? false,
        authorId,
      })
      .returning();
    return p;
  }

  async update(id: string, input: Partial<NewsInput>): Promise<NewsPost> {
    const values: Partial<typeof newsPosts.$inferInsert> = {};
    if (input.title !== undefined) values.title = input.title.trim();
    if (input.body !== undefined) values.body = input.body.trim();
    if (input.imageUrl !== undefined) values.imageUrl = input.imageUrl;
    if (input.pinned !== undefined) values.pinned = input.pinned;
    const [p] = await this.db.update(newsPosts).set(values).where(eq(newsPosts.id, id)).returning();
    if (!p) throw new NotFoundException('Новость не найдена');
    return p;
  }

  async remove(id: string): Promise<void> {
    const res = await this.db.delete(newsPosts).where(eq(newsPosts.id, id)).returning({ id: newsPosts.id });
    if (!res.length) throw new NotFoundException('Новость не найдена');
  }

  /**
   * Публикация. Push отправляется максимум один раз на пост (pushedAt), чтобы
   * повторная публикация после правки опечатки не будила подписчиков снова.
   */
  async publish(id: string, notify: boolean): Promise<NewsPost> {
    const current = await this.get(id);
    const [p] = await this.db
      .update(newsPosts)
      .set({ status: 'published', publishedAt: current.publishedAt ?? new Date() })
      .where(eq(newsPosts.id, id))
      .returning();

    if (notify && !p.pushedAt) {
      try {
        await this.push.sendToTopic(this.config.push.newsTopic, {
          title: p.title,
          body: excerpt(p.body, 140),
          imageUrl: p.imageUrl ?? undefined,
          data: { type: 'news', id: p.id },
        });
        const [pushed] = await this.db
          .update(newsPosts)
          .set({ pushedAt: new Date() })
          .where(eq(newsPosts.id, id))
          .returning();
        return pushed;
      } catch (e) {
        // Пост уже опубликован — не откатываем из-за сбоя FCM, админ может повторить.
        this.logger.error(`Не удалось отправить push для новости ${id}: ${(e as Error).message}`);
      }
    }
    return p;
  }

  async unpublish(id: string): Promise<NewsPost> {
    const [p] = await this.db
      .update(newsPosts)
      .set({ status: 'draft' })
      .where(eq(newsPosts.id, id))
      .returning();
    if (!p) throw new NotFoundException('Новость не найдена');
    return p;
  }
}

export function excerpt(text: string, max: number): string {
  const flat = text.replace(/\s+/g, ' ').trim();
  if (flat.length <= max) return flat;
  const cut = flat.slice(0, max - 1);
  if (flat.charAt(cut.length) === ' ') return `${cut.trimEnd()}…`; // разрез ровно по границе слова
  const lastSpace = cut.lastIndexOf(' ');
  return `${(lastSpace > max * 0.6 ? cut.slice(0, lastSpace) : cut).trimEnd()}…`;
}
