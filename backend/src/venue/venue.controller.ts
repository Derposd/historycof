import { Body, Controller, Get, Module, Put, UseGuards } from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEmail,
  IsIn,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { Roles, StaffGuard } from '../common/auth';
import { IsoWeekday } from './hours';
import { VenueService } from './venue.service';

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

class DayHoursDto {
  @IsIn([1, 2, 3, 4, 5, 6, 7])
  day: IsoWeekday;

  @ValidateIf((o: DayHoursDto) => o.open !== null)
  @Matches(HHMM)
  open: string | null;

  @ValidateIf((o: DayHoursDto) => o.close !== null)
  @Matches(HHMM)
  close: string | null;
}

class UpdateVenueDto {
  @IsOptional() @IsString() @Length(1, 80) name?: string;
  @IsOptional() @IsString() @MaxLength(200) tagline?: string;
  @IsOptional() @IsString() @Length(1, 200) address?: string;
  @IsOptional() @ValidateIf((o: UpdateVenueDto) => o.lat !== null) @IsLatitude() lat?: number | null;
  @IsOptional() @ValidateIf((o: UpdateVenueDto) => o.lng !== null) @IsLongitude() lng?: number | null;
  @IsOptional() @Matches(/^\+7\d{10}$/, { message: 'Телефон в формате +7XXXXXXXXXX' }) phone?: string;
  @IsOptional() @Matches(/^\+7\d{10}$/, { message: 'WhatsApp в формате +7XXXXXXXXXX' }) whatsapp?: string;
  @IsOptional() @Matches(/^([A-Za-z0-9_]{5,32})?$/, { message: 'Telegram — имя без @ (латиница, цифры, _)' }) telegram?: string;
  @IsOptional() @Matches(/^([A-Za-z0-9_.]{2,50})?$/, { message: 'ВКонтакте — короткое имя сообщества' }) vk?: string;
  @IsOptional() @IsString() @MaxLength(200) website?: string;
  @IsOptional() @IsString() @Length(1, 200, { message: 'Укажите наименование продавца (ИП или организация)' }) legalName?: string;
  @IsOptional() @IsString() @MaxLength(300) legalAddress?: string;
  @IsOptional() @ValidateIf((o: UpdateVenueDto) => !!o.privacyEmail) @IsEmail({}, { message: 'Почта указана неверно' }) privacyEmail?: string;
  @IsOptional() @IsString() @MaxLength(3000) processors?: string;
  @IsOptional() @IsString() @MaxLength(20000) loyaltyRules?: string;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(7)
  @ArrayMaxSize(7)
  @ValidateNested({ each: true })
  @Type(() => DayHoursDto)
  hours?: DayHoursDto[];
}

@Controller('venue')
export class VenueController {
  constructor(private readonly venue: VenueService) {}

  @Get()
  get() {
    return this.venue.getWithStatus();
  }
}

@Controller('admin/venue')
@UseGuards(StaffGuard)
export class AdminVenueController {
  constructor(private readonly venue: VenueService) {}

  @Get()
  get() {
    return this.venue.get();
  }

  @Put()
  @Roles('admin')
  update(@Body() dto: UpdateVenueDto) {
    return this.venue.update(dto);
  }
}

@Module({
  controllers: [VenueController, AdminVenueController],
  providers: [VenueService],
  exports: [VenueService],
})
export class VenueModule {}
