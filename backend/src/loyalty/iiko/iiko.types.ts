export interface IikoCard {
  track: string;
  number: string;
}

export interface IikoWallet {
  id: string;
  name: string;
  /** Тип кошелька в iiko (0 — депозит, 1 — бонусы и т.д.). Храним как есть. */
  type: number | string | null;
  balance: number;
}

export interface IikoCustomer {
  id: string;
  name: string | null;
  phone: string | null;
  cards: IikoCard[];
  walletBalances: IikoWallet[];
}

export interface IikoTransaction {
  id: string;
  /** ISO-дата. */
  date: string;
  /** Положительное — начисление, отрицательное — списание. */
  amount: number;
  kind: 'accrual' | 'redeem' | 'other';
  /** Человекочитаемое описание типа операции из iiko. */
  title: string;
  orderNumber: string | null;
  balanceAfter: number | null;
}

/**
 * Минимальный контракт с программой лояльности iiko (iikoCard через iikoCloud API).
 * Приложение только читает данные и выпускает виртуальную карту — начисление/списание
 * происходит на кассе iiko.
 */
export interface IikoLoyaltyClient {
  findCustomerByPhone(phone: string): Promise<IikoCustomer | null>;
  getCustomerById(id: string): Promise<IikoCustomer | null>;
  createOrUpdateCustomer(input: { phone: string; name?: string | null; birthday?: string | null }): Promise<string>;
  addCard(customerId: string, card: IikoCard): Promise<void>;
  getTransactions(customerId: string, from: Date, to: Date, page: number, pageSize: number): Promise<IikoTransaction[]>;
}

export const IIKO_CLIENT = Symbol('IIKO_CLIENT');

export class IikoUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'IikoUnavailableError';
  }
}
