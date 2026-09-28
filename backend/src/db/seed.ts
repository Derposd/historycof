import { count } from 'drizzle-orm';
import { loadConfig, loadDotEnv } from '../config/configuration';
import { createDb, Db } from './database.module';
import { menuCategories, menuItems, menuSections, newsPosts } from './schema';

/**
 * Стартовая структура меню как на historycoffee.ru: Кухня / Бар, в Кухне —
 * Завтраки, Салаты, Боулы, Основное, Тосты·Сэндвичи.
 *
 * Позиции НЕ выдумываются: единственная, подтверждённая брифом, — капучино 270/290 ₽.
 * Остальное меню вносится через админку (или импортом из iiko — см. docs/client-questions.md).
 * Категории бара — рабочие заготовки, их состав сверить с заказчиком.
 */
/**
 * demoImagesBaseUrl — для тестового стенда: к капучино и примеру блюда подставляются
 * демо-иллюстрации (лежат в uploads/demo, нарисованы для проекта), добавляется «Пример блюда».
 */
export async function seed(db: Db, demoImagesBaseUrl?: string): Promise<void> {
  const [{ n }] = await db.select({ n: count() }).from(menuSections);
  if (n > 0) {
    console.log('Меню уже заполнено — сид пропущен');
    return;
  }

  const [kitchen, bar] = await db
    .insert(menuSections)
    .values([
      { slug: 'kitchen', title: 'Кухня', sort: 0 },
      { slug: 'bar', title: 'Бар', sort: 1 },
    ])
    .returning();

  const kitchenCategories = await db
    .insert(menuCategories)
    .values(
      ['Завтраки', 'Салаты', 'Боулы', 'Основное', 'Тосты · Сэндвичи'].map((title, sort) => ({
        sectionId: kitchen.id,
        title,
        sort,
      })),
    )
    .returning();
  const img = (name: string) => (demoImagesBaseUrl ? `${demoImagesBaseUrl.replace(/\/$/, '')}/${name}` : null);

  if (demoImagesBaseUrl) {
    await db.insert(menuItems).values({
      categoryId: kitchenCategories[0].id,
      title: 'Пример блюда',
      description: 'Тестовая позиция: фото, состав, цены и бейджи каждого блюда задаются в админке.',
      imageUrl: img('dish.jpg'),
      prices: [{ label: '', amount: 390 }],
      badges: ['team_choice', 'story'],
      story: 'Здесь будет короткая легенда блюда — для позиций с пометкой «Блюдо с историей».',
      sort: 0,
    });
  }

  const [coffee] = await db
    .insert(menuCategories)
    .values({ sectionId: bar.id, title: 'Кофе', sort: 0 })
    .returning();

  await db.insert(menuItems).values({
    categoryId: coffee.id,
    title: 'Капучино',
    description: null, // состав уточнить у заказчика
    imageUrl: img('cappuccino.jpg'),
    prices: [
      { label: 'S', amount: 270 },
      { label: 'L', amount: 290 },
    ],
    badges: [],
    sort: 0,
  });

  const [{ posts }] = await db.select({ posts: count() }).from(newsPosts);
  if (posts === 0) {
    await db.insert(newsPosts).values({
      title: 'Добро пожаловать в приложение History Coffee',
      body:
        'Теперь меню, бонусы и новости кофейни — всегда под рукой. ' +
        'Покажите QR-код бариста, чтобы копить и тратить бонусы. ' +
        'Место для ваших историй — Нальчик, ул. Толстого, 43.',
      imageUrl: img('cappuccino.jpg'),
      status: 'published',
      pinned: true,
      publishedAt: new Date(),
    });
  }

  console.log('Сид выполнен');
}

if (require.main === module) {
  loadDotEnv();
  const config = loadConfig();
  const { pool, db } = createDb(config.databaseUrl);
  seed(db, process.env.SEED_DEMO === 'true' ? `${config.publicUrl}/uploads/demo` : undefined)
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => pool.end());
}
