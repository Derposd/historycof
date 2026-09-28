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
  whatsapp: string;
  instagram: string;
  website: string;
  legalName: string;
  hours: DayHours[];
}

/** Данные из брифа заказчика (сверено с historycoffee.ru). */
export const DEFAULT_VENUE: VenueInfo = {
  name: 'History Coffee',
  tagline: 'Место для ваших историй',
  address: 'г. Нальчик, ул. Толстого, 43',
  lat: null,
  lng: null,
  phone: '+79604316223',
  whatsapp: '+79604316223',
  instagram: 'history.coffee.ru',
  website: 'https://historycoffee.ru/',
  legalName: 'ИП Жабоева А. Т.',
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
    return { ...DEFAULT_VENUE, ...((row?.value as Partial<VenueInfo>) ?? {}) };
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
