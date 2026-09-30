# History Coffee — мобильное приложение кофейни-бутика

«Место для ваших историй» · Нальчик, ул. Толстого, 43

Мобильное приложение (Android + iOS), backend и веб-админка для кофейни History Coffee.

| Раздел приложения | Что умеет |
|---|---|
| **Новости** | лента постов с фото, закрепление, уведомления о новостях (только гостям, давшим согласие на рекламу) |
| **Меню** | Кухня / Бар, категории, несколько цен (S/L), бейджи «Выбор команды», «Хит продаж», «Новинка», «Блюдо с историей»; наполняется из админки |
| **Бонусы** | вход по телефону + SMS, карта с QR для кассы iiko, баланс и история операций |
| **Контакты** | адрес и маршрут (Яндекс / 2ГИС / Google / Apple), часы и индикатор «открыто сейчас», звонок, чат с кофейней (сообщения приходят в админку), WhatsApp — если указан в админке (соцсетей нет — см. docs/compliance-rf.md) |
| **Обратная связь** | жалоба / предложение / благодарность, фото, телефон; статус и ответ кофейни в приложении |
| **Профиль** | имя, согласие на новости и акции, документы (политика, согласия, правила бонусов), реквизиты продавца, выход, удаление аккаунта |

Требования законов РФ (152-ФЗ, 38-ФЗ, 149-ФЗ, 168-ФЗ и др.) и что должна сделать кофейня — `docs/compliance-rf.md`.

## Структура

```
backend/   API (NestJS + PostgreSQL): авторизация, новости, меню, iiko, обращения, push
admin/     веб-админка (React) для владельца и сотрудников
mobile/    приложение (Flutter)
docs/      архитектура, интеграция с iiko, дизайн-система, вопросы заказчику
```

## Быстрый старт (локально)

Нужны Node 22, PostgreSQL 16, Flutter 3.47.

В контейнере Claude Code / на Linux всё поднимается одной командой: `tools/dev-up.sh`
(API на :3000, админка на :5173; с `--flutter` — ещё и Flutter SDK).
Контекст проекта для продолжения работы с Claude — в [CLAUDE.md](CLAUDE.md).

```bash
# 1. Backend
cd backend
cp .env.example .env            # заполнить ADMIN_BOOTSTRAP_EMAIL/PASSWORD
npm ci && npm run build
npm run db:migrate && npm run db:seed
npm run start:dev               # http://localhost:3000/api/v1

# 2. Админка
cd ../admin && npm ci && npm run dev    # http://localhost:5173

# 3. Приложение
cd ../mobile && flutter pub get && flutter run
```

Или всё сразу в Docker (PostgreSQL + MinIO + API + админка):

```bash
docker compose up --build
docker compose exec backend node dist/db/seed.js   # стартовая структура меню
# админка: http://localhost:8080  (admin@historycoffee.ru / change-me-please)
```

В режиме разработки внешние сервисы не нужны: SMS-коды пишутся в лог backend,
бонусы работают на mock-клиенте iiko, пуши логируются.

## Тесты

```bash
cd backend && npm test && npm run test:e2e   # e2e — на реальной PostgreSQL (DATABASE_URL_TEST)
cd admin && npm run lint && npm run build
cd mobile && flutter analyze && flutter test
```

## Документация

- [Архитектура, API, 152-ФЗ, развёртывание](docs/architecture.md)
- [Интеграция с iiko и чек-лист проверки](docs/iiko-integration.md)
- [Дизайн-система](docs/design-system.md)
- [**Что уточнить у заказчика**](docs/client-questions.md) — iiko, правила бонусов, канал для жалоб, логотип, сторы, реквизиты
- [Приложение](mobile/README.md) · [Админка](admin/README.md)

## Статус

MVP готов к наполнению и интеграционной проверке. До запуска нужно:
доступ к iiko API, SMS-шлюз, Firebase-проект, хостинг в РФ, реквизиты для политики ПДн,
векторный логотип и иконка, аккаунты в сторах. Подробно: [client-questions.md](docs/client-questions.md).
