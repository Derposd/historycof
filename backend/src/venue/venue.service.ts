import { Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { DB, Db } from '../db/database.module';
import { settings } from '../db/schema';
import { computeOpenState, DayHours, OpenState } from './hours';

export interface VenueInfo {
  name: string;
  tagline: string;
  address: string;
  /** Координаты точки на карте. null — строим маршрут по адресу. Уточнить у заказчика. */
  lat: number | null;
  lng: number | null;
  phone: string;
  /** WhatsApp (необязательно; пусто — кнопки в приложении нет). В РФ заблокирован с 02.2026 — работает через VPN. */
  whatsapp: string;
  website: string;
  hours: DayHours[];
  // ── Сведения о продавце (ЗоЗПП ст. 9) и об операторе ПДн (152-ФЗ) ──
  /** Наименование оператора (ИП или организация) — обязательно для согласия (ч. 4 ст. 9 152-ФЗ). */
  legalName: string;
  /** ИНН продавца (10 или 12 цифр) — показывается, если заполнен. */
  inn: string;
  /** ОГРН (13 цифр) или ОГРНИП (15 цифр) — показывается, если заполнен. */
  ogrn: string;
  /** Адрес оператора; пусто — используется адрес кофейни. */
  legalAddress: string;
  /** Почта для запросов по персональным данным (необязательно). */
  privacyEmail: string;
}

/** Поля, которые раньше были в настройках и больше не используются. */
const REMOVED_FIELDS = ['instagram', 'telegram', 'vk', 'processors', 'loyaltyRules'];

/** Данные из брифа заказчика (сверено с historycoffee.ru). */
export const DEFAULT_VENUE: VenueInfo = {
  name: 'History Coffee',
  tagline: 'Место для ваших историй',
  address: 'г. Нальчик, ул. Толстого, 43',
  lat: null,
  lng: null,
  phone: '+79604316223',
  whatsapp: '+79604316223',
  website: 'https://historycoffee.ru/',
  legalName: 'ИП Жабоева А. Т.',
  inn: '',
  ogrn: '',
  legalAddress: '',
  privacyEmail: '',
  hours: [
    { day: 1, open: '08:00', close: '23:00' },
    { day: 2, open: '08:00', close: '23:00' },
    { day: 3, open: '08:00', close: '23:00' },
    { day: 4, open: '08:00', close: '23:00' },
    { day: 5, open: '08:00', close: '23:00' },
    { day: 6, open: '09:00', close: '23:00' },
    { day: 7, open: '09:00', close: '23:00' },
  ],
};

const KEY = 'venue';

@Injectable()
export class VenueService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async get(): Promise<VenueInfo> {
    const [row] = await this.db.select().from(settings).where(eq(settings.key, KEY));
    const stored = { ...((row?.value as Record<string, unknown>) ?? {}) };
    // Instagram убран: Meta признана в РФ экстремистской (наказывают даже за ссылки). Telegram и VK —
    // по решению заказчика. WhatsApp (не запрещён, но заблокирован) — необязательное поле.
    for (const k of REMOVED_FIELDS) delete stored[k];
    const venue = { ...DEFAULT_VENUE, ...(stored as Partial<VenueInfo>) };
    // Адрес продавца по умолчанию — адрес кофейни (показываем в админке настоящее значение)
    if (!venue.legalAddress?.trim()) venue.legalAddress = venue.address;
    return venue;
  }

  async getWithStatus(now = new Date()): Promise<VenueInfo & { timezone: string; openState: OpenState }> {
    const venue = await this.get();
    return { ...venue, timezone: this.config.timezone, openState: computeOpenState(venue.hours, now, this.config.timezone) };
  }

  async update(patch: Partial<VenueInfo>): Promise<VenueInfo> {
    const next = { ...(await this.get()), ...patch };
    await this.db
      .insert(settings)
      .values({ key: KEY, value: next })
      .onConflictDoUpdate({ target: settings.key, set: { value: next, updatedAt: new Date() } });
    return next;
  }
}
