import { Module } from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { GuestsModule } from '../guests/guests.module';
import { AdminAuthController, AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { createSmsProvider, SMS_PROVIDER } from './sms/sms.provider';
import { TokensService } from './tokens.service';

@Module({
  imports: [GuestsModule],
  controllers: [AuthController, AdminAuthController],
  providers: [
    AuthService,
    OtpService,
    TokensService,
    { provide: SMS_PROVIDER, inject: [APP_CONFIG], useFactory: (c: AppConfig) => createSmsProvider(c) },
  ],
  exports: [TokensService],
})
export class AuthModule {}
