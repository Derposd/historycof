import { Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { and, eq, gt, isNull } from 'drizzle-orm';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { DB, Db } from '../db/database.module';
import { refreshTokens } from '../db/schema';
import { Principal } from '../common/auth';
import { hmacSha256, randomToken } from '../common/crypto';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

@Injectable()
export class TokensService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly jwt: JwtService,
  ) {}

  private hash(token: string): string {
    return hmacSha256(this.config.jwt.secret, token);
  }

  async issue(principal: Principal): Promise<TokenPair> {
    const accessToken = await this.jwt.signAsync({ ...principal }, { expiresIn: this.config.jwt.accessTtlSec });
    const refreshToken = randomToken();
    const days =
      principal.typ === 'guest' ? this.config.jwt.guestRefreshTtlDays : this.config.jwt.staffRefreshTtlDays;
    await this.db.insert(refreshTokens).values({
      subjectType: principal.typ,
      subjectId: principal.sub,
      tokenHash: this.hash(refreshToken),
      expiresAt: new Date(Date.now() + days * 86400_000),
    });
    return { accessToken, refreshToken, expiresIn: this.config.jwt.accessTtlSec };
  }

  /**
   * Ротация: старый refresh-токен отзывается, возвращается subject для выпуска новой пары.
   * Вызывающая сторона сама проверяет, что subject ещё существует/активен.
   */
  async consumeRefresh(refreshToken: string): Promise<{ subjectType: 'guest' | 'staff'; subjectId: string }> {
    const [row] = await this.db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(refreshTokens.tokenHash, this.hash(refreshToken)),
          isNull(refreshTokens.revokedAt),
          gt(refreshTokens.expiresAt, new Date()),
        ),
      )
      .returning();
    if (!row) throw new UnauthorizedException('Сессия истекла, войдите заново');
    return { subjectType: row.subjectType, subjectId: row.subjectId };
  }

  async revoke(refreshToken: string): Promise<void> {
    await this.db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(and(eq(refreshTokens.tokenHash, this.hash(refreshToken)), isNull(refreshTokens.revokedAt)));
  }

  async revokeAll(subjectType: 'guest' | 'staff', subjectId: string): Promise<void> {
    await this.db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(refreshTokens.subjectType, subjectType),
          eq(refreshTokens.subjectId, subjectId),
          isNull(refreshTokens.revokedAt),
        ),
      );
  }
}
