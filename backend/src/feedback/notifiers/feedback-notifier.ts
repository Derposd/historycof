import { Inject, Injectable, Logger } from '@nestjs/common';
import { createTransport, Transporter } from 'nodemailer';
import { APP_CONFIG, AppConfig } from '../../config/configuration';
import { Feedback } from '../../db/schema';
import { formatRuPhone } from '../../common/phone';

export const FEEDBACK_TYPE_LABEL: Record<Feedback['type'], string> = {
  complaint: 'Жалоба',
  suggestion: 'Предложение',
  thanks: 'Благодарность',
};

const TYPE_ICON: Record<Feedback['type'], string> = { complaint: '⚠️', suggestion: '💡', thanks: '💚' };

export function formatFeedbackText(f: Feedback, guestPhone: string | null, adminUrl?: string): string {
  const contact = f.contactPhone ?? guestPhone;
  const lines = [
    `${TYPE_ICON[f.type]} ${FEEDBACK_TYPE_LABEL[f.type]} из приложения`,
    '',
    f.message,
    '',
    contact ? `Телефон для связи: ${formatRuPhone(contact)}` : 'Гость не оставил телефон',
  ];
  if (adminUrl) lines.push(`Открыть в админке: ${adminUrl}/feedback/${f.id}`);
  return lines.join('\n');
}

/**
 * Уведомляет сотрудников о новом обращении. Каналы включаются переменными окружения:
 * Telegram-бот (TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID) и/или email (SMTP_URL + FEEDBACK_EMAIL_TO).
 * Обращение в любом случае сохраняется в админке — каналы только дублируют.
 */
@Injectable()
export class FeedbackNotifier {
  private readonly logger = new Logger(FeedbackNotifier.name);
  private readonly mailer: Transporter | null;

  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {
    const { smtpUrl, emailTo } = config.feedbackNotify;
    this.mailer = smtpUrl && emailTo ? createTransport(smtpUrl) : null;
  }

  async notify(f: Feedback, guestPhone: string | null): Promise<void> {
    const text = formatFeedbackText(f, guestPhone, this.config.adminUrl.replace(/\/$/, ''));
    const jobs: Promise<unknown>[] = [];

    const { telegramBotToken, telegramChatId, emailTo, emailFrom } = this.config.feedbackNotify;
    if (telegramBotToken && telegramChatId) jobs.push(this.telegram(telegramBotToken, telegramChatId, text, f.photoUrl));
    if (this.mailer && emailTo) {
      jobs.push(
        this.mailer.sendMail({
          from: emailFrom ?? 'History Coffee <no-reply@historycoffee.ru>',
          to: emailTo,
          subject: `${FEEDBACK_TYPE_LABEL[f.type]} из приложения History Coffee`,
          text: f.photoUrl ? `${text}\n\nФото: ${f.photoUrl}` : text,
        }),
      );
    }
    if (!jobs.length) {
      this.logger.log(`[dev] новое обращение ${f.id} (${f.type}) — каналы уведомлений не настроены`);
      return;
    }

    const results = await Promise.allSettled(jobs);
    for (const r of results) {
      if (r.status === 'rejected') this.logger.error(`Не удалось уведомить об обращении ${f.id}: ${String(r.reason)}`);
    }
  }

  private async telegram(token: string, chatId: string, text: string, photoUrl: string | null): Promise<void> {
    const base = `https://api.telegram.org/bot${token}`;
    // Подпись к фото ограничена 1024 символами — длинный текст отправляем отдельно.
    const usePhoto = photoUrl && text.length <= 1024;
    const res = await fetch(`${base}/${usePhoto ? 'sendPhoto' : 'sendMessage'}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(
        usePhoto
          ? { chat_id: chatId, photo: photoUrl, caption: text }
          : { chat_id: chatId, text: photoUrl ? `${text}\n\nФото: ${photoUrl}` : text, disable_web_page_preview: false },
      ),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`Telegram HTTP ${res.status}: ${await res.text()}`);
  }
}
