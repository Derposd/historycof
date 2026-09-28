import { Logger } from '@nestjs/common';
import { AppConfig } from '../../config/configuration';
import { maskPhone } from '../../common/phone';

export const SMS_PROVIDER = Symbol('SMS_PROVIDER');

export interface SmsProvider {
  send(phoneE164: string, text: string): Promise<void>;
}

/** Для разработки: код пишется в лог сервера, SMS не отправляется. */
export class ConsoleSmsProvider implements SmsProvider {
  private readonly logger = new Logger('SMS');

  async send(phone: string, text: string): Promise<void> {
    this.logger.log(`[dev] SMS на ${phone}: ${text}`);
  }
}

/**
 * SMS.ru (https://sms.ru/api/send). Выбран как пример российского шлюза —
 * провайдер легко заменить (SMSC, SMS Aero, МТС Exolve), реализовав SmsProvider.
 */
export class SmsRuProvider implements SmsProvider {
  private readonly logger = new Logger('SMS.ru');

  constructor(
    private readonly apiId: string,
    private readonly sender?: string,
  ) {}

  async send(phone: string, text: string): Promise<void> {
    const params = new URLSearchParams({
      api_id: this.apiId,
      to: phone.replace('+', ''),
      msg: text,
      json: '1',
    });
    if (this.sender) params.set('from', this.sender);
    const res = await fetch('https://sms.ru/sms/send', { method: 'POST', body: params });
    const body = (await res.json().catch(() => null)) as { status?: string; status_text?: string } | null;
    if (!res.ok || body?.status !== 'OK') {
      this.logger.error(`Не удалось отправить SMS на ${maskPhone(phone)}: ${body?.status_text ?? res.status}`);
      throw new Error('SMS_SEND_FAILED');
    }
  }
}

export function createSmsProvider(config: AppConfig): SmsProvider {
  if (config.sms.provider === 'smsru') {
    if (!config.sms.smsRuApiId) throw new Error('SMS_PROVIDER=smsru требует SMSRU_API_ID');
    return new SmsRuProvider(config.sms.smsRuApiId, config.sms.sender);
  }
  return new ConsoleSmsProvider();
}
