import { randomUUID } from 'node:crypto';
import { IikoCard, IikoCustomer, IikoLoyaltyClient, IikoTransaction } from './iiko.types';

/**
 * In-memory имитация iikoCard для разработки и тестов (IIKO_MODE=mock).
 * Новому гостю начисляется приветственный бонус, чтобы было что показать на экране.
 */
export class MockIikoClient implements IikoLoyaltyClient {
  private readonly customers = new Map<string, IikoCustomer>();
  private readonly transactions = new Map<string, IikoTransaction[]>();

  async findCustomerByPhone(phone: string): Promise<IikoCustomer | null> {
    return [...this.customers.values()].find((c) => c.phone === phone) ?? null;
  }

  async getCustomerById(id: string): Promise<IikoCustomer | null> {
    return this.customers.get(id) ?? null;
  }

  async createOrUpdateCustomer(input: { phone: string; name?: string | null }): Promise<string> {
    const existing = await this.findCustomerByPhone(input.phone);
    if (existing) {
      existing.name = input.name ?? existing.name;
      return existing.id;
    }
    const id = randomUUID();
    this.customers.set(id, {
      id,
      name: input.name ?? null,
      phone: input.phone,
      cards: [],
      walletBalances: [{ id: 'mock-wallet', name: 'Бонусы History', type: 1, balance: 150 }],
    });
    const now = Date.now();
    this.transactions.set(id, [
      {
        id: randomUUID(),
        date: new Date(now - 2 * 86400_000).toISOString(),
        amount: 150,
        kind: 'accrual',
        title: 'Приветственные бонусы (демо)',
        orderNumber: null,
        balanceAfter: 150,
      },
    ]);
    return id;
  }

  async addCard(customerId: string, card: IikoCard): Promise<void> {
    const c = this.customers.get(customerId);
    if (!c) throw new Error('customer not found');
    c.cards.push(card);
  }

  async getTransactions(customerId: string, from: Date, to: Date, page: number, pageSize: number): Promise<IikoTransaction[]> {
    const all = (this.transactions.get(customerId) ?? [])
      .filter((t) => {
        const d = new Date(t.date);
        return d >= from && d <= to;
      })
      .sort((a, b) => b.date.localeCompare(a.date));
    return all.slice(page * pageSize, (page + 1) * pageSize);
  }
}
