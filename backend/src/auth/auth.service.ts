import { BadRequestException, Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { and, eq, isNull } from 'drizzle-orm';
import * as bcrypt from 'bcryptjs';
import { DB, Db } from '../db/database.module';
import { guests, staffUsers } from '../db/schema';
import { normalizeRuMobile } from '../common/phone';
import { ConsentContext, GuestsService } from '../guests/guests.service';
import { LEGAL_VERSION } from '../legal/documents';
import { OtpService } from './otp.service';
import { TokenPair, TokensService } from './tokens.service';

const DUMMY_HASH = bcrypt.hashSync('timing-equalizer', 10);

@Injectable()
export class AuthService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly otp: OtpService,
    private readonly tokens: TokensService,
    private readonly guestsService: GuestsService,
  ) {}

  private phoneOrThrow(raw: string): string {
    const phone = normalizeRuMobile(raw);
    if (!phone) {
      throw new BadRequestException({ error: 'phone_invalid', message: 'Введите российский мобильный номер: +7 9XX XXX-XX-XX' });
    }
    return phone;
  }

  async requestOtp(rawPhone: string) {
    const phone = this.phoneOrThrow(rawPhone);
    const [existing] = await this.db
      .select({ id: guests.id })
      .from(guests)
      .where(and(eq(guests.phone, phone), isNull(guests.deletedAt)));
    const result = await this.otp.request(phone);
    return { ...result, isNewUser: !existing, legalVersion: LEGAL_VERSION };
  }

  async verifyOtp(
    input: {
      phone: string;
      code: string;
      acceptPersonalData?: boolean;
      acceptPrivacyPolicy?: boolean;
      acceptMarketing?: boolean;
      name?: string;
    },
    ctx: ConsentContext = {},
  ) {
    const phone = this.phoneOrThrow(input.phone);
    const acceptPd = input.acceptPersonalData ?? input.acceptPrivacyPolicy ?? false;

    const [existing] = await this.db
      .select()
      .from(guests)
      .where(and(eq(guests.phone, phone), isNull(guests.deletedAt)));

    // Согласие проверяем до проверки кода, чтобы не «сжечь» код на ошибке формы.
    if (!existing && !acceptPd) {
      throw new BadRequestException({
        error: 'consent_required',
        message: 'Для регистрации необходимо согласие на обработку персональных данных',
      });
    }

    await this.otp.verify(phone, input.code);

    const now = new Date();
    let guestId: string;
    if (existing) {
      guestId = existing.id;
      await this.db
        .update(guests)
        .set({
          lastSeenAt: now,
          ...(acceptPd ? { consentVersion: LEGAL_VERSION, consentAt: now } : {}),
        })
        .where(eq(guests.id, guestId));
    } else {
      const [created] = await this.db
        .insert(guests)
        .values({
          phone,
          name: input.name?.trim() || null,
          consentVersion: LEGAL_VERSION,
          consentAt: now,
          lastSeenAt: now,
        })
        .returning({ id: guests.id });
      guestId = created.id;
    }

    // Журнал согласий: на обработку ПДн — при регистрации или повторном подтверждении,
    // на рекламу — только если гость отдельно отметил галочку
    if (acceptPd) await this.guestsService.recordConsent(guestId, 'pd', ctx);
    if (input.acceptMarketing) await this.guestsService.update(guestId, { pushNewsEnabled: true }, ctx);

    const pair = await this.tokens.issue({ typ: 'guest', sub: guestId });
    const profile = await this.guestsService.getProfile(guestId);
    return { ...pair, guest: profile, isNewUser: !existing };
  }

  async refreshGuest(refreshToken: string): Promise<TokenPair> {
    const { subjectType, subjectId } = await this.tokens.consumeRefresh(refreshToken);
    if (subjectType !== 'guest') throw new UnauthorizedException();
    const [g] = await this.db
      .select({ id: guests.id })
      .from(guests)
      .where(and(eq(guests.id, subjectId), isNull(guests.deletedAt)));
    if (!g) throw new UnauthorizedException();
    await this.db.update(guests).set({ lastSeenAt: new Date() }).where(eq(guests.id, g.id));
    return this.tokens.issue({ typ: 'guest', sub: g.id });
  }

  async staffLogin(email: string, password: string) {
    const [user] = await this.db.select().from(staffUsers).where(eq(staffUsers.email, email.toLowerCase().trim()));
    // bcrypt.compare выполняем всегда, чтобы время ответа не выдавало наличие email.
    const ok = await bcrypt.compare(password, user?.passwordHash ?? DUMMY_HASH);
    if (!user || !ok || !user.active) throw new UnauthorizedException('Неверный email или пароль');
    await this.db.update(staffUsers).set({ lastLoginAt: new Date() }).where(eq(staffUsers.id, user.id));
    const pair = await this.tokens.issue({ typ: 'staff', sub: user.id, role: user.role });
    return { ...pair, user: { id: user.id, email: user.email, name: user.name, role: user.role } };
  }

  async refreshStaff(refreshToken: string): Promise<TokenPair> {
    const { subjectType, subjectId } = await this.tokens.consumeRefresh(refreshToken);
    if (subjectType !== 'staff') throw new UnauthorizedException();
    const [user] = await this.db.select().from(staffUsers).where(eq(staffUsers.id, subjectId));
    if (!user?.active) throw new UnauthorizedException();
    return this.tokens.issue({ typ: 'staff', sub: user.id, role: user.role });
  }

  logout(refreshToken: string): Promise<void> {
    return this.tokens.revoke(refreshToken);
  }
}
