import { Module } from '@nestjs/common';
import { AdminNewsController, NewsController } from './news.controller';
import { NewsService } from './news.service';

@Module({
  controllers: [NewsController, AdminNewsController],
  providers: [NewsService],
})
export class NewsModule {}
