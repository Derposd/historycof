import { IikoCloudClient, iikoDate, mapCustomer, mapTransaction } from './iiko-cloud.client';

describe('iikoDate', () => {
  it('форматирует в МСК без таймзоны', () => {
    expect(iikoDate(new Date('2026-09-28T05:30:00.000Z'))).toBe('2026-09-28 08:30:00.000');
  });
});

describe('mapCustomer', () => {
  it('берёт карты и кошельки', () => {
    const c = mapCustomer({
      id: 'c1',
      name: 'Анна',
      phone: '+79604316223',
      cards: [{ id: 'x', track: '770712345678', number: '770712345678' }],
      walletBalances: [{ id: 'w', name: 'Бонусы', type: 1, balance: 420.5 }],
    });
    expect(c).toEqual({
      id: 'c1',
      name: 'Анна',
      phone: '+79604316223',
      cards: [{ track: '770712345678', number: '770712345678' }],
      walletBalances: [{ id: 'w', name: 'Бонусы', type: 1, balance: 420.5 }],
    });
  });

  it('null без id', () => {
    expect(mapCustomer({})).toBeNull();
  });
});

describe('mapTransaction', () => {
  it('начисление', () => {
    expect(mapTransaction({ id: 't1', sum: 27, typeName: 'RefillWalletFromOrder', whenCreated: '2026-09-27 12:00:00.000', orderNumber: 15 })).toMatchObject({
      amount: 27,
      kind: 'accrual',
      orderNumber: '15',
      date: '2026-09-27T09:00:00.000Z',
    });
  });

  it('списание с положительной суммой — знак инвертируется', () => {
    expect(mapTransaction({ id: 't2', sum: 100, typeName: 'PayFromWallet', whenCreated: '2026-09-27 12:00:00.000' })).toMatchObject({
      amount: -100,
      kind: 'redeem',
    });
  });

  it('списание с отрицательной суммой', () => {
    expect(mapTransaction({ sum: -50, whenCreated: '2026-09-27T12:00:00Z' })).toMatchObject({ amount: -50, kind: 'redeem' });
  });

  it('без суммы — пропускается', () => {
    expect(mapTransaction({ whenCreated: '2026-09-27 12:00:00.000' })).toBeNull();
  });
});

describe('IikoCloudClient', () => {
  const json = (status: number, body: unknown) =>
    new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

  function client(handler: (path: string, body: any) => Response) {
    const calls: { path: string; body: any; auth?: string }[] = [];
    const fetchFn = (async (url: string, init: RequestInit) => {
      const path = new URL(url).pathname;
      const body = JSON.parse(String(init.body));
      calls.push({ path, body, auth: (init.headers as Record<string, string>).Authorization });
      return handler(path, body);
    }) as unknown as typeof fetch;
    const c = new IikoCloudClient({ baseUrl: 'https://iiko.test', apiLogin: 'login', organizationId: 'org' }, fetchFn);
    return { c, calls };
  }

  it('получает токен один раз и передаёт organizationId', async () => {
    const { c, calls } = client((path) =>
      path === '/api/1/access_token' ? json(200, { token: 'tkn' }) : json(200, { id: 'c1', cards: [], walletBalances: [] }),
    );
    await c.findCustomerByPhone('+79604316223');
    await c.findCustomerByPhone('+79604316223');
    expect(calls.filter((x) => x.path === '/api/1/access_token')).toHaveLength(1);
    expect(calls[1]).toMatchObject({
      path: '/api/1/loyalty/iiko/customer/info',
      body: { type: 'phone', phone: '+79604316223', organizationId: 'org' },
      auth: 'Bearer tkn',
    });
  });

  it('возвращает null, если гость не найден', async () => {
    const { c } = client((path) =>
      path === '/api/1/access_token' ? json(200, { token: 't' }) : json(400, { errorDescription: 'There is no user with phone +7...' }),
    );
    await expect(c.findCustomerByPhone('+79604316223')).resolves.toBeNull();
  });

  it('обновляет токен при 401', async () => {
    let tokens = 0;
    let infos = 0;
    const { c } = client((path) => {
      if (path === '/api/1/access_token') return json(200, { token: `t${++tokens}` });
      return ++infos === 1 ? json(401, {}) : json(200, { id: 'c1', cards: [], walletBalances: [] });
    });
    await expect(c.getCustomerById('c1')).resolves.toMatchObject({ id: 'c1' });
    expect(tokens).toBe(2);
  });

  it('прочие ошибки пробрасываются как недоступность', async () => {
    const { c } = client((path) => (path === '/api/1/access_token' ? json(200, { token: 't' }) : json(500, { message: 'boom' })));
    await expect(c.getCustomerById('c1')).rejects.toThrow('HTTP 500');
  });
});
