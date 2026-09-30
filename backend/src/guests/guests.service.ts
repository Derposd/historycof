import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, eq, isNull } from 'drizzle-orm';
import { DB, Db } from '../db/database.module';
import { chatMessages, consents, deviceTokens, feedback, guests, refreshTokens } from '../db/schema';
import { LEGAL_VERSION } from '../legal/documents';
import { StorageService } from '../storage/storage.service';

/** Откуда дано согласие — для журнала (доказательство получения согласия). */
export interface ConsentContext {
  ip?: string | null;
  userAgent?: string | null;
}

export interface GuestProfile {
  id: string;
  phone: string;
  name: string | null;
  birthday: string | null;
  /** Новости и акции push-уведомлениями — есть действующее согласие на рекламу. */
  pushNewsEnabled: boolean;
  consentVersion: string | null;
  /** true — тексты документов обновились, нужно заново получить согласие на обработку ПДн. */
  consentRequired: boolean;
  /** Текущая версия юридических документов. */
  legalVersion: string;
  createdAt: string;
}

@Injectable()
export class GuestsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly storage: StorageService,
  ) {}

  /** Записывает согласие в журнал; прежнее действующее согласие того же вида закрывается. */
  async recordConsent(guestId: string, kind: 'pd' | 'marketing', ctx: ConsentContext = {}): Promise<void> {
    const now = new Date();
    await this.db
      .update(consents)
      .set({ revokedAt: now })
      .where(and(eq(consents.guestId, guestId), eq(consents.kind, kind), isNull(consents.revokedAt)));
    await this.db.insert(consents).values({
      guestId,
      kind,
      version: LEGAL_VERSION,
      grantedAt: now,
      ip: ctx.ip?.slice(0, 64) ?? null,
      userAgent: ctx.userAgent?.slice(0, 300) ?? null,
    });
  }

  async revokeConsent(guestId: string, kind: 'pd' | 'marketing'): Promise<void> {
    await this.db
      .update(consents)
      .set({ revokedAt: new Date() })
      .where(and(eq(consents.guestId, guestId), eq(consents.kind, kind), isNull(consents.revokedAt)));
  }

  async getProfile(guestId: string): Promise<GuestProfile> {
    const [g] = await this.db
      .select()
      .from(guests)
      .where(and(eq(guests.id, guestId), isNull(guests.deletedAt)));
    if (!g || !g.phone) throw new NotFoundException('Профиль не найден');
    return {
      id: g.id,
      phone: g.phone,
      name: g.name,
      birthday: g.birthday,
      pushNewsEnabled: g.pushNewsEnabled,
      consentVersion: g.consentVersion,
      consentRequired: g.consentVersion !== LEGAL_VERSION,
      legalVersion: LEGAL_VERSION,
      createdAt: g.createdAt.toISOString(),
    };
  }

  async update(
    guestId: string,
    patch: { name?: string | null; birthday?: string | null; pushNewsEnabled?: boolean },
    ctx: ConsentContext = {},
  ): Promise<GuestProfile> {
    const before = await this.getProfile(guestId);
    const values: Partial<typeof guests.$inferInsert> = {};
    if (patch.name !== undefined) values.name = patch.name?.trim() || null;
    if (patch.birthday !== undefined) values.birthday = patch.birthday || null;
    if (patch.pushNewsEnabled !== undefined) values.pushNewsEnabled = patch.pushNewsEnabled;
    if (Object.keys(values).length) {
      await this.db
        .update(guests)
        .set(values)
        .where(and(eq(guests.id, guestId), isNull(guests.deletedAt)));
    }
    // Включение «Новостей и акций» — это согласие на рекламу (38-ФЗ ст. 18), выключение — его отзыв
    if (patch.pushNewsEnabled === true && !before.pushNewsEnabled) await this.recordConsent(guestId, 'marketing', ctx);
    if (patch.pushNewsEnabled === false && before.pushNewsEnabled) await this.revokeConsent(guestId, 'marketing');
    return this.getProfile(guestId);
  }

  /** Повторное согласие на обработку ПДн после обновления документов. */
  async acceptConsent(guestId: string, ctx: ConsentContext = {}): Promise<GuestProfile> {
    await this.db
      .update(guests)
      .set({ consentVersion: LEGAL_VERSION, consentAt: new Date() })
      .where(eq(guests.id, guestId));
    await this.recordConsent(guestId, 'pd', ctx);
    return this.getProfile(guestId);
  }

  /**
   * Удаление аккаунта (требование App Store / Google Play и 152-ФЗ — отзыв согласия).
   * Персональные данные обезличиваются; обращения остаются без привязки к телефону.
   * Данные в iiko не удаляются автоматически — это отдельная процедура на стороне кофейни.
   */
  async deleteAccount(guestId: string): Promise<void> {
    // Фото из обращений гостя удаляем из хранилища — на них могут быть персональные данные
    const photos = await this.db
      .select({ url: feedback.photoUrl })
      .from(feedback)
      .where(eq(feedback.guestId, guestId));
    await this.db.transaction(async (tx) => {
      await tx
        .update(guests)
        .set({
          phone: null,
          name: null,
          birthday: null,
          iikoCustomerId: null,
          iikoCardTrack: null,
          pushNewsEnabled: false,
          deletedAt: new Date(),
        })
        .where(eq(guests.id, guestId));
      // Обращения остаются обезличенными: без телефона и фото
      await tx.update(feedback).set({ contactPhone: null, photoUrl: null }).where(eq(feedback.guestId, guestId));
      // Переписка в чате удаляется целиком
      await tx.delete(chatMessages).where(eq(chatMessages.guestId, guestId));
      // Согласия отозваны (строки журнала остаются как подтверждение, пока жива запись)
      await tx
        .update(consents)
        .set({ revokedAt: new Date() })
        .where(and(eq(consents.guestId, guestId), isNull(consents.revokedAt)));
      await tx.delete(deviceTokens).where(eq(deviceTokens.guestId, guestId));
      await tx
        .update(refreshTokens)
        .set({ revokedAt: new Date() })
        .where(
          and(
            eq(refreshTokens.subjectType, 'guest'),
            eq(refreshTokens.subjectId, guestId),
            isNull(refreshTokens.revokedAt),
          ),
        );
    });
    for (const p of photos) await this.storage.deleteByUrl(p.url);
  }

  async registerDevice(token: string, platform: 'android' | 'ios' | 'web', guestId: string | null): Promise<void> {
    await this.db
      .insert(deviceTokens)
      .values({ token, platform, guestId })
      .onConflictDoUpdate({ target: deviceTokens.token, set: { platform, guestId, updatedAt: new Date() } });
  }

  async unregisterDevice(token: string): Promise<void> {
    await this.db.delete(deviceTokens).where(eq(deviceTokens.token, token));
  }

  async deviceTokensOf(guestId: string): Promise<string[]> {
    const rows = await this.db
      .select({ token: deviceTokens.token })
      .from(deviceTokens)
      .where(eq(deviceTokens.guestId, guestId));
    return rows.map((r) => r.token);
  }

  /** Устройства гостей с действующим согласием на рекламу — адресаты новостей и акций. */
  async marketingDeviceTokens(): Promise<string[]> {
    const rows = await this.db
      .select({ token: deviceTokens.token })
      .from(deviceTokens)
      .innerJoin(guests, eq(guests.id, deviceTokens.guestId))
      .where(and(eq(guests.pushNewsEnabled, true), isNull(guests.deletedAt)));
    return rows.map((r) => r.token);
  }
}
