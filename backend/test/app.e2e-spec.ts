import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Client } from 'pg';
import sharp from 'sharp';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { SMS_PROVIDER, SmsProvider } from '../src/auth/sms/sms.provider';
import { loadConfig } from '../src/config/configuration';
import { runMigrations } from '../src/db/migrate';
import { RetentionService } from '../src/retention/retention.service';
import { configureApp } from '../src/main';

const DATABASE_URL = process.env.DATABASE_URL_TEST ?? 'postgres://history:history@localhost:5432/history_test';

class CapturingSms implements SmsProvider {
  last = new Map<string, string>();
  async send(phone: string, text: string) {
    this.last.set(phone, text.match(/\d{4}/)![0]);
  }
}

describe('History Coffee API (e2e)', () => {
  let app: NestExpressApplication;
  let http: ReturnType<typeof request>;
  const sms = new CapturingSms();
  let staffToken: string;
  let editorToken: string;

  beforeAll(async () => {
    const pg = new Client({ connectionString: DATABASE_URL });
    await pg.connect();
    await pg.query('drop schema if exists public cascade; drop schema if exists drizzle cascade; create schema public;');
    await pg.end();
    await runMigrations(DATABASE_URL);

    const config = loadConfig({
      NODE_ENV: 'test',
      DATABASE_URL,
      OTP_RESEND_COOLDOWN_SEC: '0',
      OTP_MAX_PER_HOUR: '100',
      OTP_REVIEW_PHONE: '+79990000000',
      OTP_REVIEW_CODE: '1234',
      OTP_TEST_ACCOUNTS: '+79990000001:2580, +79990000002:1470',
      ADMIN_BOOTSTRAP_EMAIL: 'owner@historycoffee.ru',
      ADMIN_BOOTSTRAP_PASSWORD: 'super-secret-password',
      STORAGE_LOCAL_DIR: mkdtempSync(join(tmpdir(), 'hc-uploads-')),
      PUBLIC_URL: 'http://api.test',
    });

    const moduleRef = await Test.createTestingModule({ imports: [AppModule.forRoot(config)] })
      .overrideProvider(SMS_PROVIDER)
      .useValue(sms)
      .compile();
    app = moduleRef.createNestApplication<NestExpressApplication>();
    configureApp(app);
    await app.init();
    http = request(app.getHttpServer());
  });

  afterAll(async () => {
    await app?.close();
  });

  async function loginGuest(phone: string, extra: Record<string, unknown> = { acceptPrivacyPolicy: true }) {
    await http.post('/api/v1/auth/otp/request').send({ phone }).expect(200);
    const normalized = `+7${phone.replace(/\D/g, '').slice(-10)}`;
    const res = await http
      .post('/api/v1/auth/otp/verify')
      .send({ phone, code: sms.last.get(normalized), ...extra })
      .expect(200);
    return res.body as { accessToken: string; refreshToken: string; guest: { id: string } };
  }

  /** Прямой запрос к тестовой базе — проверить, что данные действительно записаны или удалены. */
  const q = async (sql: string, params: unknown[] = []) => {
    const pg = new Client({ connectionString: DATABASE_URL });
    await pg.connect();
    try {
      return (await pg.query(sql, params)).rows;
    } finally {
      await pg.end();
    }
  };

  describe('health & public', () => {
    it('GET /health', () => http.get('/health').expect(200, { status: 'ok' }));

    it('GET /venue — контакты и статус', async () => {
      const res = await http.get('/api/v1/venue').expect(200);
      expect(res.body).toMatchObject({
        address: 'г. Нальчик, ул. Толстого, 43',
        phone: '+79604316223',
        timezone: 'Europe/Moscow',
      });
      expect(typeof res.body.openState.isOpen).toBe('boolean');
    });

    it('GET /legal/privacy', async () => {
      const res = await http.get('/api/v1/legal/privacy').expect(200);
      expect(res.body.markdown).toContain('152-ФЗ');
    });
  });

  describe('auth гостя', () => {
    it('отклоняет неверный номер', () =>
      http.post('/api/v1/auth/otp/request').send({ phone: '123' }).expect(400));

    it('новому гостю нужно согласие на обработку ПДн', async () => {
      const phone = '+7 (900) 111-22-33';
      const req = await http.post('/api/v1/auth/otp/request').send({ phone }).expect(200);
      expect(req.body.isNewUser).toBe(true);
      const res = await http
        .post('/api/v1/auth/otp/verify')
        .send({ phone, code: sms.last.get('+79001112233') })
        .expect(400);
      expect(res.body.error).toBe('consent_required');
    });

    it('неверный код уменьшает число попыток', async () => {
      await http.post('/api/v1/auth/otp/request').send({ phone: '89001112244' }).expect(200);
      const real = sms.last.get('+79001112244')!;
      const wrong = real === '0000' ? '1111' : '0000';
      const res = await http
        .post('/api/v1/auth/otp/verify')
        .send({ phone: '89001112244', code: wrong, acceptPrivacyPolicy: true })
        .expect(400);
      expect(res.body).toMatchObject({ error: 'otp_invalid', attemptsLeft: 4 });
    });

    it('регистрация, профиль, refresh с ротацией, logout', async () => {
      const auth = await loginGuest('9001112255', { acceptPrivacyPolicy: true, name: 'Мадина' });
      const me = await http.get('/api/v1/me').set('Authorization', `Bearer ${auth.accessToken}`).expect(200);
      expect(me.body).toMatchObject({ phone: '+79001112255', name: 'Мадина', consentRequired: false });

      const refreshed = await http.post('/api/v1/auth/refresh').send({ refreshToken: auth.refreshToken }).expect(200);
      expect(refreshed.body.accessToken).toBeTruthy();
      // старый refresh больше не работает
      await http.post('/api/v1/auth/refresh').send({ refreshToken: auth.refreshToken }).expect(401);

      await http.post('/api/v1/auth/logout').send({ refreshToken: refreshed.body.refreshToken }).expect(204);
      await http.post('/api/v1/auth/refresh').send({ refreshToken: refreshed.body.refreshToken }).expect(401);
    });

    it('повторный вход существующего гостя не требует согласия', async () => {
      await loginGuest('9001112266');
      const again = await loginGuest('9001112266', {});
      expect(again.accessToken).toBeTruthy();
    });

    it('тестовый номер для ревью сторов входит с фиксированным кодом без SMS', async () => {
      await http.post('/api/v1/auth/otp/request').send({ phone: '+79990000000' }).expect(200);
      expect(sms.last.has('+79990000000')).toBe(false);
      await http
        .post('/api/v1/auth/otp/verify')
        .send({ phone: '+79990000000', code: '1234', acceptPrivacyPolicy: true })
        .expect(200);
    });

    it('тестовые аккаунты из OTP_TEST_ACCOUNTS входят со своими кодами', async () => {
      for (const [phone, code] of [['+79990000001', '2580'], ['+79990000002', '1470']]) {
        await http.post('/api/v1/auth/otp/request').send({ phone }).expect(200);
        expect(sms.last.has(phone)).toBe(false);
        await http.post('/api/v1/auth/otp/verify').send({ phone, code, acceptPrivacyPolicy: true }).expect(200);
      }
    });

    it('без токена /me недоступен', () => http.get('/api/v1/me').expect(401));

    it('удаление аккаунта обезличивает данные', async () => {
      const auth = await loginGuest('9001112277');
      await http.delete('/api/v1/me').set('Authorization', `Bearer ${auth.accessToken}`).expect(204);
      await http.get('/api/v1/me').set('Authorization', `Bearer ${auth.accessToken}`).expect(404);
      await http.post('/api/v1/auth/refresh').send({ refreshToken: auth.refreshToken }).expect(401);
      // тот же номер может зарегистрироваться заново
      const req = await http.post('/api/v1/auth/otp/request').send({ phone: '9001112277' }).expect(200);
      expect(req.body.isNewUser).toBe(true);
    });
  });

  describe('админка: вход и роли', () => {
    it('первый админ создаётся из env и входит', async () => {
      await http.post('/api/v1/admin/auth/login').send({ email: 'owner@historycoffee.ru', password: 'wrong' }).expect(401);
      const res = await http
        .post('/api/v1/admin/auth/login')
        .send({ email: 'OWNER@historycoffee.ru', password: 'super-secret-password' })
        .expect(200);
      expect(res.body.user.role).toBe('admin');
      staffToken = res.body.accessToken;
    });

    it('админ создаёт редактора; редактору закрыт раздел сотрудников и настройки', async () => {
      await http
        .post('/api/v1/admin/staff')
        .set('Authorization', `Bearer ${staffToken}`)
        .send({ email: 'barista@historycoffee.ru', name: 'Бариста', password: 'barista-password', role: 'editor' })
        .expect(201);
      const login = await http
        .post('/api/v1/admin/auth/login')
        .send({ email: 'barista@historycoffee.ru', password: 'barista-password' })
        .expect(200);
      editorToken = login.body.accessToken;
      await http.get('/api/v1/admin/staff').set('Authorization', `Bearer ${editorToken}`).expect(403);
      await http.put('/api/v1/admin/venue').set('Authorization', `Bearer ${editorToken}`).send({ tagline: 'x' }).expect(403);
      await http.get('/api/v1/admin/staff/me').set('Authorization', `Bearer ${editorToken}`).expect(200);
    });

    it('токен гостя не открывает админку', async () => {
      const guest = await loginGuest('9001112288');
      await http.get('/api/v1/admin/news').set('Authorization', `Bearer ${guest.accessToken}`).expect(401);
    });
  });

  describe('новости', () => {
    it('черновик не виден в ленте, после публикации — виден', async () => {
      const created = await http
        .post('/api/v1/admin/news')
        .set('Authorization', `Bearer ${editorToken}`)
        .send({ title: 'Осеннее меню', body: 'Тыквенный латте уже в кофейне' })
        .expect(201);
      expect(created.body.status).toBe('draft');

      let feed = await http.get('/api/v1/news').expect(200);
      expect(feed.body.items.find((n: { id: string }) => n.id === created.body.id)).toBeUndefined();

      const published = await http
        .post(`/api/v1/admin/news/${created.body.id}/publish`)
        .set('Authorization', `Bearer ${editorToken}`)
        .send({ notify: true })
        .expect(200);
      expect(published.body.pushedAt).toBeTruthy();

      feed = await http.get('/api/v1/news').expect(200);
      expect(feed.body.items[0]).toMatchObject({ title: 'Осеннее меню' });
      await http.get(`/api/v1/news/${created.body.id}`).expect(200);

      await http.delete(`/api/v1/admin/news/${created.body.id}`).set('Authorization', `Bearer ${editorToken}`).expect(204);
      await http.get(`/api/v1/news/${created.body.id}`).expect(404);
    });

    it('пагинация по курсору', async () => {
      for (let i = 0; i < 3; i++) {
        await http
          .post('/api/v1/admin/news')
          .set('Authorization', `Bearer ${staffToken}`)
          .send({ title: `Пост ${i}`, body: 'текст', publish: true, notify: false })
          .expect(201);
        await new Promise((r) => setTimeout(r, 5));
      }
      const first = await http.get('/api/v1/news?limit=2').expect(200);
      expect(first.body.items.map((n: { title: string }) => n.title)).toEqual(['Пост 2', 'Пост 1']);
      const second = await http.get(`/api/v1/news?limit=2&before=${encodeURIComponent(first.body.nextBefore)}`).expect(200);
      expect(second.body.items.map((n: { title: string }) => n.title)).toEqual(['Пост 0']);
      expect(second.body.nextBefore).toBeNull();
    });

    it('валидация', () =>
      http.post('/api/v1/admin/news').set('Authorization', `Bearer ${staffToken}`).send({ title: '' }).expect(400));
  });

  describe('меню', () => {
    it('CMS: раздел → категория → позиция с двумя ценами и бейджами', async () => {
      const auth = { Authorization: `Bearer ${editorToken}` };
      const section = await http.post('/api/v1/admin/menu/sections').set(auth).send({ slug: 'bar', title: 'Бар' }).expect(201);
      await http.post('/api/v1/admin/menu/sections').set(auth).send({ slug: 'bar', title: 'Бар 2' }).expect(409);
      const category = await http
        .post('/api/v1/admin/menu/categories')
        .set(auth)
        .send({ sectionId: section.body.id, title: 'Кофе' })
        .expect(201);
      const item = await http
        .post('/api/v1/admin/menu/items')
        .set(auth)
        .send({
          categoryId: category.body.id,
          title: 'Капучино',
          prices: [
            { label: 'S', amount: 270 },
            { label: 'L', amount: 290 },
          ],
          badges: ['bestseller', 'bestseller', 'story'],
          story: 'Легенда блюда',
        })
        .expect(201);
      expect(item.body.badges).toEqual(['bestseller', 'story']);

      await http
        .post('/api/v1/admin/menu/items')
        .set(auth)
        .send({ categoryId: category.body.id, title: 'X', prices: [], badges: ['unknown'] })
        .expect(400);

      const hidden = await http
        .post('/api/v1/admin/menu/items')
        .set(auth)
        .send({ categoryId: category.body.id, title: 'Сезонный раф', prices: [{ label: '', amount: 350 }], available: false })
        .expect(201);

      const menu = await http.get('/api/v1/menu').expect(200);
      expect(menu.body.disclaimer).toContain('информационный характер');
      const bar = menu.body.sections.find((s: { slug: string }) => s.slug === 'bar');
      const items = bar.categories[0].items;
      expect(items.map((i: { title: string }) => i.title)).toEqual(['Капучино']);
      expect(items[0].prices).toEqual([
        { label: 'S', amount: 270 },
        { label: 'L', amount: 290 },
      ]);

      await http.patch(`/api/v1/admin/menu/items/${hidden.body.id}`).set(auth).send({ available: true }).expect(200);
      await http
        .put('/api/v1/admin/menu/reorder/items')
        .set(auth)
        .send({ ids: [hidden.body.id, item.body.id] })
        .expect(204);
      const menu2 = await http.get('/api/v1/menu').expect(200);
      const bar2 = menu2.body.sections.find((s: { slug: string }) => s.slug === 'bar');
      expect(bar2.categories[0].items.map((i: { title: string }) => i.title)).toEqual(['Сезонный раф', 'Капучино']);
    });
  });

  describe('лояльность (mock iiko)', () => {
    it('выпускает виртуальную карту и отдаёт баланс/историю', async () => {
      const guest = await loginGuest('9001113300');
      const auth = { Authorization: `Bearer ${guest.accessToken}` };
      const summary = await http.get('/api/v1/loyalty').set(auth).expect(200);
      expect(summary.body.balance).toBe(150);
      expect(summary.body.card.barcode).toMatch(/^7707\d{8}$/);
      expect(summary.body.card.cardNumber).toMatch(/^7707 \d{4} \d{4}$/);

      const card = await http.get('/api/v1/loyalty/card').set(auth).expect(200);
      expect(card.body.barcode).toBe(summary.body.card.barcode);

      const tx = await http.get('/api/v1/loyalty/transactions').set(auth).expect(200);
      expect(tx.body.items[0]).toMatchObject({ amount: 150, kind: 'accrual' });
      expect(tx.body.hasMore).toBe(false);
    });

    it('требует входа', () => http.get('/api/v1/loyalty').expect(401));
  });

  describe('обратная связь', () => {
    it('анонимная жалоба с фото; гость видит статус и ответ', async () => {
      const png = await sharp({ create: { width: 40, height: 30, channels: 3, background: '#8A9770' } }).png().toBuffer();

      await http
        .post('/api/v1/feedback')
        .field('type', 'complaint')
        .field('message', 'Долго ждали заказ')
        .field('contactPhone', '8 (900) 555-44-33')
        .attach('photo', png, { filename: 'photo.png', contentType: 'image/png' })
        .expect(201)
        .expect((res) => {
          expect(res.body.photoUrl).toMatch(/^http:\/\/api\.test\/uploads\/feedback\/.+\.jpg$/);
          expect(res.body.status).toBe('sent');
        });

      const guest = await loginGuest('9001114400');
      const gAuth = { Authorization: `Bearer ${guest.accessToken}` };
      const created = await http
        .post('/api/v1/feedback')
        .set(gAuth)
        .field('type', 'thanks')
        .field('message', 'Спасибо за чудесный завтрак!')
        .expect(201);

      await http.post('/api/v1/feedback').field('type', 'spam').field('message', 'xxx').expect(400);

      const sAuth = { Authorization: `Bearer ${editorToken}` };
      // ровно такой запрос делает админка: фильтр + страница
      const list = await http.get('/api/v1/admin/feedback?page=0&pageSize=30&status=sent').set(sAuth).expect(200);
      await http.get('/api/v1/admin/feedback?page=0&pageSize=30').set(sAuth).expect(200);
      await http.get('/api/v1/admin/feedback?pageSize=500').set(sAuth).expect(400);
      expect(list.body.total).toBe(2);
      expect(list.body.items.find((f: { id: string }) => f.id === created.body.id).guestPhone).toBe('+79001114400');

      const opened = await http.get(`/api/v1/admin/feedback/${created.body.id}`).set(sAuth).expect(200);
      expect(opened.body.status).toBe('viewed');

      let mine = await http.get('/api/v1/feedback/mine').set(gAuth).expect(200);
      expect(mine.body[0].status).toBe('viewed');

      await http
        .patch(`/api/v1/admin/feedback/${created.body.id}`)
        .set(sAuth)
        .send({ reply: 'Спасибо! Ждём вас снова' })
        .expect(200);
      mine = await http.get('/api/v1/feedback/mine').set(gAuth).expect(200);
      expect(mine.body[0]).toMatchObject({ status: 'answered', reply: 'Спасибо! Ждём вас снова' });
    });
  });

  describe('настройки заведения и аналитика', () => {
    it('админ меняет часы работы', async () => {
      const auth = { Authorization: `Bearer ${staffToken}` };
      await http
        .put('/api/v1/admin/venue')
        .set(auth)
        .send({ hours: [{ day: 1, open: '8:00', close: '23:00' }] })
        .expect(400);
      const res = await http.put('/api/v1/admin/venue').set(auth).send({ lat: 43.48, lng: 43.6 }).expect(200);
      expect(res.body).toMatchObject({ lat: 43.48, lng: 43.6, address: 'г. Нальчик, ул. Толстого, 43' });
    });

    it('сводка для дашборда', async () => {
      const res = await http.get('/api/v1/admin/analytics/summary').set('Authorization', `Bearer ${staffToken}`).expect(200);
      expect(res.body.guests.total).toBeGreaterThan(0);
      expect(res.body.guests.loyaltyLinked).toBe(1);
      expect(res.body.feedback.open).toBe(1);
    });

    it('загрузка картинки для новости', async () => {
      const jpg = await sharp({ create: { width: 3000, height: 2000, channels: 3, background: '#FBF7EF' } }).jpeg().toBuffer();
      const res = await http
        .post('/api/v1/admin/uploads?folder=news')
        .set('Authorization', `Bearer ${editorToken}`)
        .attach('file', jpg, { filename: 'a.jpg', contentType: 'image/jpeg' })
        .expect(201);
      const path = new URL(res.body.url).pathname;
      const img = await http.get(path).expect(200);
      const meta = await sharp(img.body as Buffer).metadata();
      expect(meta.width).toBe(1600);
    });
  });

  describe('чат с кофейней', () => {
    it('гость пишет, сотрудник видит, отвечает, гость получает ответ', async () => {
      const g = await loginGuest('9005550201', { acceptPersonalData: true, name: 'Амина' });
      const guest = { Authorization: `Bearer ${g.accessToken}` };
      const staff = { Authorization: `Bearer ${staffToken}` };

      await http.get('/api/v1/chat').expect(401);
      await http.post('/api/v1/chat').set(guest).send({ text: '' }).expect(400);
      await http.post('/api/v1/chat').set(guest).send({ text: '  Здравствуйте! Есть овсяное молоко?  ' }).expect(201);

      const before = await http.get('/api/v1/admin/chats/unread').set(staff).expect(200);
      expect(before.body.count).toBeGreaterThanOrEqual(1);
      const threads = await http.get('/api/v1/admin/chats').set(staff).expect(200);
      const t = threads.body.find((x: { guestId: string }) => x.guestId === g.guest.id);
      expect(t).toMatchObject({ guestName: 'Амина', guestPhone: '+79005550201', lastText: 'Здравствуйте! Есть овсяное молоко?', unread: 1 });

      const opened = await http.get(`/api/v1/admin/chats/${g.guest.id}`).set(staff).expect(200);
      expect(opened.body.messages).toHaveLength(1);
      const after = await http.get('/api/v1/admin/chats').set(staff).expect(200);
      expect(after.body.find((x: { guestId: string }) => x.guestId === g.guest.id).unread).toBe(0);

      await http.post(`/api/v1/admin/chats/${g.guest.id}`).set(staff).send({ text: 'Да, есть 🙂' }).expect(201);
      expect((await http.get('/api/v1/chat/unread').set(guest).expect(200)).body.count).toBe(1);
      const mine = await http.get('/api/v1/chat').set(guest).expect(200);
      expect(mine.body.map((m: { fromStaff: boolean; text: string }) => [m.fromStaff, m.text])).toEqual([
        [false, 'Здравствуйте! Есть овсяное молоко?'],
        [true, 'Да, есть 🙂'],
      ]);
      expect((await http.get('/api/v1/chat/unread').set(guest).expect(200)).body.count).toBe(0);
      // гости не видят чужие диалоги и не пишут в админку
      await http.get('/api/v1/admin/chats').set(guest).expect(401);
    });

    it('удаление аккаунта удаляет переписку', async () => {
      const g = await loginGuest('9005550202', { acceptPersonalData: true });
      await http.post('/api/v1/chat').set('Authorization', `Bearer ${g.accessToken}`).send({ text: 'Привет' }).expect(201);
      await http.delete('/api/v1/me').set('Authorization', `Bearer ${g.accessToken}`).expect(204);
      expect(await q('select 1 from chat_messages where guest_id = $1', [g.guest.id])).toHaveLength(0);
      await http.post(`/api/v1/admin/chats/${g.guest.id}`).set('Authorization', `Bearer ${staffToken}`).send({ text: 'Ответ' }).expect(404);
    });
  });

  describe('законы РФ', () => {
    it('вход только по российскому мобильному номеру (149-ФЗ, 406-ФЗ)', async () => {
      // Казахстан тоже +7, но 7xx — не пускаем; городской 495 — тоже нет
      for (const phone of ['+77011234567', '+74951234567']) {
        const res = await http.post('/api/v1/auth/otp/request').send({ phone }).expect(400);
        expect(res.body.error).toBe('phone_invalid');
      }
    });

    it('согласие на ПДн записывается в журнал; реклама — только отдельно и по желанию', async () => {
      const a = await loginGuest('9005550101', { acceptPersonalData: true });
      const me = await http.get('/api/v1/me').set('Authorization', `Bearer ${a.accessToken}`).expect(200);
      expect(me.body.pushNewsEnabled).toBe(false);
      expect(me.body.consentRequired).toBe(false);
      const rows = await q('select kind, version, revoked_at, user_agent from consents where guest_id = $1', [a.guest.id]);
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ kind: 'pd', revoked_at: null });

      const b = await loginGuest('9005550102', { acceptPersonalData: true, acceptMarketing: true });
      const meB = await http.get('/api/v1/me').set('Authorization', `Bearer ${b.accessToken}`).expect(200);
      expect(meB.body.pushNewsEnabled).toBe(true);
      const kinds = (await q('select kind from consents where guest_id = $1 and revoked_at is null', [b.guest.id])).map(
        (r: { kind: string }) => r.kind,
      );
      expect(kinds.sort()).toEqual(['marketing', 'pd']);

      // Отзыв согласия на рекламу — выключатель в профиле
      await http.patch('/api/v1/me').set('Authorization', `Bearer ${b.accessToken}`).send({ pushNewsEnabled: false }).expect(200);
      const active = await q("select 1 from consents where guest_id = $1 and kind = 'marketing' and revoked_at is null", [b.guest.id]);
      expect(active).toHaveLength(0);
    });

    it('устройства для уведомлений — только у вошедших гостей', () =>
      http.post('/api/v1/devices').send({ token: 'anon-token', platform: 'android' }).expect(401));

    it('документы: политика, согласие, реклама, правила бонусов; есть HTML-страницы', async () => {
      for (const kind of ['privacy', 'consent', 'marketing', 'loyalty']) {
        const res = await http.get(`/api/v1/legal/${kind}`).expect(200);
        expect(res.body.markdown.length).toBeGreaterThan(200);
        expect(res.body.version).toBeTruthy();
      }
      const consent = await http.get('/api/v1/legal/consent').expect(200);
      expect(consent.body.markdown).toContain('Отзыв согласия');
      const page = await http.get('/api/v1/legal/privacy/page').expect(200);
      expect(page.headers['content-type']).toContain('text/html');
      expect(page.text).toContain('152-ФЗ');
      await http.get('/api/v1/legal/unknown').expect(404);
    });

    it('Instagram и мессенджеры не отдаём, даже если остались в старых настройках', async () => {
      await q(
        `insert into settings (key, value) values ('venue', '{"instagram":"old.account","whatsapp":"+79604316223","telegram":"hc","vk":"hc","phone":"+79604316223"}')
         on conflict (key) do update set value = excluded.value`,
      );
      const res = await http.get('/api/v1/venue').expect(200);
      for (const k of ['instagram', 'whatsapp', 'telegram', 'vk']) expect(res.body[k]).toBeUndefined();
      expect(res.body.phone).toBe('+79604316223');
      expect(res.body.legalAddress).toBe(res.body.address); // адрес продавца по умолчанию — адрес кофейни
      await http
        .put('/api/v1/admin/venue')
        .set('Authorization', `Bearer ${staffToken}`)
        .send({ whatsapp: '+79604316223' })
        .expect(400);
    });

    it('в документах — наименование и адрес оператора, без заглушек', async () => {
      const auth = { Authorization: `Bearer ${staffToken}` };
      await http.put('/api/v1/admin/venue').set(auth).send({ legalAddress: '', privacyEmail: '' }).expect(200);
      let res = await http.get('/api/v1/legal/consent').expect(200);
      expect(res.body.markdown).toContain('ИП Жабоева А. Т., адрес: г. Нальчик, ул. Толстого, 43');
      expect(res.body.markdown).not.toMatch(/\[[^\]]+\]/); // нет «[ИНН]» и подобных пустых мест
      expect(res.body.markdown).not.toContain('ИНН');

      await http
        .put('/api/v1/admin/venue')
        .set(auth)
        .send({ legalAddress: 'г. Нальчик, ул. Примерная, 1', privacyEmail: 'pd@historycoffee.ru' })
        .expect(200);
      res = await http.get('/api/v1/legal/privacy').expect(200);
      expect(res.body.markdown).toContain('г. Нальчик, ул. Примерная, 1');
      expect(res.body.markdown).toContain('pd@historycoffee.ru');
      // ИНН/ОГРН больше не принимаются
      await http.put('/api/v1/admin/venue').set(auth).send({ inn: '071234567890' }).expect(400);
    });

    it('удаление аккаунта убирает телефон из его обращений', async () => {
      const g = await loginGuest('9005550103', { acceptPersonalData: true });
      await http
        .post('/api/v1/feedback')
        .set('Authorization', `Bearer ${g.accessToken}`)
        .field('type', 'complaint')
        .field('message', 'Проверка удаления данных')
        .field('contactPhone', '+79005550103')
        .expect(201);
      await http.delete('/api/v1/me').set('Authorization', `Bearer ${g.accessToken}`).expect(204);
      const rows = await q('select contact_phone from feedback where guest_id = $1', [g.guest.id]);
      expect(rows.length).toBeGreaterThan(0);
      expect(rows.every((r: { contact_phone: string | null }) => r.contact_phone === null)).toBe(true);
      const consents = await q('select 1 from consents where guest_id = $1 and revoked_at is null', [g.guest.id]);
      expect(consents).toHaveLength(0);
    });

    it('пищевая ценность и аллергены позиции меню', async () => {
      const menu = await http.get('/api/v1/admin/menu').set('Authorization', `Bearer ${staffToken}`).expect(200);
      const categoryId = menu.body[0].categories[0].id as string;
      const item = await http
        .post('/api/v1/admin/menu/items')
        .set('Authorization', `Bearer ${staffToken}`)
        .send({
          categoryId,
          title: 'Сырники',
          portion: '220 г',
          prices: [{ label: '', amount: 390 }],
          nutrition: { kcal: 412, proteins: 18.5, fats: 16, carbs: 44 },
          allergens: 'молоко, яйца, глютен',
        })
        .expect(201);
      expect(item.body.nutrition).toEqual({ kcal: 412, proteins: 18.5, fats: 16, carbs: 44 });
      const pub = await http.get('/api/v1/menu').expect(200);
      const found = pub.body.sections
        .flatMap((s: { categories: { items: { id: string }[] }[] }) => s.categories.flatMap((c) => c.items))
        .find((i: { id: string }) => i.id === item.body.id);
      expect(found).toMatchObject({ allergens: 'молоко, яйца, глютен', nutrition: { kcal: 412 } });
    });

    it('сроки хранения: старые коды подтверждения удаляются', async () => {
      await q("insert into otp_codes (phone, code_hash, expires_at, created_at) values ('+79005550199', 'x', now(), now() - interval '2 days')");
      const res = await app.get(RetentionService).run();
      expect(res.otp).toBeGreaterThan(0);
      const left = await q("select 1 from otp_codes where phone = '+79005550199'");
      expect(left).toHaveLength(0);
    });
  });
});
