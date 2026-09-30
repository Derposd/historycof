import { Body, Controller, Get, Module, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { IsString, Length } from 'class-validator';
import { CurrentPrincipal, GuestGuard, GuestPrincipal, StaffGuard, StaffPrincipal } from '../common/auth';
import { GuestsModule } from '../guests/guests.module';
import { ChatService } from './chat.service';

class SendMessageDto {
  @IsString()
  @Length(1, 2000, { message: 'Сообщение — от 1 до 2000 символов' })
  text: string;
}

@Controller('chat')
@UseGuards(GuestGuard)
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  /** Переписка гостя; открытие отмечает ответы кофейни прочитанными. */
  @Get()
  thread(@CurrentPrincipal() p: GuestPrincipal) {
    return this.chat.guestThread(p.sub);
  }

  @Get('unread')
  async unread(@CurrentPrincipal() p: GuestPrincipal) {
    return { count: await this.chat.guestUnread(p.sub) };
  }

  @Post()
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  send(@CurrentPrincipal() p: GuestPrincipal, @Body() dto: SendMessageDto) {
    return this.chat.guestSend(p.sub, dto.text);
  }
}

@Controller('admin/chats')
@UseGuards(StaffGuard)
export class AdminChatController {
  constructor(private readonly chat: ChatService) {}

  @Get()
  threads() {
    return this.chat.threads();
  }

  @Get('unread')
  async unread() {
    return { count: await this.chat.staffUnread() };
  }

  @Get(':guestId')
  thread(@Param('guestId', ParseUUIDPipe) guestId: string) {
    return this.chat.staffThread(guestId);
  }

  @Post(':guestId')
  send(@CurrentPrincipal() p: StaffPrincipal, @Param('guestId', ParseUUIDPipe) guestId: string, @Body() dto: SendMessageDto) {
    return this.chat.staffSend(guestId, p.sub, dto.text);
  }
}

@Module({
  imports: [GuestsModule],
  controllers: [ChatController, AdminChatController],
  providers: [ChatService],
})
export class ChatModule {}
