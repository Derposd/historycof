import { DynamicModule, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AppConfigModule } from './config/config.module';
import { APP_CONFIG, AppConfig } from './config/configuration';
import { DatabaseModule } from './db/database.module';
import { AuthModule } from './auth/auth.module';
import { GuestsModule } from './guests/guests.module';
import { NewsModule } from './news/news.module';
import { MenuModule } from './menu/menu.module';
import { LoyaltyModule } from './loyalty/loyalty.module';
import { FeedbackModule } from './feedback/feedback.module';
import { VenueModule } from './venue/venue.controller';
import { StorageModule } from './storage/storage.module';
import { PushModule } from './push/push.service';
import { StaffModule } from './staff/staff.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { LegalModule } from './legal/legal.module';
import { RetentionModule } from './retention/retention.module';
import { HealthController } from './health/health.controller';

@Module({})
export class AppModule {
  static forRoot(configOverride?: Partial<AppConfig>): DynamicModule {
    return {
      module: AppModule,
      imports: [
        AppConfigModule.forRoot(configOverride),
        DatabaseModule,
        JwtModule.registerAsync({
          global: true,
          inject: [APP_CONFIG],
          useFactory: (c: AppConfig) => ({ secret: c.jwt.secret }),
        }),
        ThrottlerModule.forRootAsync({
          inject: [APP_CONFIG],
          useFactory: (c: AppConfig) => ({
            throttlers: [{ name: 'default', ttl: 60_000, limit: 120 }],
            // В e2e-тестах лимиты по IP мешают сценариям; OTP ограничен отдельно в OtpService.
            skipIf: () => c.env === 'test',
          }),
        }),
        PushModule,
        StorageModule,
        GuestsModule,
        AuthModule,
        NewsModule,
        MenuModule,
        LoyaltyModule,
        FeedbackModule,
        VenueModule,
        StaffModule,
        AnalyticsModule,
        LegalModule,
        RetentionModule,
      ],
      controllers: [HealthController],
      providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
    };
  }
}
