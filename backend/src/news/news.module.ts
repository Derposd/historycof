import { Module } from '@nestjs/common';
import { GuestsModule } from '../guests/guests.module';
import { AdminNewsController, NewsController } from './news.controller';
import { NewsService } from './news.service';

@Module({
  imports: [GuestsModule],
  controllers: [NewsController, AdminNewsController],
  providers: [NewsService],
})
export class NewsModule {}
