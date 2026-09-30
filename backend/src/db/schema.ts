import { sql } from 'drizzle-orm';
import {
  boolean,
  index,
  integer,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

const createdAt = () => timestamp('created_at', { withTimezone: true }).notNull().defaultNow();
const updatedAt = () =>
  timestamp('updated_at', { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date());

// ─── Гости (пользователи мобильного приложения) ────────────────────────────────

export const guests = pgTable('guests', {
  id: uuid('id').primaryKey().defaultRandom(),
  /** E.164, например +79604316223. null после удаления аккаунта (анонимизация). */
  phone: text('phone').unique(),
  name: text('name'),
  birthday: text('birthday'), // YYYY-MM-DD
  iikoCustomerId: text('iiko_customer_id'),
  /** Трек виртуальной карты, выпущенной приложением в iikoCard (кодируется в QR). */
  iikoCardTrack: text('iiko_card_track').unique(),
  consentVersion: text('consent_version'),
  consentAt: timestamp('consent_at', { withTimezone: true }),
  /** Новости и акции push-уведомлениями — только с отдельного согласия на рекламу (38-ФЗ, ст. 18). */
  pushNewsEnabled: boolean('push_news_enabled').notNull().default(false),
  lastSeenAt: timestamp('last_seen_at', { withTimezone: true }),
  deletedAt: timestamp('deleted_at', { withTimezone: true }),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

export const otpCodes = pgTable(
  'otp_codes',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    phone: text('phone').notNull(),
    codeHash: text('code_hash').notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    attempts: integer('attempts').notNull().default(0),
    consumedAt: timestamp('consumed_at', { withTimezone: true }),
    createdAt: createdAt(),
  },
  (t) => [index('otp_codes_phone_created_idx').on(t.phone, t.createdAt)],
);

export const subjectType = pgEnum('subject_type', ['guest', 'staff']);

export const refreshTokens = pgTable(
  'refresh_tokens',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    subjectType: subjectType('subject_type').notNull(),
    subjectId: uuid('subject_id').notNull(),
    tokenHash: text('token_hash').notNull().unique(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    revokedAt: timestamp('revoked_at', { withTimezone: true }),
    createdAt: createdAt(),
  },
  (t) => [index('refresh_tokens_subject_idx').on(t.subjectType, t.subjectId)],
);

export const devicePlatform = pgEnum('device_platform', ['android', 'ios', 'web']);

export const deviceTokens = pgTable('device_tokens', {
  id: uuid('id').primaryKey().defaultRandom(),
  guestId: uuid('guest_id').references(() => guests.id, { onDelete: 'cascade' }),
  token: text('token').notNull().unique(),
  platform: devicePlatform('platform').notNull(),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

// ─── Сотрудники (веб-админка) ─────────────────────────────────────────────────

export const staffRole = pgEnum('staff_role', ['admin', 'editor']);

export const staffUsers = pgTable('staff_users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').notNull().unique(),
  passwordHash: text('password_hash').notNull(),
  name: text('name').notNull(),
  role: staffRole('role').notNull().default('editor'),
  active: boolean('active').notNull().default(true),
  lastLoginAt: timestamp('last_login_at', { withTimezone: true }),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

// ─── Новости ──────────────────────────────────────────────────────────────────

export const newsStatus = pgEnum('news_status', ['draft', 'published']);

export const newsPosts = pgTable(
  'news_posts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    title: text('title').notNull(),
    body: text('body').notNull(),
    imageUrl: text('image_url'),
    status: newsStatus('status').notNull().default('draft'),
    pinned: boolean('pinned').notNull().default(false),
    publishedAt: timestamp('published_at', { withTimezone: true }),
    pushedAt: timestamp('pushed_at', { withTimezone: true }),
    authorId: uuid('author_id').references(() => staffUsers.id, { onDelete: 'set null' }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [index('news_posts_status_published_idx').on(t.status, t.publishedAt)],
);

// ─── Меню ─────────────────────────────────────────────────────────────────────

export const menuSections = pgTable('menu_sections', {
  id: uuid('id').primaryKey().defaultRandom(),
  /** kitchen | bar — стабильный идентификатор для приложения. */
  slug: text('slug').notNull().unique(),
  title: text('title').notNull(),
  sort: integer('sort').notNull().default(0),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

export const menuCategories = pgTable('menu_categories', {
  id: uuid('id').primaryKey().defaultRandom(),
  sectionId: uuid('section_id')
    .notNull()
    .references(() => menuSections.id, { onDelete: 'cascade' }),
  title: text('title').notNull(),
  sort: integer('sort').notNull().default(0),
  visible: boolean('visible').notNull().default(true),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

export const MENU_BADGES = ['team_choice', 'bestseller', 'new', 'story'] as const;
export type MenuBadge = (typeof MENU_BADGES)[number];

export interface MenuPrice {
  /** Подпись варианта: «S», «L», «250 мл». Пустая строка — если вариант один. */
  label: string;
  /** Цена в рублях (целое). */
  amount: number;
}

export interface MenuNutrition {
  /** ккал на порцию */
  kcal?: number | null;
  /** белки, жиры, углеводы, г */
  proteins?: number | null;
  fats?: number | null;
  carbs?: number | null;
}

export const menuItems = pgTable(
  'menu_items',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    categoryId: uuid('category_id')
      .notNull()
      .references(() => menuCategories.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    /** Состав / описание. */
    description: text('description'),
    /** Выход: «250 г», «300 мл». */
    portion: text('portion'),
    imageUrl: text('image_url'),
    prices: jsonb('prices').$type<MenuPrice[]>().notNull().default(sql`'[]'::jsonb`),
    badges: text('badges').array().$type<MenuBadge[]>().notNull().default(sql`'{}'::text[]`),
    /** Легенда для бейджа «Блюдо с историей». */
    story: text('story'),
    /** Пищевая ценность на порцию (ПП РФ № 1515 — информация о продукции общепита). */
    nutrition: jsonb('nutrition').$type<MenuNutrition | null>(),
    /** Аллергены: «молоко, орехи». */
    allergens: text('allergens'),
    available: boolean('available').notNull().default(true),
    sort: integer('sort').notNull().default(0),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [index('menu_items_category_idx').on(t.categoryId, t.sort)],
);

// ─── Обратная связь ───────────────────────────────────────────────────────────

export const feedbackType = pgEnum('feedback_type', ['complaint', 'suggestion', 'thanks']);
export const feedbackStatus = pgEnum('feedback_status', ['sent', 'viewed', 'answered']);

export const feedback = pgTable(
  'feedback',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    guestId: uuid('guest_id').references(() => guests.id, { onDelete: 'set null' }),
    type: feedbackType('type').notNull(),
    message: text('message').notNull(),
    photoUrl: text('photo_url'),
    contactPhone: text('contact_phone'),
    status: feedbackStatus('status').notNull().default('sent'),
    reply: text('reply'),
    viewedAt: timestamp('viewed_at', { withTimezone: true }),
    answeredAt: timestamp('answered_at', { withTimezone: true }),
    answeredBy: uuid('answered_by').references(() => staffUsers.id, { onDelete: 'set null' }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [
    index('feedback_status_created_idx').on(t.status, t.createdAt),
    index('feedback_guest_idx').on(t.guestId),
  ],
);

// ─── Согласия гостей (152-ФЗ ст. 9, 38-ФЗ ст. 18) ─────────────────────────────

/**
 * Журнал согласий — доказательство их получения (обязанность оператора и рекламораспространителя).
 * pd — на обработку персональных данных, marketing — на получение рекламы (новости и акции).
 * Отзыв — revoked_at; строки не удаляются, пока жив аккаунт.
 */
export const consentKind = pgEnum('consent_kind', ['pd', 'marketing']);

export const consents = pgTable(
  'consents',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    guestId: uuid('guest_id')
      .notNull()
      .references(() => guests.id, { onDelete: 'cascade' }),
    kind: consentKind('kind').notNull(),
    /** Версия текста документа, на который дано согласие. */
    version: text('version').notNull(),
    grantedAt: timestamp('granted_at', { withTimezone: true }).notNull().defaultNow(),
    revokedAt: timestamp('revoked_at', { withTimezone: true }),
    ip: text('ip'),
    userAgent: text('user_agent'),
  },
  (t) => [index('consents_guest_kind_idx').on(t.guestId, t.kind)],
);

// ─── Настройки заведения (контакты, часы работы) ──────────────────────────────

export const settings = pgTable('settings', {
  key: text('key').primaryKey(),
  value: jsonb('value').notNull(),
  updatedAt: updatedAt(),
});

export type Guest = typeof guests.$inferSelect;
export type StaffUser = typeof staffUsers.$inferSelect;
export type NewsPost = typeof newsPosts.$inferSelect;
export type MenuSection = typeof menuSections.$inferSelect;
export type MenuCategory = typeof menuCategories.$inferSelect;
export type MenuItem = typeof menuItems.$inferSelect;
export type Feedback = typeof feedback.$inferSelect;

// ─── Чат гостя с кофейней ─────────────────────────────────────────────────────

/**
 * Переписка гостя с кофейней: у каждого гостя один диалог, отвечают сотрудники из админки.
 * Гости между собой не переписываются. read_at — когда сообщение прочитала другая сторона.
 */
export const chatSender = pgEnum('chat_sender', ['guest', 'staff']);

export const chatMessages = pgTable(
  'chat_messages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    guestId: uuid('guest_id')
      .notNull()
      .references(() => guests.id, { onDelete: 'cascade' }),
    sender: chatSender('sender').notNull(),
    staffId: uuid('staff_id').references(() => staffUsers.id, { onDelete: 'set null' }),
    text: text('text').notNull(),
    readAt: timestamp('read_at', { withTimezone: true }),
    createdAt: createdAt(),
  },
  (t) => [
    index('chat_messages_guest_created_idx').on(t.guestId, t.createdAt),
    index('chat_messages_unread_idx').on(t.sender, t.readAt),
  ],
);

export type ChatMessage = typeof chatMessages.$inferSelect;
