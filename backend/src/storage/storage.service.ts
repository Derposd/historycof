import { BadRequestException, Inject, Injectable, Logger } from '@nestjs/common';
import { DeleteObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { mkdir, rm, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { APP_CONFIG, AppConfig } from '../config/configuration';

export const MAX_UPLOAD_BYTES = 8 * 1024 * 1024;
const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);

export type UploadFolder = 'news' | 'menu' | 'feedback';

/**
 * Хранилище изображений: S3-совместимое (Yandex Object Storage, Selectel, MinIO)
 * или локальная папка для разработки. Все картинки перекодируются в JPEG,
 * уменьшаются до 1600px по длинной стороне и очищаются от EXIF (геометки с телефона).
 */
@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly s3: S3Client | null;

  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {
    const s = config.storage;
    if (s.driver === 's3') {
      if (!s.s3Bucket || !s.s3AccessKeyId || !s.s3SecretAccessKey || !s.s3PublicBaseUrl) {
        throw new Error('STORAGE_DRIVER=s3 требует S3_BUCKET, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, S3_PUBLIC_BASE_URL');
      }
      this.s3 = new S3Client({
        region: s.s3Region,
        endpoint: s.s3Endpoint,
        forcePathStyle: s.s3ForcePathStyle,
        credentials: { accessKeyId: s.s3AccessKeyId, secretAccessKey: s.s3SecretAccessKey },
      });
    } else {
      this.s3 = null;
    }
  }

  get localDir(): string {
    return resolve(this.config.storage.localDir);
  }

  async saveImage(file: { buffer: Buffer; mimetype: string; size: number }, folder: UploadFolder): Promise<string> {
    if (!ALLOWED_MIME.has(file.mimetype)) {
      throw new BadRequestException({ error: 'upload_type', message: 'Поддерживаются JPEG, PNG, WEBP' });
    }
    if (file.size > MAX_UPLOAD_BYTES) {
      throw new BadRequestException({ error: 'upload_size', message: 'Файл больше 8 МБ' });
    }

    let processed: Buffer;
    try {
      processed = await sharp(file.buffer)
        .rotate() // учесть EXIF-ориентацию до удаления метаданных
        .resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 82, mozjpeg: true })
        .toBuffer();
    } catch {
      throw new BadRequestException({ error: 'upload_invalid', message: 'Не удалось прочитать изображение' });
    }

    const key = `${folder}/${new Date().toISOString().slice(0, 7)}/${randomUUID()}.jpg`;

    if (this.s3) {
      await this.s3.send(
        new PutObjectCommand({
          Bucket: this.config.storage.s3Bucket,
          Key: key,
          Body: processed,
          ContentType: 'image/jpeg',
          CacheControl: 'public, max-age=31536000, immutable',
        }),
      );
      return `${this.config.storage.s3PublicBaseUrl!.replace(/\/$/, '')}/${key}`;
    }

    const path = join(this.localDir, key);
    await mkdir(join(path, '..'), { recursive: true });
    await writeFile(path, processed);
    this.logger.debug(`Сохранено локально: ${key}`);
    return `${this.config.publicUrl.replace(/\/$/, '')}/uploads/${key}`;
  }

  /**
   * Удаляет загруженную картинку по её публичному адресу — например, фото из обращения
   * удалённого гостя (152-ФЗ: уничтожение данных). Чужие адреса и ошибки игнорирует.
   */
  async deleteByUrl(url: string | null | undefined): Promise<void> {
    if (!url) return;
    try {
      if (this.s3) {
        const base = `${this.config.storage.s3PublicBaseUrl!.replace(/\/$/, '')}/`;
        if (!url.startsWith(base)) return;
        await this.s3.send(new DeleteObjectCommand({ Bucket: this.config.storage.s3Bucket, Key: url.slice(base.length) }));
      } else {
        const marker = '/uploads/';
        const i = url.indexOf(marker);
        if (i < 0) return;
        const key = url.slice(i + marker.length);
        if (key.includes('..')) return;
        await rm(join(this.localDir, key), { force: true });
      }
    } catch (e) {
      this.logger.warn(`Не удалось удалить файл ${url}: ${String(e)}`);
    }
  }
}
