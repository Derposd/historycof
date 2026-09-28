import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { IsBoolean, IsIn, IsOptional, IsString, Matches, MaxLength } from 'class-validator';
import { CurrentPrincipal, GuestGuard, GuestPrincipal, OptionalGuestGuard, Principal } from '../common/auth';
import { GuestsService } from './guests.service';

class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string | null;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'Дата в формате ГГГГ-ММ-ДД' })
  birthday?: string | null;

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
  update(@CurrentPrincipal() p: GuestPrincipal, @Body() dto: UpdateProfileDto) {
    return this.guests.update(p.sub, dto);
  }

  @Post('consent')
  @HttpCode(200)
  consent(@CurrentPrincipal() p: GuestPrincipal) {
    return this.guests.acceptConsent(p.sub);
  }

  @Delete()
  @HttpCode(204)
  async remove(@CurrentPrincipal() p: GuestPrincipal) {
    await this.guests.deleteAccount(p.sub);
  }
}

/** FCM-токены. Анонимные устройства тоже регистрируются — чтобы получать новости без входа. */
@Controller('devices')
@UseGuards(OptionalGuestGuard)
export class DevicesController {
  constructor(private readonly guests: GuestsService) {}

  @Post()
  @HttpCode(204)
  async register(@CurrentPrincipal() p: Principal | undefined, @Body() dto: RegisterDeviceDto) {
    await this.guests.registerDevice(dto.token, dto.platform, p?.sub ?? null);
  }

  @Delete(':token')
  @HttpCode(204)
  async unregister(@Param('token') token: string) {
    await this.guests.unregisterDevice(token);
  }
}
