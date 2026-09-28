import {
  Body,
  Controller,
  DefaultValuePipe,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { IsBoolean, IsIn, IsOptional, IsString, IsUrl, Length, MaxLength } from 'class-validator';
import { CurrentPrincipal, StaffGuard, StaffPrincipal } from '../common/auth';
import { NewsService } from './news.service';

class CreateNewsDto {
  @IsString()
  @Length(1, 200)
  title: string;

  @IsString()
  @Length(1, 10_000)
  body: string;

  @IsOptional()
  @IsUrl({ require_tld: false })
  @MaxLength(1000)
  imageUrl?: string | null;

  @IsOptional()
  @IsBoolean()
  pinned?: boolean;

  /** Сразу опубликовать. */
  @IsOptional()
  @IsBoolean()
  publish?: boolean;

  /** Отправить push подписчикам при публикации. */
  @IsOptional()
  @IsBoolean()
  notify?: boolean;
}

class UpdateNewsDto {
  @IsOptional()
  @IsString()
  @Length(1, 200)
  title?: string;

  @IsOptional()
  @IsString()
  @Length(1, 10_000)
  body?: string;

  @IsOptional()
  @IsUrl({ require_tld: false })
  @MaxLength(1000)
  imageUrl?: string | null;

  @IsOptional()
  @IsBoolean()
  pinned?: boolean;
}

class PublishDto {
  @IsOptional()
  @IsBoolean()
  notify?: boolean;
}

@Controller('news')
export class NewsController {
  constructor(private readonly news: NewsService) {}

  @Get()
  feed(
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
    @Query('before') before?: string,
  ) {
    return this.news.feed(Math.min(Math.max(limit, 1), 50), before);
  }

  @Get(':id')
  one(@Param('id', ParseUUIDPipe) id: string) {
    return this.news.getPublished(id);
  }
}

class ListQuery {
  @IsOptional()
  @IsIn(['draft', 'published'])
  status?: 'draft' | 'published';
}

@Controller('admin/news')
@UseGuards(StaffGuard)
export class AdminNewsController {
  constructor(private readonly news: NewsService) {}

  @Get()
  list(@Query() q: ListQuery) {
    return this.news.listAll(q.status);
  }

  @Get(':id')
  one(@Param('id', ParseUUIDPipe) id: string) {
    return this.news.get(id);
  }

  @Post()
  async create(@CurrentPrincipal() p: StaffPrincipal, @Body() dto: CreateNewsDto) {
    const post = await this.news.create(dto, p.sub);
    return dto.publish ? this.news.publish(post.id, dto.notify ?? true) : post;
  }

  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateNewsDto) {
    return this.news.update(id, dto);
  }

  @Post(':id/publish')
  @HttpCode(200)
  publish(@Param('id', ParseUUIDPipe) id: string, @Body() dto: PublishDto) {
    return this.news.publish(id, dto.notify ?? true);
  }

  @Post(':id/unpublish')
  @HttpCode(200)
  unpublish(@Param('id', ParseUUIDPipe) id: string) {
    return this.news.unpublish(id);
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@Param('id', ParseUUIDPipe) id: string) {
    await this.news.remove(id);
  }
}
