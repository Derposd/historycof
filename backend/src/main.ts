import 'reflect-metadata';
import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { APP_CONFIG, AppConfig, loadDotEnv } from './config/configuration';
import { StorageService } from './storage/storage.service';

export function configureApp(app: NestExpressApplication): void {
  const config = app.get<AppConfig>(APP_CONFIG);
  app.set('trust proxy', 1); // за reverse-proxy — корректный IP для rate limit
  app.disable('x-powered-by');
  app.setGlobalPrefix('api/v1', { exclude: ['health'] });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: false },
    }),
  );
  app.enableCors({ origin: config.corsOrigins, credentials: false });
  if (config.storage.driver === 'local') {
    app.useStaticAssets(app.get(StorageService).localDir, { prefix: '/uploads/', maxAge: '30d', immutable: true });
  }
}

async function bootstrap() {
  loadDotEnv();
  const app = await NestFactory.create<NestExpressApplication>(AppModule.forRoot(), { bufferLogs: false });
  configureApp(app);
  app.enableShutdownHooks();
  const config = app.get<AppConfig>(APP_CONFIG);
  await app.listen(config.port, '0.0.0.0');
  Logger.log(`History Coffee API: ${config.publicUrl}/api/v1 (iiko: ${config.iiko.mode}, sms: ${config.sms.provider})`, 'Bootstrap');
}

if (require.main === module) {
  void bootstrap();
}
