import { Controller, Get, Header, Inject, Module } from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { PRIVACY_POLICY_MARKDOWN } from './privacy-policy';

@Controller('legal')
export class LegalController {
  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  @Get('privacy')
  @Header('Cache-Control', 'public, max-age=3600')
  privacy() {
    return { version: this.config.privacyPolicyVersion, markdown: PRIVACY_POLICY_MARKDOWN };
  }
}

@Module({ controllers: [LegalController] })
export class LegalModule {}
