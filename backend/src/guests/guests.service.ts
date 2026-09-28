import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, eq, isNull } from 'drizzle-orm';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { DB, Db } from '../db/database.module';
import { deviceTokens, guests, refreshTokens } from '../db/schema';

export interface GuestProfile {
  id: string;
  phone: string;
  name: string | null;
  birthday: string | null;
  pushNewsEnabled: boolean;
  consentVersion: string | null;
  /** true — политика обновилась, нужно повторно запросить согласие. */
  consentRequired: boolean;
  createdAt: string;
}

@Injectable()
export class GuestsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

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
      consentRequired: g.consentVersion !== this.config.privacyPolicyVersion,
      createdAt: g.createdAt.toISOString(),
    };
  }

  async update(
    guestId: string,
    patch: { name?: string | null; birthday?: string | null; pushNewsEnabled?: boolean },
  ): Promise<GuestProfile> {
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
    return this.getProfile(guestId);
  }

  async acceptConsent(guestId: string): Promise<GuestProfile> {
    await this.db
      .update(guests)
      .set({ consentVersion: this.config.privacyPolicyVersion, consentAt: new Date() })
      .where(eq(guests.id, guestId));
    return this.getProfile(guestId);
  }

  /**
   * Удаление аккаунта (требование App Store / Google Play и 152-ФЗ — отзыв согласия).
   * Персональные данные обезличиваются; обращения остаются без привязки к телефону.
   * Данные в iiko не удаляются автоматически — это отдельная процедура на стороне кофейни.
   */
  async deleteAccount(guestId: string): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx
        .update(guests)
        .set({
          phone: null,
          name: null,
          birthday: null,
          iikoCustomerId: null,
          iikoCardTrack: null,
          deletedAt: new Date(),
        })
        .where(eq(guests.id, guestId));
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
}
