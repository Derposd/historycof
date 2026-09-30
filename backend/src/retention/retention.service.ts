import { Inject, Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import { and, isNotNull, isNull, lt, or } from 'drizzle-orm';
import { DB, Db } from '../db/database.module';
import { chatMessages, feedback, guests, otpCodes, refreshTokens } from '../db/schema';
import { GuestsService } from '../guests/guests.service';
import { StorageService } from '../storage/storage.service';

const DAY = 86_400_000;
const YEAR = 365 * DAY;

/**
 * Сроки хранения персональных данных (152-ФЗ ст. 5 ч. 7 — хранить не дольше, чем требуют цели;
 * сроки описаны в политике, раздел 9). Раз в сутки удаляет:
 * - коды подтверждения старше суток;
 * - просроченные и отозванные токены входа старше 30 дней;
 * - обращения старше 3 лет (с фото) и сообщения чата старше 3 лет;
 * - аккаунты, которыми не пользовались 3 года.
 */
@Injectable()
export class RetentionService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger(RetentionService.name);
  private timer?: NodeJS.Timeout;

  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly guests: GuestsService,
    private readonly storage: StorageService,
  ) {}

  onApplicationBootstrap() {
    if (process.env.NODE_ENV === 'test') return;
    // Первый проход через минуту после старта, дальше — раз в сутки
    this.timer = setTimeout(() => void this.tick(), 60_000);
  }

  onModuleDestroy() {
    if (this.timer) clearTimeout(this.timer);
  }

  private async tick() {
    try {
      await this.run();
    } catch (e) {
      this.logger.error(`Очистка по срокам хранения не удалась: ${String(e)}`);
    }
    this.timer = setTimeout(() => void this.tick(), DAY);
  }

  async run(now = new Date()) {
    const otp = await this.db
      .delete(otpCodes)
      .where(lt(otpCodes.createdAt, new Date(now.getTime() - DAY)))
      .returning({ id: otpCodes.id });

    const monthAgo = new Date(now.getTime() - 30 * DAY);
    const tokens = await this.db
      .delete(refreshTokens)
      .where(
        or(
          lt(refreshTokens.expiresAt, monthAgo),
          and(isNotNull(refreshTokens.revokedAt), lt(refreshTokens.revokedAt, monthAgo)),
        ),
      )
      .returning({ id: refreshTokens.id });

    const threeYearsAgo = new Date(now.getTime() - 3 * YEAR);
    const oldFeedback = await this.db
      .delete(feedback)
      .where(lt(feedback.createdAt, threeYearsAgo))
      .returning({ photoUrl: feedback.photoUrl });
    for (const f of oldFeedback) await this.storage.deleteByUrl(f.photoUrl);
    const oldChat = await this.db
      .delete(chatMessages)
      .where(lt(chatMessages.createdAt, threeYearsAgo))
      .returning({ id: chatMessages.id });

    const idle = await this.db
      .select({ id: guests.id })
      .from(guests)
      .where(and(isNull(guests.deletedAt), lt(guests.lastSeenAt, threeYearsAgo)));
    for (const g of idle) await this.guests.deleteAccount(g.id);

    const total = otp.length + tokens.length + oldFeedback.length + oldChat.length + idle.length;
    if (total) {
      this.logger.log(
        `Сроки хранения: кодов ${otp.length}, токенов ${tokens.length}, обращений ${oldFeedback.length}, сообщений чата ${oldChat.length}, неактивных аккаунтов ${idle.length}`,
      );
    }
    return {
      otp: otp.length,
      tokens: tokens.length,
      feedback: oldFeedback.length,
      chat: oldChat.length,
      idleGuests: idle.length,
    };
  }
}
