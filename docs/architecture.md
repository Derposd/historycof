# Архитектура

```
┌──────────────────┐      HTTPS / JSON       ┌─────────────────────────┐
│ Flutter-app      │ ──────────────────────▶ │ Backend (NestJS)        │──▶ PostgreSQL
│ Android + iOS    │ ◀── push (FCM) ───┐     │ /api/v1                 │──▶ S3 (картинки)
└──────────────────┘                   │     │                         │──▶ iikoCloud API (бонусы)
┌──────────────────┐                   │     │                         │──▶ SMS-шлюз (коды входа)
│ Веб-админка      │ ──────────────────┼───▶ │ /api/v1/admin/*         │──▶ Telegram / SMTP (обращения)
│ React            │                   └──── │                         │──▶ Firebase Cloud Messaging
└──────────────────┘                         └─────────────────────────┘
```

| Часть | Стек | Папка |
|---|---|---|
| Мобильное приложение | Flutter 3.47, Riverpod 3, go_router, Dio | `mobile/` |
| Backend | Node 22, NestJS 11, Drizzle ORM, PostgreSQL 16 | `backend/` |
| Админка | React 19, Vite, TanStack Query | `admin/` |

## Авторизация

- **Гости**: номер телефона → SMS-код (4 цифры, 5 минут, 5 попыток, повтор через 60 с,
  не больше 5 кодов в час на номер; коды хранятся как HMAC). При первой регистрации
  обязательно согласие на обработку ПДн: сохраняются версия политики и время согласия.
  Если политика обновилась (`PRIVACY_POLICY_VERSION`), приложение просит согласие заново.
- **Сотрудники**: email + пароль (bcrypt), роли `admin` / `editor`.
- Токены: JWT access на 15 минут и opaque refresh с ротацией (гость — 90 дней, сотрудник — 7).
  Refresh хранится в БД как HMAC; повторное использование и выход его отзывают.
- Для ревью в App Store / Google Play: `OTP_REVIEW_PHONE` + `OTP_REVIEW_CODE` — фиксированный код без SMS.

## API

Префикс `/api/v1`. Ошибки: `{ statusCode, error, message }`, где `error` — машиночитаемый
код (`consent_required`, `otp_invalid`, `otp_cooldown`, `loyalty_unavailable`…).

**Публичные**
| | |
|---|---|
| `GET /news?limit&before` | лента (закреплённые + курсорная пагинация) |
| `GET /news/:id` | новость |
| `GET /menu` | дерево меню (только видимое и доступное) + дисклеймер |
| `GET /venue` | контакты, часы, `openState` (по Москве) |
| `GET /legal/privacy` | политика ПДн (markdown + версия) |
| `POST /feedback` | обращение, multipart: `type`, `message`, `contactPhone?`, `photo?` (гость — опционально) |
| `POST /devices`, `DELETE /devices/:token` | FCM-токен устройства |

**Гость** (`Authorization: Bearer`)
| | |
|---|---|
| `POST /auth/otp/request`, `/auth/otp/verify`, `/auth/refresh`, `/auth/logout` | вход |
| `GET/PATCH/DELETE /me`, `POST /me/consent` | профиль, удаление аккаунта, повторное согласие |
| `GET /loyalty[?refresh=true]`, `/loyalty/card`, `/loyalty/transactions` | бонусы (iiko) |
| `GET /feedback/mine` | мои обращения со статусами и ответами |

**Админка** (`/admin/*`, токен сотрудника)
| | |
|---|---|
| `POST /admin/auth/login`, `/refresh`, `/logout` | вход сотрудника |
| `/admin/news` CRUD, `POST :id/publish {notify}`, `POST :id/unpublish` | новости. Push уходит один раз на пост |
| `/admin/menu` дерево; CRUD `sections`, `categories`, `items`; `PUT reorder/:kind` | меню |
| `GET /admin/feedback?status&type&page`, `GET :id` (→ «просмотрено»), `PATCH :id {reply,status}` | обращения, ответ гостю + push |
| `GET/PUT /admin/venue` (PUT — только admin) | контакты и часы |
| `/admin/staff` (admin), `GET /admin/staff/me` | сотрудники |
| `POST /admin/uploads?folder=news\|menu` | загрузка картинки |
| `GET /admin/analytics/summary` | цифры для дашборда |

## Данные

Схема: `backend/src/db/schema.ts`, миграции: `backend/drizzle/`. Основные таблицы:
`guests`, `otp_codes`, `refresh_tokens`, `device_tokens`, `staff_users`, `news_posts`,
`menu_sections` / `menu_categories` / `menu_items` (цены в `jsonb`: `[{label, amount}]`,
бейджи — массив), `feedback`, `settings` (контакты и часы).

Баланс и операции по бонусам **не копируются** в нашу БД: источник правды — iiko.

## Картинки

Загрузка идёт только через backend. Каждое фото перекодируется в JPEG, ужимается до 1600 px
по длинной стороне, EXIF удаляется (в том числе геометки с телефона). Хранилище —
S3-совместимое (`STORAGE_DRIVER=s3`) или локальная папка в разработке.

## Push-уведомления

- Новости: FCM-топик `news`. Приложение подписывается само; в профиле подписку можно выключить.
- Ответ на обращение: персонально, по токенам устройств гостя.
- Без `FIREBASE_SERVICE_ACCOUNT_JSON` на backend и без `--dart-define` в приложении
  пуши отключены, всё остальное работает.

## Персональные данные (152-ФЗ)

- Согласие при регистрации с фиксацией версии и времени; повторное согласие при смене политики.
- Политика доступна в приложении до входа и после (`GET /legal/privacy`).
- Удаление аккаунта в профиле (требование App Store / Google Play) обезличивает гостя,
  отзывает сессии и удаляет токены устройств.
- **Локализация**: БД и хранилище картинок должны быть в РФ (Yandex Cloud / Selectel).
- **Трансграничная передача**: в FCM уходит только токен устройства, без телефона и имени.
  Порядок уведомления Роскомнадзора нужно уточнить у юриста.
- В логах телефоны маскируются.

## Развёртывание (рекомендация)

- Backend — Docker-образ (`backend/Dockerfile`), миграции применяются при старте.
- Админка — статика за nginx (`admin/Dockerfile`), `/api` проксируется на backend,
  чтобы обойтись без CORS.
- Managed PostgreSQL с ежедневными бэкапами, Object Storage с публичным чтением
  бакета картинок.
- Секреты — через переменные окружения (`backend/.env.example`).
