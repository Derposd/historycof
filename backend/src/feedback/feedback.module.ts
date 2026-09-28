import {
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  Module,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { IsIn, IsOptional, IsString, Length, MaxLength } from 'class-validator';
import { memoryStorage } from 'multer';
import { CurrentPrincipal, GuestGuard, GuestPrincipal, OptionalGuestGuard, StaffGuard, StaffPrincipal } from '../common/auth';
import { GuestsModule } from '../guests/guests.module';
import { MAX_UPLOAD_BYTES } from '../storage/storage.service';
import { FeedbackService, FeedbackStatus, FeedbackType } from './feedback.service';
import { FeedbackNotifier } from './notifiers/feedback-notifier';

const TYPES: FeedbackType[] = ['complaint', 'suggestion', 'thanks'];
const STATUSES: FeedbackStatus[] = ['sent', 'viewed', 'answered'];

class CreateFeedbackDto {
  @IsIn(TYPES)
  type: FeedbackType;

  @IsString()
  @Length(3, 3000, { message: 'Сообщение от 3 до 3000 символов' })
  message: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  contactPhone?: string;
}

class ListFeedbackQuery {
  @IsOptional() @IsIn(STATUSES) status?: FeedbackStatus;
  @IsOptional() @IsIn(TYPES) type?: FeedbackType;
}

class AnswerFeedbackDto {
  @IsOptional()
  @IsString()
  @MaxLength(3000)
  reply?: string;

  @IsOptional()
  @IsIn(STATUSES)
  status?: FeedbackStatus;
}

@Controller('feedback')
export class FeedbackController {
  constructor(private readonly feedback: FeedbackService) {}

  /** multipart/form-data: type, message, contactPhone?, photo? */
  @Post()
  @UseGuards(OptionalGuestGuard)
  @Throttle({ default: { limit: 5, ttl: 10 * 60_000 } })
  @UseInterceptors(FileInterceptor('photo', { storage: memoryStorage(), limits: { fileSize: MAX_UPLOAD_BYTES } }))
  create(
    @CurrentPrincipal() p: GuestPrincipal | undefined,
    @Body() dto: CreateFeedbackDto,
    @UploadedFile() photo?: Express.Multer.File,
  ) {
    return this.feedback.create({ guestId: p?.sub ?? null, ...dto, photo });
  }

  @Get('mine')
  @UseGuards(GuestGuard)
  mine(@CurrentPrincipal() p: GuestPrincipal) {
    return this.feedback.listMine(p.sub);
  }
}

@Controller('admin/feedback')
@UseGuards(StaffGuard)
export class AdminFeedbackController {
  constructor(private readonly feedback: FeedbackService) {}

  @Get()
  list(
    @Query() q: ListFeedbackQuery,
    @Query('page', new DefaultValuePipe(0), ParseIntPipe) page: number,
    @Query('pageSize', new DefaultValuePipe(30), ParseIntPipe) pageSize: number,
  ) {
    return this.feedback.list({ ...q, page: Math.max(page, 0), pageSize: Math.min(Math.max(pageSize, 1), 100) });
  }

  @Get(':id')
  one(@Param('id', ParseUUIDPipe) id: string) {
    return this.feedback.openForStaff(id);
  }

  @Patch(':id')
  answer(@CurrentPrincipal() p: StaffPrincipal, @Param('id', ParseUUIDPipe) id: string, @Body() dto: AnswerFeedbackDto) {
    return this.feedback.answer(id, p.sub, dto);
  }
}

@Module({
  imports: [GuestsModule],
  controllers: [FeedbackController, AdminFeedbackController],
  providers: [FeedbackService, FeedbackNotifier],
  exports: [FeedbackService],
})
export class FeedbackModule {}
