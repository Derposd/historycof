import { Controller, Global, Module, Post, UploadedFile, UseGuards, UseInterceptors, BadRequestException, Query } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { StaffGuard } from '../common/auth';
import { MAX_UPLOAD_BYTES, StorageService, UploadFolder } from './storage.service';

@Controller('admin/uploads')
@UseGuards(StaffGuard)
export class AdminUploadsController {
  constructor(private readonly storage: StorageService) {}

  @Post()
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: MAX_UPLOAD_BYTES } }))
  async upload(@UploadedFile() file: Express.Multer.File | undefined, @Query('folder') folder?: string) {
    if (!file) throw new BadRequestException({ error: 'upload_missing', message: 'Файл не передан' });
    const target: UploadFolder = folder === 'menu' ? 'menu' : 'news';
    return { url: await this.storage.saveImage(file, target) };
  }
}

@Global()
@Module({
  controllers: [AdminUploadsController],
  providers: [StorageService],
  exports: [StorageService],
})
export class StorageModule {}
