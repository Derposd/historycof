import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { IsBoolean, IsIn, IsOptional, IsString, Matches, MaxLength } from 'class-validator';
import { CurrentPrincipal, GuestGuard, GuestPrincipal } from '../common/auth';
import { ConsentContext, GuestsService } from './guests.service';

export const consentContext = (req: Request): ConsentContext => ({
  ip: req.ip ?? null,
  userAgent: req.headers['user-agent'] ?? null,
});

class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string | null;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'Дата в формате ГГГГ-ММ-ДД' })
  birthday?: string | null;

  /** true — согласие на получение рекламы (новостей и акций), false — отзыв. */
  @IsOptional()
  @IsBoolean()
  pushNewsEnabled?: boolean;
}

class RegisterDeviceDto {
  @IsString()
  @MaxLength(4096)
  token: string;

  @IsIn(['android', 'ios', 'web'])
  platform: 'android' | 'ios' | 'web';
}

@Controller('me')
@UseGuards(GuestGuard)
export class MeController {
  constructor(private readonly guests: GuestsService) {}

  @Get()
  profile(@CurrentPrincipal() p: GuestPrincipal) {
    return this.guests.getProfile(p.sub);
  }

  @Patch()
  update(@CurrentPrincipal() p: GuestPrincipal, @Body() dto: UpdateProfileDto, @Req() req: Request) {
    return this.guests.update(p.sub, dto, consentContext(req));
  }

  @Post('consent')
  @HttpCode(200)
  consent(@CurrentPrincipal() p: GuestPrincipal, @Req() req: Request) {
    return this.guests.acceptConsent(p.sub, consentContext(req));
  }

  @Delete()
  @HttpCode(204)
  async remove(@CurrentPrincipal() p: GuestPrincipal) {
    await this.guests.deleteAccount(p.sub);
  }
}

/**
 * Токены устройств для уведомлений — только для вошедших гостей: новости и акции уходят
 * лишь давшим согласие на рекламу, служебные — владельцу аккаунта. Анонимные устройства
 * не регистрируются (без согласия рекламу слать нельзя, 38-ФЗ ст. 18).
 */
@Controller('devices')
@UseGuards(GuestGuard)
export class DevicesController {
  constructor(private readonly guests: GuestsService) {}

  @Post()
  @HttpCode(204)
  async register(@CurrentPrincipal() p: GuestPrincipal, @Body() dto: RegisterDeviceDto) {
    await this.guests.registerDevice(dto.token, dto.platform, p.sub);
  }

  @Delete(':token')
  @HttpCode(204)
  async unregister(@Param('token') token: string) {
    await this.guests.unregisterDevice(token);
  }
}
