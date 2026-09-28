/**
 * Единая точка чтения переменных окружения. Все значения по умолчанию —
 * безопасные для локальной разработки (моки вместо SMS/iiko/FCM/S3).
 */
export interface AppConfig {
  env: 'development' | 'test' | 'production';
  port: number;
  publicUrl: string;
  /** Адрес веб-админки — для ссылок в уведомлениях. */
  adminUrl: string;
  corsOrigins: string[];
  databaseUrl: string;
  jwt: {
    secret: string;
    accessTtlSec: number;
    guestRefreshTtlDays: number;
    staffRefreshTtlDays: number;
  };
  otp: {
    secret: string;
    ttlSec: number;
    resendCooldownSec: number;
    maxPerHour: number;
    maxAttempts: number;
    /** Тестовый номер для ревью App Store / Google Play (фиксированный код, SMS не отправляется). */
    reviewPhone?: string;
    reviewCode?: string;
  };
  sms: {
    provider: 'console' | 'smsru';
    smsRuApiId?: string;
    sender?: string;
  };
  iiko: {
    mode: 'mock' | 'cloud';
    baseUrl: string;
    apiLogin?: string;
    organizationId?: string;
    /** Префикс виртуальных карт, которые приложение выпускает гостю в iikoCard. */
    virtualCardPrefix: string;
  };
  push: {
    /** JSON сервисного аккаунта Firebase (строкой) — без него пуши только логируются. */
    firebaseServiceAccountJson?: string;
    newsTopic: string;
  };
  storage: {
    driver: 'local' | 's3';
    localDir: string;
    s3Endpoint?: string;
    s3Region: string;
    s3Bucket?: string;
    s3AccessKeyId?: string;
    s3SecretAccessKey?: string;
    s3PublicBaseUrl?: string;
    s3ForcePathStyle: boolean;
  };
  feedbackNotify: {
    telegramBotToken?: string;
    telegramChatId?: string;
    smtpUrl?: string;
    emailFrom?: string;
    emailTo?: string;
  };
  admin: {
    bootstrapEmail?: string;
    bootstrapPassword?: string;
  };
  privacyPolicyVersion: string;
  timezone: string;
}

const int = (v: string | undefined, def: number): number => {
  const n = v === undefined || v === '' ? NaN : Number(v);
  return Number.isFinite(n) ? n : def;
};

const opt = (v: string | undefined): string | undefined => (v && v.trim() !== '' ? v.trim() : undefined);

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const nodeEnv = (env.NODE_ENV as AppConfig['env']) ?? 'development';
  const isProd = nodeEnv === 'production';

  const jwtSecret = opt(env.JWT_SECRET) ?? (isProd ? '' : 'dev-jwt-secret-change-me');
  const otpSecret = opt(env.OTP_SECRET) ?? (isProd ? '' : 'dev-otp-secret-change-me');
  if (isProd && (!jwtSecret || !otpSecret)) {
    throw new Error('JWT_SECRET и OTP_SECRET обязательны в production');
  }

  const port = int(env.PORT, 3000);

  return {
    env: nodeEnv,
    port,
    publicUrl: opt(env.PUBLIC_URL) ?? `http://localhost:${port}`,
    adminUrl: opt(env.ADMIN_URL) ?? 'http://localhost:5173',
    corsOrigins: (env.CORS_ORIGINS ?? 'http://localhost:5173')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    databaseUrl: opt(env.DATABASE_URL) ?? 'postgres://history:history@localhost:5432/history',
    jwt: {
      secret: jwtSecret,
      accessTtlSec: int(env.JWT_ACCESS_TTL_SEC, 15 * 60),
      guestRefreshTtlDays: int(env.JWT_GUEST_REFRESH_TTL_DAYS, 90),
      staffRefreshTtlDays: int(env.JWT_STAFF_REFRESH_TTL_DAYS, 7),
    },
    otp: {
      secret: otpSecret,
      ttlSec: int(env.OTP_TTL_SEC, 5 * 60),
      resendCooldownSec: int(env.OTP_RESEND_COOLDOWN_SEC, 60),
      maxPerHour: int(env.OTP_MAX_PER_HOUR, 5),
      maxAttempts: int(env.OTP_MAX_ATTEMPTS, 5),
      reviewPhone: opt(env.OTP_REVIEW_PHONE),
      reviewCode: opt(env.OTP_REVIEW_CODE),
    },
    sms: {
      provider: env.SMS_PROVIDER === 'smsru' ? 'smsru' : 'console',
      smsRuApiId: opt(env.SMSRU_API_ID),
      sender: opt(env.SMS_SENDER),
    },
    iiko: {
      mode: env.IIKO_MODE === 'cloud' ? 'cloud' : 'mock',
      baseUrl: opt(env.IIKO_BASE_URL) ?? 'https://api-ru.iiko.services',
      apiLogin: opt(env.IIKO_API_LOGIN),
      organizationId: opt(env.IIKO_ORGANIZATION_ID),
      virtualCardPrefix: opt(env.IIKO_VIRTUAL_CARD_PREFIX) ?? '7707',
    },
    push: {
      firebaseServiceAccountJson: opt(env.FIREBASE_SERVICE_ACCOUNT_JSON),
      newsTopic: opt(env.FCM_NEWS_TOPIC) ?? 'news',
    },
    storage: {
      driver: env.STORAGE_DRIVER === 's3' ? 's3' : 'local',
      localDir: opt(env.STORAGE_LOCAL_DIR) ?? './uploads',
      s3Endpoint: opt(env.S3_ENDPOINT),
      s3Region: opt(env.S3_REGION) ?? 'ru-central1',
      s3Bucket: opt(env.S3_BUCKET),
      s3AccessKeyId: opt(env.S3_ACCESS_KEY_ID),
      s3SecretAccessKey: opt(env.S3_SECRET_ACCESS_KEY),
      s3PublicBaseUrl: opt(env.S3_PUBLIC_BASE_URL),
      s3ForcePathStyle: env.S3_FORCE_PATH_STYLE === 'true',
    },
    feedbackNotify: {
      telegramBotToken: opt(env.TELEGRAM_BOT_TOKEN),
      telegramChatId: opt(env.TELEGRAM_CHAT_ID),
      smtpUrl: opt(env.SMTP_URL),
      emailFrom: opt(env.FEEDBACK_EMAIL_FROM),
      emailTo: opt(env.FEEDBACK_EMAIL_TO),
    },
    admin: {
      bootstrapEmail: opt(env.ADMIN_BOOTSTRAP_EMAIL),
      bootstrapPassword: opt(env.ADMIN_BOOTSTRAP_PASSWORD),
    },
    privacyPolicyVersion: opt(env.PRIVACY_POLICY_VERSION) ?? '2026-09-28',
    timezone: opt(env.VENUE_TIMEZONE) ?? 'Europe/Moscow',
  };
}

export const APP_CONFIG = Symbol('APP_CONFIG');
