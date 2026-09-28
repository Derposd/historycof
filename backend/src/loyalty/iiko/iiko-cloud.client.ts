import { Logger } from '@nestjs/common';
import { IikoCard, IikoCustomer, IikoLoyaltyClient, IikoTransaction, IikoUnavailableError, IikoWallet } from './iiko.types';

type FetchFn = typeof fetch;

/**
 * Клиент iikoCloud API (https://api-ru.iiko.services/docs).
 *
 * ВНИМАНИЕ: схема ответов по транзакциям различается между версиями API и настройками
 * программы — маппинг сделан защитно (см. mapTransaction). После получения доступа
 * к реальной организации сверить поля на живых данных (docs/iiko-integration.md).
 */
export class IikoCloudClient implements IikoLoyaltyClient {
  private readonly logger = new Logger('iikoCloud');
  private token: { value: string; expiresAt: number } | null = null;

  constructor(
    private readonly opts: { baseUrl: string; apiLogin: string; organizationId: string },
    private readonly fetchFn: FetchFn = fetch,
  ) {}

  private async accessToken(): Promise<string> {
    // Токен живёт ~60 минут; обновляем с запасом.
    if (this.token && this.token.expiresAt > Date.now()) return this.token.value;
    const res = await this.raw('/api/1/access_token', { apiLogin: this.opts.apiLogin }, false);
    const token = (res as { token?: string }).token;
    if (!token) throw new IikoUnavailableError('iiko: пустой access_token');
    this.token = { value: token, expiresAt: Date.now() + 45 * 60_000 };
    return token;
  }

  private async raw(path: string, body: unknown, auth = true, retried = false): Promise<unknown> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (auth) headers.Authorization = `Bearer ${await this.accessToken()}`;

    let res: Response;
    try {
      res = await this.fetchFn(`${this.opts.baseUrl.replace(/\/$/, '')}${path}`, {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(15_000),
      });
    } catch (e) {
      throw new IikoUnavailableError(`iiko недоступен: ${(e as Error).message}`);
    }

    if (res.status === 401 && auth && !retried) {
      this.token = null;
      return this.raw(path, body, auth, true);
    }

    const text = await res.text();
    const json = text ? safeJson(text) : {};
    if (!res.ok) {
      const err = new IikoHttpError(res.status, json, path);
      this.logger.warn(`${path} → ${res.status}: ${err.description}`);
      throw err;
    }
    return json;
  }

  private withOrg<T extends object>(body: T): T & { organizationId: string } {
    return { ...body, organizationId: this.opts.organizationId };
  }

  async findCustomerByPhone(phone: string): Promise<IikoCustomer | null> {
    return this.info({ type: 'phone', phone });
  }

  async getCustomerById(id: string): Promise<IikoCustomer | null> {
    return this.info({ type: 'id', id });
  }

  private async info(query: Record<string, string>): Promise<IikoCustomer | null> {
    try {
      const res = await this.raw('/api/1/loyalty/iiko/customer/info', this.withOrg(query));
      return mapCustomer(res);
    } catch (e) {
      if (e instanceof IikoHttpError && e.isNotFound) return null;
      throw e;
    }
  }

  async createOrUpdateCustomer(input: { phone: string; name?: string | null; birthday?: string | null }): Promise<string> {
    const res = (await this.raw(
      '/api/1/loyalty/iiko/customer/create_or_update',
      this.withOrg({
        phone: input.phone,
        name: input.name ?? undefined,
        // iiko ожидает "yyyy-MM-dd HH:mm:ss.fff"
        birthday: input.birthday ? `${input.birthday} 00:00:00.000` : undefined,
        // Согласие на обработку ПДн получено в приложении.
        consentStatus: 1,
      }),
    )) as { id?: string };
    if (!res.id) throw new IikoUnavailableError('iiko: create_or_update не вернул id');
    return res.id;
  }

  async addCard(customerId: string, card: IikoCard): Promise<void> {
    await this.raw(
      '/api/1/loyalty/iiko/customer/card/add',
      this.withOrg({ customerId, cardTrack: card.track, cardNumber: card.number }),
    );
  }

  async getTransactions(customerId: string, from: Date, to: Date, page: number, pageSize: number): Promise<IikoTransaction[]> {
    const res = (await this.raw(
      '/api/1/loyalty/iiko/customer/transactions/by_date',
      this.withOrg({
        customerId,
        dateFrom: iikoDate(from),
        dateTo: iikoDate(to),
        pageNumber: page,
        pageSize,
      }),
    )) as { transactions?: unknown[] };
    return (res.transactions ?? []).map(mapTransaction).filter((t): t is IikoTransaction => t !== null);
  }
}

