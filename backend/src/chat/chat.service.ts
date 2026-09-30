import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { and, count, desc, eq, isNull, sql } from 'drizzle-orm';
import { DB, Db } from '../db/database.module';
import { ChatMessage, chatMessages, guests } from '../db/schema';
import { GuestsService } from '../guests/guests.service';
import { PushService } from '../push/push.service';

export interface ChatMessageView {
  id: string;
  /** true — написала кофейня, false — гость */
  fromStaff: boolean;
  text: string;
  createdAt: string;
  readAt: string | null;
}

export interface ChatThreadSummary {
  guestId: string;
  guestName: string | null;
  guestPhone: string | null;
  lastText: string;
  lastFromStaff: boolean;
  lastAt: string;
  /** Сообщения гостя, которые ещё не прочитал никто из сотрудников */
  unread: number;
}

const HISTORY_LIMIT = 300;

const toView = (m: ChatMessage): ChatMessageView => ({
  id: m.id,
  fromStaff: m.sender === 'staff',
  text: m.text,
  createdAt: m.createdAt.toISOString(),
  readAt: m.readAt?.toISOString() ?? null,
});

/**
 * Чат гостя с кофейней. У гостя один диалог; отвечает любой сотрудник из админки.
 * Уведомление гостю об ответе — служебное (не реклама) и без текста сообщения:
 * в push-сервис не передаём содержание переписки.
 */
@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly guests: GuestsService,
    private readonly push: PushService,
  ) {}

  private async history(guestId: string): Promise<ChatMessageView[]> {
    const rows = await this.db
      .select()
      .from(chatMessages)
      .where(eq(chatMessages.guestId, guestId))
      .orderBy(desc(chatMessages.createdAt))
      .limit(HISTORY_LIMIT);
    return rows.reverse().map(toView);
  }

  /** Отмечает прочитанными сообщения другой стороны. */
  private async markRead(guestId: string, sender: 'guest' | 'staff') {
    await this.db
      .update(chatMessages)
      .set({ readAt: new Date() })
      .where(and(eq(chatMessages.guestId, guestId), eq(chatMessages.sender, sender), isNull(chatMessages.readAt)));
  }

  // ─── Гость ───

  async guestThread(guestId: string): Promise<ChatMessageView[]> {
    await this.markRead(guestId, 'staff');
    return this.history(guestId);
  }

  async guestSend(guestId: string, text: string): Promise<ChatMessageView> {
    const [row] = await this.db
      .insert(chatMessages)
      .values({ guestId, sender: 'guest', text: text.trim() })
      .returning();
    return toView(row);
  }

  async guestUnread(guestId: string): Promise<number> {
    const [{ n }] = await this.db
      .select({ n: count() })
      .from(chatMessages)
      .where(and(eq(chatMessages.guestId, guestId), eq(chatMessages.sender, 'staff'), isNull(chatMessages.readAt)));
    return n;
  }

  // ─── Админка ───

  /** Диалоги: последний ответ сверху, у каждого — последнее сообщение и число непрочитанных. */
  async threads(): Promise<ChatThreadSummary[]> {
    const res = await this.db.execute<{
      guest_id: string;
      name: string | null;
      phone: string | null;
      text: string;
      sender: 'guest' | 'staff';
      created_at: Date;
      unread: string;
    }>(sql`
      select distinct on (m.guest_id)
        m.guest_id, g.name, g.phone, m.text, m.sender, m.created_at,
        (select count(*) from ${chatMessages} u
          where u.guest_id = m.guest_id and u.sender = 'guest' and u.read_at is null) as unread
      from ${chatMessages} m
      join ${guests} g on g.id = m.guest_id and g.deleted_at is null
      order by m.guest_id, m.created_at desc
    `);
    return res.rows
      .map((r) => ({
        guestId: r.guest_id,
        guestName: r.name,
        guestPhone: r.phone,
        lastText: r.text,
        lastFromStaff: r.sender === 'staff',
        lastAt: new Date(r.created_at).toISOString(),
        unread: Number(r.unread),
      }))
      .sort((a, b) => b.lastAt.localeCompare(a.lastAt))
      .slice(0, 200);
  }

  async staffUnread(): Promise<number> {
    const [{ n }] = await this.db
      .select({ n: count() })
      .from(chatMessages)
      .innerJoin(guests, and(eq(guests.id, chatMessages.guestId), isNull(guests.deletedAt)))
      .where(and(eq(chatMessages.sender, 'guest'), isNull(chatMessages.readAt)));
    return n;
  }

  private async activeGuest(guestId: string) {
    const [g] = await this.db
      .select({ id: guests.id, name: guests.name, phone: guests.phone })
      .from(guests)
      .where(and(eq(guests.id, guestId), isNull(guests.deletedAt)));
    if (!g) throw new NotFoundException('Гость не найден или удалил аккаунт');
    return g;
  }

  async staffThread(guestId: string) {
    const guest = await this.activeGuest(guestId);
    await this.markRead(guestId, 'guest');
    return { guest, messages: await this.history(guestId) };
  }

  async staffSend(guestId: string, staffId: string, text: string): Promise<ChatMessageView> {
    await this.activeGuest(guestId);
    const [row] = await this.db
      .insert(chatMessages)
      .values({ guestId, sender: 'staff', staffId, text: text.trim() })
      .returning();
    // Отвечая, сотрудник видел переписку — сообщения гостя считаем прочитанными
    await this.markRead(guestId, 'guest');

    const tokens = await this.guests.deviceTokensOf(guestId);
    void this.push
      .sendToTokens(tokens, {
        title: 'History Coffee',
        body: 'Новое сообщение в чате',
        data: { type: 'chat' },
      })
      .catch((e) => this.logger.error(`push о сообщении в чате: ${String(e)}`));
    return toView(row);
  }
}
