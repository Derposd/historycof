import { Controller, Get, Inject, Module, UseGuards } from '@nestjs/common';
import { and, count, eq, gte, isNotNull, isNull, sql } from 'drizzle-orm';
import { DB, Db } from '../db/database.module';
import { deviceTokens, feedback, guests, menuItems, newsPosts } from '../db/schema';
import { StaffGuard } from '../common/auth';

/**
 * Базовая аналитика для дашборда админки. Оборот и суммы бонусов живут в iiko
 * (отчёты iikoOffice / iikoCard) — здесь только то, что знает приложение.
 */
@Controller('admin/analytics')
@UseGuards(StaffGuard)
export class AdminAnalyticsController {
  constructor(@Inject(DB) private readonly db: Db) {}

  @Get('summary')
  async summary() {
    const monthAgo = new Date(Date.now() - 30 * 86400_000);
    const weekAgo = new Date(Date.now() - 7 * 86400_000);
    const active = isNull(guests.deletedAt);

    const one = async (q: Promise<{ n: number }[]>) => (await q)[0]?.n ?? 0;

    const [
      guestsTotal,
      guestsNew30d,
      guestsActive7d,
      loyaltyLinked,
      devices,
      newsPublished,
      menuItemsTotal,
      feedbackOpen,
      feedbackByType,
      signupsByDay,
    ] = await Promise.all([
      one(this.db.select({ n: count() }).from(guests).where(active)),
      one(this.db.select({ n: count() }).from(guests).where(and(active, gte(guests.createdAt, monthAgo)))),
      one(this.db.select({ n: count() }).from(guests).where(and(active, gte(guests.lastSeenAt, weekAgo)))),
      one(this.db.select({ n: count() }).from(guests).where(and(active, isNotNull(guests.iikoCustomerId)))),
      one(this.db.select({ n: count() }).from(deviceTokens)),
      one(this.db.select({ n: count() }).from(newsPosts).where(eq(newsPosts.status, 'published'))),
      one(this.db.select({ n: count() }).from(menuItems)),
      one(this.db.select({ n: count() }).from(feedback).where(sql`${feedback.status} <> 'answered'`)),
      this.db
        .select({ type: feedback.type, n: count() })
        .from(feedback)
        .where(gte(feedback.createdAt, monthAgo))
        .groupBy(feedback.type),
      this.db
        .select({
          day: sql<string>`to_char(date_trunc('day', ${guests.createdAt} at time zone 'Europe/Moscow'), 'YYYY-MM-DD')`,
          n: count(),
        })
        .from(guests)
        .where(gte(guests.createdAt, monthAgo))
        .groupBy(sql`1`)
        .orderBy(sql`1`),
    ]);

    return {
      guests: { total: guestsTotal, new30d: guestsNew30d, active7d: guestsActive7d, loyaltyLinked },
      devices,
      newsPublished,
      menuItems: menuItemsTotal,
      feedback: { open: feedbackOpen, last30dByType: feedbackByType },
      signupsByDay,
    };
  }
}

@Module({ controllers: [AdminAnalyticsController] })
export class AnalyticsModule {}
