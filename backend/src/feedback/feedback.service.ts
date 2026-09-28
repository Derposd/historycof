import { BadRequestException, Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { and, count, desc, eq, SQL } from 'drizzle-orm';
import { DB, Db } from '../db/database.module';
import { Feedback, feedback, guests } from '../db/schema';
import { normalizeRuPhone } from '../common/phone';
import { PushService } from '../push/push.service';
import { GuestsService } from '../guests/guests.service';
import { StorageService } from '../storage/storage.service';
import { FeedbackNotifier, FEEDBACK_TYPE_LABEL } from './notifiers/feedback-notifier';

export type FeedbackType = Feedback['type'];
export type FeedbackStatus = Feedback['status'];

export interface GuestFeedbackView {
  id: string;
  type: FeedbackType;
  message: string;
  photoUrl: string | null;
  status: FeedbackStatus;
  reply: string | null;
  createdAt: string;
  answeredAt: string | null;
}

const toGuestView = (f: Feedback): GuestFeedbackView => ({
  id: f.id,
  type: f.type,
  message: f.message,
  photoUrl: f.photoUrl,
  status: f.status,
  reply: f.reply,
  createdAt: f.createdAt.toISOString(),
  answeredAt: f.answeredAt?.toISOString() ?? null,
});

@Injectable()
export class FeedbackService {
  private readonly logger = new Logger(FeedbackService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly storage: StorageService,
    private readonly notifier: FeedbackNotifier,
    private readonly push: PushService,
    private readonly guests: GuestsService,
  ) {}

  async create(input: {
    guestId: string | null;
    type: FeedbackType;
    message: string;
    contactPhone?: string | null;
    photo?: { buffer: Buffer; mimetype: string; size: number };
  }): Promise<GuestFeedbackView> {
    let contactPhone: string | null = null;
    if (input.contactPhone) {
      contactPhone = normalizeRuPhone(input.contactPhone);
      if (!contactPhone) throw new BadRequestException({ error: 'phone_invalid', message: 'Проверьте номер телефона' });
    }
    const photoUrl = input.photo ? await this.storage.saveImage(input.photo, 'feedback') : null;

    const [row] = await this.db
      .insert(feedback)
      .values({
        guestId: input.guestId,
        type: input.type,
        message: input.message.trim(),
        contactPhone,
        photoUrl,
      })
      .returning();

    let guestPhone: string | null = null;
    if (input.guestId) {
      const [g] = await this.db.select({ phone: guests.phone }).from(guests).where(eq(guests.id, input.guestId));
      guestPhone = g?.phone ?? null;
    }
    // Не блокируем ответ гостю на внешних каналах.
    void this.notifier.notify(row, guestPhone).catch((e) => this.logger.error(String(e)));

    return toGuestView(row);
  }

  async listMine(guestId: string): Promise<GuestFeedbackView[]> {
    const rows = await this.db
      .select()
      .from(feedback)
      .where(eq(feedback.guestId, guestId))
      .orderBy(desc(feedback.createdAt))
      .limit(100);
    return rows.map(toGuestView);
  }

  // ─── Админка ───

  async list(filter: { status?: FeedbackStatus; type?: FeedbackType; page: number; pageSize: number }) {
    const conds: SQL[] = [];
    if (filter.status) conds.push(eq(feedback.status, filter.status));
    if (filter.type) conds.push(eq(feedback.type, filter.type));
    const where = conds.length ? and(...conds) : undefined;

    const [rows, [{ total }]] = await Promise.all([
      this.db
        .select({ f: feedback, guestPhone: guests.phone, guestName: guests.name })
        .from(feedback)
        .leftJoin(guests, eq(guests.id, feedback.guestId))
        .where(where)
        .orderBy(desc(feedback.createdAt))
        .limit(filter.pageSize)
        .offset(filter.page * filter.pageSize),
      this.db.select({ total: count() }).from(feedback).where(where),
    ]);
    return {
      items: rows.map((r) => ({ ...r.f, guestPhone: r.guestPhone, guestName: r.guestName })),
      total,
    };
  }

  /** Открытие обращения в админке переводит его из «отправлено» в «просмотрено». */
  async openForStaff(id: string) {
    const [row] = await this.db
      .select({ f: feedback, guestPhone: guests.phone, guestName: guests.name })
      .from(feedback)
      .leftJoin(guests, eq(guests.id, feedback.guestId))
      .where(eq(feedback.id, id));
    if (!row) throw new NotFoundException('Обращение не найдено');
    let f = row.f;
    if (f.status === 'sent') {
      [f] = await this.db
        .update(feedback)
        .set({ status: 'viewed', viewedAt: new Date() })
        .where(eq(feedback.id, id))
        .returning();
    }
    return { ...f, guestPhone: row.guestPhone, guestName: row.guestName };
  }

  async answer(id: string, staffId: string, patch: { reply?: string; status?: FeedbackStatus }) {
    const [current] = await this.db.select().from(feedback).where(eq(feedback.id, id));
    if (!current) throw new NotFoundException('Обращение не найдено');

    const values: Partial<typeof feedback.$inferInsert> = {};
    const reply = patch.reply?.trim();
    if (reply) {
      Object.assign(values, { reply, status: 'answered', answeredAt: new Date(), answeredBy: staffId });
    } else if (patch.status) {
      values.status = patch.status;
      if (patch.status !== 'sent' && !current.viewedAt) values.viewedAt = new Date();
    }
    if (!Object.keys(values).length) return current;

    const [updated] = await this.db.update(feedback).set(values).where(eq(feedback.id, id)).returning();

    if (reply && updated.guestId) {
      const tokens = await this.guests.deviceTokensOf(updated.guestId);
      await this.push
        .sendToTokens(tokens, {
          title: 'Ответ от History Coffee',
          body: `На ваше обращение («${FEEDBACK_TYPE_LABEL[updated.type]}») пришёл ответ`,
          data: { type: 'feedback', id: updated.id },
        })
        .catch((e) => this.logger.error(`push об ответе на ${id}: ${String(e)}`));
    }
    return updated;
  }

  async stats() {
    const rows = await this.db
      .select({ status: feedback.status, type: feedback.type, n: count() })
      .from(feedback)
      .groupBy(feedback.status, feedback.type);
    return rows;
  }
}
