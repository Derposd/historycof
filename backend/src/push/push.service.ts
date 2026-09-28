import { Global, Inject, Injectable, Logger, Module } from '@nestjs/common';
import { App, cert, initializeApp } from 'firebase-admin/app';
import { getMessaging, Messaging } from 'firebase-admin/messaging';
import { inArray } from 'drizzle-orm';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { DB, Db } from '../db/database.module';
import { deviceTokens } from '../db/schema';

export interface PushMessage {
  title: string;
  body: string;
  /** Для deeplink в приложении: { type: 'news', id } / { type: 'feedback', id }. */
  data?: Record<string, string>;
  imageUrl?: string;
}

/**
 * Firebase Cloud Messaging. Без FIREBASE_SERVICE_ACCOUNT_JSON работает в режиме
 * «только лог» — удобно для локальной разработки и тестов.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private readonly messaging: Messaging | null;

  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(DB) private readonly db: Db,
  ) {
    const json = config.push.firebaseServiceAccountJson;
    if (json) {
      const app: App = initializeApp({ credential: cert(JSON.parse(json)) }, 'history-coffee');
      this.messaging = getMessaging(app);
    } else {
      this.messaging = null;
    }
  }

  get enabled(): boolean {
    return this.messaging !== null;
  }

  async sendToTopic(topic: string, msg: PushMessage): Promise<void> {
    if (!this.messaging) {
      this.logger.log(`[dev] push → topic "${topic}": ${msg.title}`);
      return;
    }
    await this.messaging.send({
      topic,
      notification: { title: msg.title, body: msg.body, imageUrl: msg.imageUrl },
      data: msg.data,
      android: { priority: 'high', notification: { channelId: 'news' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  }

  async sendToTokens(tokens: string[], msg: PushMessage): Promise<void> {
    if (tokens.length === 0) return;
    if (!this.messaging) {
      this.logger.log(`[dev] push → ${tokens.length} устройств: ${msg.title}`);
      return;
    }
    const res = await this.messaging.sendEachForMulticast({
      tokens,
      notification: { title: msg.title, body: msg.body, imageUrl: msg.imageUrl },
      data: msg.data,
      apns: { payload: { aps: { sound: 'default' } } },
    });
    const stale = res.responses
      .map((r, i) => (!r.success && isStaleTokenError(r.error?.code) ? tokens[i] : null))
      .filter((t): t is string => t !== null);
    if (stale.length) {
      await this.db.delete(deviceTokens).where(inArray(deviceTokens.token, stale));
    }
  }
}

function isStaleTokenError(code?: string): boolean {
  return code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token';
}

@Global()
@Module({ providers: [PushService], exports: [PushService] })
export class PushModule {}
