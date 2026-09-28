import { HttpException, HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import { and, desc, eq, gt, isNull } from 'drizzle-orm';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { DB, Db } from '../db/database.module';
import { otpCodes } from '../db/schema';
import { hmacSha256, randomDigits, safeEqualHex } from '../common/crypto';
import { maskPhone } from '../common/phone';
import { SMS_PROVIDER, SmsProvider } from './sms/sms.provider';

export const OTP_LENGTH = 4;

export class OtpError extends HttpException {
  constructor(
    public readonly code: 'otp_cooldown' | 'otp_rate_limited' | 'otp_invalid' | 'otp_expired' | 'otp_attempts',
    message: string,
    status: HttpStatus,
    extra: Record<string, unknown> = {},
  ) {
    super({ statusCode: status, error: code, message, ...extra }, status);
  }
}

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
  ) {}

  private hash(phone: string, code: string): string {
    return hmacSha256(this.config.otp.secret, `${phone}:${code}`);
  }

  private isReviewPhone(phone: string): boolean {
    return !!this.config.otp.reviewPhone && !!this.config.otp.reviewCode && phone === this.config.otp.reviewPhone;
  }

  /** Отправляет код. Возвращает, через сколько секунд можно запросить повторно. */
  async request(phone: string, now = new Date()): Promise<{ resendInSec: number; ttlSec: number }> {
    const { resendCooldownSec, maxPerHour, ttlSec } = this.config.otp;

    const hourAgo = new Date(now.getTime() - 3600_000);
    const recent = await this.db
      .select({ createdAt: otpCodes.createdAt })
      .from(otpCodes)
      .where(and(eq(otpCodes.phone, phone), gt(otpCodes.createdAt, hourAgo)))
      .orderBy(desc(otpCodes.createdAt));

    if (recent.length > 0) {
      const sinceLast = (now.getTime() - recent[0].createdAt.getTime()) / 1000;
      if (sinceLast < resendCooldownSec) {
        const wait = Math.ceil(resendCooldownSec - sinceLast);
        throw new OtpError('otp_cooldown', `Повторно запросить код можно через ${wait} с`, HttpStatus.TOO_MANY_REQUESTS, {
          resendInSec: wait,
        });
      }
    }
    if (recent.length >= maxPerHour) {
      throw new OtpError(
        'otp_rate_limited',
        'Слишком много запросов кода. Попробуйте через час',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const code = this.isReviewPhone(phone) ? this.config.otp.reviewCode! : randomDigits(OTP_LENGTH);
    await this.db.insert(otpCodes).values({
      phone,
      codeHash: this.hash(phone, code),
      expiresAt: new Date(now.getTime() + ttlSec * 1000),
      createdAt: now,
    });

    if (!this.isReviewPhone(phone)) {
      await this.sms.send(phone, `History Coffee: код для входа ${code}. Никому его не сообщайте.`);
    }
    this.logger.log(`OTP отправлен на ${maskPhone(phone)}`);
    return { resendInSec: resendCooldownSec, ttlSec };
  }

  /** Проверяет код. Бросает OtpError при ошибке, иначе помечает код использованным. */
  async verify(phone: string, code: string, now = new Date()): Promise<void> {
    const [row] = await this.db
      .select()
      .from(otpCodes)
      .where(and(eq(otpCodes.phone, phone), isNull(otpCodes.consumedAt)))
      .orderBy(desc(otpCodes.createdAt))
      .limit(1);

    if (!row) throw new OtpError('otp_invalid', 'Сначала запросите код', HttpStatus.BAD_REQUEST);
    if (row.expiresAt <= now) throw new OtpError('otp_expired', 'Срок действия кода истёк', HttpStatus.BAD_REQUEST);
    if (row.attempts >= this.config.otp.maxAttempts) {
      throw new OtpError('otp_attempts', 'Превышено число попыток. Запросите новый код', HttpStatus.BAD_REQUEST);
    }

    if (!safeEqualHex(row.codeHash, this.hash(phone, code))) {
      await this.db
        .update(otpCodes)
        .set({ attempts: row.attempts + 1 })
        .where(eq(otpCodes.id, row.id));
      const left = this.config.otp.maxAttempts - row.attempts - 1;
      throw new OtpError('otp_invalid', 'Неверный код', HttpStatus.BAD_REQUEST, { attemptsLeft: Math.max(left, 0) });
    }

    await this.db.update(otpCodes).set({ consumedAt: now }).where(eq(otpCodes.id, row.id));
  }
}