export class IikoHttpError extends IikoUnavailableError {
  constructor(
    public readonly status: number,
    public readonly body: unknown,
    path: string,
  ) {
    super(`iiko ${path} → HTTP ${status}`);
  }

  get description(): string {
    const b = this.body as { errorDescription?: string; error?: string; message?: string } | null;
    return b?.errorDescription ?? b?.message ?? b?.error ?? '';
  }

  /** iiko отвечает 400 с текстом ошибки, если гость не найден. */
  get isNotFound(): boolean {
    return this.status === 404 || (this.status === 400 && /not\s*found|no\s*user|не\s*найден|doesn.?t\s*exist/i.test(this.description));
  }
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return { message: text.slice(0, 500) };
  }
}

/** Дата в формате iiko: "yyyy-MM-dd HH:mm:ss.fff" (время организации — МСК). */
export function iikoDate(d: Date): string {
  const msk = new Date(d.getTime() + 3 * 3600_000);
  return msk.toISOString().replace('T', ' ').replace('Z', '');
}

const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : typeof v === 'string' && v.trim() !== '' && Number.isFinite(Number(v)) ? Number(v) : null);
const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);

export function mapCustomer(raw: unknown): IikoCustomer | null {
  const r = raw as Record<string, unknown> | null;
  const id = str(r?.id);
  if (!r || !id) return null;
  const cards = Array.isArray(r.cards) ? r.cards : [];
  const wallets = Array.isArray(r.walletBalances) ? r.walletBalances : [];
  return {
    id,
    name: str(r.name),
    phone: str(r.phone),
    cards: cards
      .map((c: Record<string, unknown>) => ({ track: str(c.track) ?? str(c.number) ?? '', number: str(c.number) ?? str(c.track) ?? '' }))
      .filter((c) => c.track !== ''),
    walletBalances: wallets.map(
      (w: Record<string, unknown>): IikoWallet => ({
        id: str(w.id) ?? '',
        name: str(w.name) ?? 'Бонусы',
        type: (w.type as number | string | undefined) ?? null,
        balance: num(w.balance) ?? 0,
      }),
    ),
  };
}

const REDEEM_HINT = /pay|withdraw|writeoff|write_off|списан|оплат|refill.?cancel/i;
const ACCRUAL_HINT = /refill|accrual|bonus|начисл|пополн|reward/i;

export function mapTransaction(raw: unknown): IikoTransaction | null {
  const r = raw as Record<string, unknown> | null;
  if (!r) return null;
  const sum = num(r.sum) ?? num(r.amount) ?? num(r.value);
  const date = str(r.whenCreated) ?? str(r.whenCreatedOrder) ?? str(r.date);
  if (sum === null || !date) return null;

  const typeLabel = str(r.typeName) ?? str(r.type) ?? '';
  let amount = sum;
  if (sum > 0 && REDEEM_HINT.test(typeLabel) && !ACCRUAL_HINT.test(typeLabel)) amount = -sum;

  const kind: IikoTransaction['kind'] = amount > 0 ? 'accrual' : amount < 0 ? 'redeem' : 'other';
  return {
    id: str(r.id) ?? `${date}:${sum}`,
    date: new Date(date.includes('T') ? date : `${date.replace(' ', 'T')}+03:00`).toISOString(),
    amount,
    kind,
    title: kind === 'accrual' ? 'Начисление бонусов' : kind === 'redeem' ? 'Списание бонусов' : typeLabel || 'Операция',
    orderNumber: r.orderNumber !== undefined && r.orderNumber !== null ? String(r.orderNumber) : null,
    balanceAfter: num(r.balanceAfter) ?? num(r.posBalance) ?? null,
  };
}
