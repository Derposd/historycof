import { Inject, Injectable, Logger, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { and, eq, isNull } from 'drizzle-orm';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { DB, Db } from '../db/database.module';
import { Guest, guests } from '../db/schema';
import { randomDigits } from '../common/crypto';
import { IIKO_CLIENT, IikoCard, IikoCustomer, IikoLoyaltyClient, IikoTransaction, IikoUnavailableError } from './iiko/iiko.types';

export interface LoyaltyCard {
  /** Номер для отображения под кодом: «7707 1234 5678». */
  cardNumber: string;
  /** Что зашито в QR/штрихкод — трек карты iikoCard, кассир сканирует его на кассе. */
  barcode: string;
}

export interface LoyaltySummary {
  card: LoyaltyCard;
  balance: number;
  wallets: { name: string; balance: number }[];
  guestName: string | null;
}

@Injectable()
export class LoyaltyService {
  private readonly logger = new Logger(LoyaltyService.name);
  /** Короткий кэш, чтобы экран баланса не дёргал iiko на каждое открытие. */
  private readonly cache = new Map<string, { at: number; customer: IikoCustomer }>();
  private readonly cacheTtlMs = 30_000;

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(IIKO_CLIENT) private readonly iiko: IikoLoyaltyClient,
  ) {}

  private async guest(guestId: string): Promise<Guest & { phone: string }> {
    const [g] = await this.db
      .select()
      .from(guests)
      .where(and(eq(guests.id, guestId), isNull(guests.deletedAt)));
    if (!g?.phone) throw new NotFoundException('Профиль не найден');
    return g as Guest & { phone: string };
  }

  private async guard<T>(fn: () => Promise<T>): Promise<T> {
    try {
      return await fn();
    } catch (e) {
      if (e instanceof IikoUnavailableError) {
        this.logger.error(e.message);
        throw new ServiceUnavailableException({
          error: 'loyalty_unavailable',
          message: 'Бонусная программа временно недоступна. Попробуйте позже',
        });
      }
      throw e;
    }
  }

  /**
   * Находит или регистрирует гостя в iiko и гарантирует, что у него есть карта.
   * Если у гостя уже есть пластиковая/любая карта в iiko — используем её,
   * иначе выпускаем виртуальную карту приложения.
   */
  private async ensureCustomer(g: Guest & { phone: string }, fresh = false): Promise<{ customer: IikoCustomer; card: IikoCard }> {
    const cached = this.cache.get(g.id);
    if (!fresh && cached && Date.now() - cached.at < this.cacheTtlMs && cached.customer.cards.length) {
      return { customer: cached.customer, card: this.pickCard(cached.customer, g) };
    }

    let customer =
      (g.iikoCustomerId ? await this.iiko.getCustomerById(g.iikoCustomerId) : null) ??
      (await this.iiko.findCustomerByPhone(g.phone));

    if (!customer) {
      const id = await this.iiko.createOrUpdateCustomer({ phone: g.phone, name: g.name, birthday: g.birthday });
      customer = await this.iiko.getCustomerById(id);
      if (!customer) throw new IikoUnavailableError('iiko: гость создан, но не читается');
    }

    if (customer.cards.length === 0) {
      const card = await this.issueVirtualCard(customer.id);
      customer = { ...customer, cards: [card] };
    }

    const card = this.pickCard(customer, g);
    if (g.iikoCustomerId !== customer.id || g.iikoCardTrack !== card.track) {
      await this.db
        .update(guests)
        .set({ iikoCustomerId: customer.id, iikoCardTrack: card.track })
        .where(eq(guests.id, g.id));
    }
    this.cache.set(g.id, { at: Date.now(), customer });
    return { customer, card };
  }

  private pickCard(customer: IikoCustomer, g: Guest): IikoCard {
    return customer.cards.find((c) => c.track === g.iikoCardTrack) ?? customer.cards[0];
  }

  private async issueVirtualCard(customerId: string): Promise<IikoCard> {
    let lastError: unknown;
    for (let attempt = 0; attempt < 3; attempt++) {
      const track = `${this.config.iiko.virtualCardPrefix}${randomDigits(12 - this.config.iiko.virtualCardPrefix.length)}`;
      const [taken] = await this.db.select({ id: guests.id }).from(guests).where(eq(guests.iikoCardTrack, track));
      if (taken) continue;
      try {
        const card = { track, number: track };
        await this.iiko.addCard(customerId, card);
        return card;
      } catch (e) {
        lastError = e; // коллизия номера в iiko — пробуем другой
      }
    }
    throw lastError instanceof IikoUnavailableError ? lastError : new IikoUnavailableError('Не удалось выпустить карту');
  }

  async summary(guestId: string, refresh = false): Promise<LoyaltySummary> {
    const g = await this.guest(guestId);
    return this.guard(async () => {
      const { customer, card } = await this.ensureCustomer(g, refresh);
      const wallets = customer.walletBalances.map((w) => ({ name: w.name, balance: w.balance }));
      return {
        card: toCard(card),
        balance: wallets.reduce((s, w) => s + w.balance, 0),
        wallets,
        guestName: g.name ?? customer.name,
      };
    });
  }

  async card(guestId: string): Promise<LoyaltyCard> {
    const g = await this.guest(guestId);
    return this.guard(async () => toCard((await this.ensureCustomer(g)).card));
  }

  async transactions(guestId: string, page: number, pageSize: number, days = 365): Promise<{ items: IikoTransaction[]; hasMore: boolean }> {
    const g = await this.guest(guestId);
    return this.guard(async () => {
      const { customer } = await this.ensureCustomer(g);
      const to = new Date();
      const from = new Date(to.getTime() - days * 86400_000);
      const items = await this.iiko.getTransactions(customer.id, from, to, page, pageSize + 1);
      return { items: items.slice(0, pageSize), hasMore: items.length > pageSize };
    });
  }
}

function toCard(card: IikoCard): LoyaltyCard {
  const digits = card.number || card.track;
  return { cardNumber: digits.replace(/(.{4})(?=.)/g, '$1 '), barcode: card.track };
}
