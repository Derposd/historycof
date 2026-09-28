import { Controller, DefaultValuePipe, Get, Module, ParseBoolPipe, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { CurrentPrincipal, GuestGuard, GuestPrincipal } from '../common/auth';
import { IikoCloudClient } from './iiko/iiko-cloud.client';
import { IIKO_CLIENT, IikoLoyaltyClient } from './iiko/iiko.types';
import { MockIikoClient } from './iiko/mock-iiko.client';
import { LoyaltyService } from './loyalty.service';

@Controller('loyalty')
@UseGuards(GuestGuard)
export class LoyaltyController {
  constructor(private readonly loyalty: LoyaltyService) {}

  @Get()
  summary(
    @CurrentPrincipal() p: GuestPrincipal,
    @Query('refresh', new DefaultValuePipe(false), ParseBoolPipe) refresh: boolean,
  ) {
    return this.loyalty.summary(p.sub, refresh);
  }

  @Get('card')
  card(@CurrentPrincipal() p: GuestPrincipal) {
    return this.loyalty.card(p.sub);
  }

  @Get('transactions')
  transactions(
    @CurrentPrincipal() p: GuestPrincipal,
    @Query('page', new DefaultValuePipe(0), ParseIntPipe) page: number,
    @Query('pageSize', new DefaultValuePipe(20), ParseIntPipe) pageSize: number,
  ) {
    return this.loyalty.transactions(p.sub, Math.max(page, 0), Math.min(Math.max(pageSize, 1), 50));
  }
}

export function createIikoClient(config: AppConfig): IikoLoyaltyClient {
  if (config.iiko.mode === 'cloud') {
    const { apiLogin, organizationId, baseUrl } = config.iiko;
    if (!apiLogin || !organizationId) throw new Error('IIKO_MODE=cloud требует IIKO_API_LOGIN и IIKO_ORGANIZATION_ID');
    return new IikoCloudClient({ baseUrl, apiLogin, organizationId });
  }
  return new MockIikoClient();
}

@Module({
  controllers: [LoyaltyController],
  providers: [
    LoyaltyService,
    { provide: IIKO_CLIENT, inject: [APP_CONFIG], useFactory: createIikoClient },
  ],
  exports: [IIKO_CLIENT],
})
export class LoyaltyModule {}
