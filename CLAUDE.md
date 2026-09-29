# History Coffee — память проекта для Claude

Этот файл Claude Code читает в начале каждой сессии. Здесь всё, что нужно, чтобы продолжить
работу в новом чате без пересказа истории. **Обновляй раздел «Состояние и что дальше»
в конце каждой заметной задачи** — это журнал для следующей сессии.

## Кто заказчик и как общаться

- Проект: приложение для **кофейни-бутика History Coffee**, Нальчик, ул. Толстого, 43
  («Место для ваших историй»). Пользователь (владелец репозитория) делает его на продажу кофейне.
- Пишем пользователю **по-русски, просто, без жаргона**, коротко. Пользователь не разработчик.
- У пользователя **Windows / PowerShell**: команды для него — без `&&`, `grep`, `\$()`;
  лучше вообще обходиться без его ручных команд, делать всё самим через GitHub Actions.
- Результаты показываем **скриншотами** (Playwright, см. «Проверка интерфейса») и ссылками.
- Пользователь любит: плавные анимации, аккуратную сетку, «дорогой» спокойный дизайн,
  не копию сайта кофейни (сайт делал дизайнер — свой стиль, но в духе бренда).
- В названии: **«coffee boutique»** (не «coffee house»), в логотипе админки без слова «админка».

## Что есть в репозитории

```
backend/  NestJS 11 + Drizzle + PostgreSQL 16 — API /api/v1
admin/    React 19 + Vite 8 + TanStack Query — веб-админка (nginx проксирует /api на backend)
mobile/   Flutter 3.47.5 (Dart 3.13), Riverpod 3, go_router 18, Dio — приложение (Android; iOS позже)
deploy/   тестовый стенд на VPS: compose, скрипты, зашифрованные секреты
docs/     architecture.md, iiko-integration.md, design-system.md, client-questions.md
tools/dev-up.sh  поднять всё локально одной командой
.github/workflows/  ci.yml (тесты), android.yml (APK/AAB + релизы), vps.yml (стенд)
```

Функции: новости с push; меню Кухня/Бар (категории, несколько цен S/L, бейджи, фото блюд,
загрузка фото из админки); бонусы iiko (вход по телефону+SMS, QR-карта, баланс — только чтение);
контакты с индикатором «открыто/закрыто»; жалобы/предложения/благодарности с фото и ответом
из админки; профиль, удаление аккаунта, 152-ФЗ (согласие, политика).

Ветка: единственная и она же ветка по умолчанию — `claude/history-coffee-app-5x2xli`.

## Команды

```bash
tools/dev-up.sh              # Postgres + npm ci + API :3000 (миграции, сид) + админка :5173
tools/dev-up.sh --flutter    # плюс Flutter в /opt/sdk/flutter; затем export PATH=/opt/sdk/flutter/bin:$PATH

cd backend && npm run typecheck && npm test && npm run test:e2e   # e2e на history_test
cd admin && npm run lint && npm run build                          # oxlint + tsc + vite
cd mobile && flutter analyze && flutter test                       # 35 тестов
cd mobile && flutter test tool/screenshots_test.dart --dart-define=DEMO=true --update-goldens  # PNG в tool/screens
```

Локальная админка: `admin@historycoffee.ru / change-me-please` (только локально).
Контейнер эфемерный: Flutter, Postgres-данные, node_modules после перезапуска пропадают —
просто снова запусти `tools/dev-up.sh`. Из песочницы закрыты SSH (порт 22) и dl.google.com
(Android SDK) — поэтому APK и деплой делаются в GitHub Actions.

## Тестовый стенд (VPS пользователя)

- Адрес: **http://168.113.210.120:8090** — админка; API: `/api/v1`. Без домена и HTTPS.
- Тестовые клиенты приложения (фиксированные коды, SMS не отправляются):
  `+7 999 000-00-01` код `2580`, `+7 999 000-00-02` код `1470`.
- Логин/пароль администратора стенда **есть у пользователя**; в репозитории — только
  в зашифрованном `deploy/secrets.env.enc`. Жалобы пока приходят только в админку.
- Тестовый APK (ходит на стенд): релиз `android-test` —
  https://github.com/Derposd/historycof/releases/download/android-test/history-coffee-arm64.apk
  Демо без сервера: релиз `android-demo`.

**Как выкладывать** — только через workflow `VPS` (`.github/workflows/vps.yml`, workflow_dispatch),
запуск через GitHub MCP `actions_run_trigger`:
`inputs: {action: deploy|check|inspect, host: 168.113.210.120, user: root, port: "22"}`, ref — ветка выше.
- `deploy` собирает образы на раннере, копирует на сервер, `deploy/server-deploy.sh` поднимает
  compose-проект `historycoffee`, затем `deploy/smoke.sh` проверяет стенд снаружи
  (админ, оба клиента, обращение видно в админке) и печатает статусы соседних контейнеров.
- Статус смотреть через `actions_list`/`actions_get` (или `curl api.github.com/.../runs/<id>`).
- Отчёт `inspect` и секреты зашифрованы ключом, производным от секрета `VPS_SSH_KEY`
  (sha256 приватного ключа без пробелов). Сам приватный ключ есть только в секретах GitHub —
  в новой сессии расшифровать отчёт/секреты нельзя, и это нормально: deploy и check работают
  без этого. Если нужно поменять секреты стенда — спроси пользователя, как поступить.

**Ни в коем случае не сломать соседнее приложение на VPS** (lms-prod: caddy на 80/443,
backend 127.0.0.1:8080, Postgres 17, каталог /opt/lms). Наш стенд: /opt/history-coffee,
отдельный compose-проект/сеть/тома, порт из диапазона 8090–8099 (сохранён в /opt/history-coffee/port),
лимиты памяти/CPU, правило ufw с комментарием `history-coffee`, чистим только образы с меткой
`com.historycoffee=1`. Сервер: Ubuntu 24.04, 1 CPU, 2 ГБ — ничего не собирать на нём.

## Безопасность

- Репозиторий **публичный**: никаких паролей, токенов, ключей в коде, логах, коммитах и входных
  параметрах workflow. `apk-share/` (ключи, пароли, APK) в .gitignore — не коммитить.
- Root-пароль VPS однажды был прислан в чат — не использовать; вход только по ключу из секрета.
- Не выводить секреты из CI ни в каком виде (даже зашифрованными под новый ключ).

## Дизайн и код — договорённости

- Палитра: светлый тёплый фон `#FBF7EF`, текст `#362B22`, олива `#8A9770` / тёмная `#5F6E45`,
  золото `#E3C57F`, терракота `#C97B5D`; glassmorphism. На графиках олива насыщеннее: `#6a8540`.
- Шрифты только свободные (SIL OFL): Cormorant Garamond (заголовки) + Golos Text (текст),
  вшиты в приложение и админку. Цифры в Cormorant — `lining-nums tabular-nums` (иначе «1» как «I»).
- Приложение: сетка `HcSpace` (поля 20), анимации через `Motion`/`Pressable`/`FadeSlideIn`
  (`lib/core/widgets/motion.dart`), переключатель Кухня/Бар — один скользящий «ползунок».
  Вкладки нижнего меню — `_FadeBranches` в `app_shell.dart` (Set уходящих вкладок + Offstage,
  чтобы при быстром переключении не просвечивала прошлая страница; есть тест).
- Админка: адаптивная — на телефоне (≤860px) бургер и выезжающее меню, таблицы → карточки
  (`.rows-table`), позиции меню — `.item`-сетка. Проверять на 390 и 320 px.
- Backend: NestJS **11** (12 — только ESM), TypeScript **~5.9** (7 ломает ts-jest),
  `useDefineForClassFields: false` (иначе DTO затирают поля), глобальный ValidationPipe с
  `forbidNonWhitelisted` — **каждый query-параметр должен быть в DTO** (так падал список обращений).
- iiko: пока `IIKO_MODE=mock`; настоящая интеграция — позже (docs/iiko-integration.md).
- Демо-режим приложения: `--dart-define=DEMO=true` (DemoInterceptor, данные и фото из assets).

## Проверка интерфейса

Chromium предустановлен (`/opt/pw-browsers/chromium`). Playwright ставить в scratchpad
(`npm i playwright`), запускать с `executablePath: '/opt/pw-browsers/chromium'`,
для телефона — `viewport 390×844, isMobile, deviceScaleFactor 2`. Проверять
`document.documentElement.scrollWidth` (не шире экрана) и отправлять скриншоты пользователю.

## Состояние и что дальше

Сделано (сентябрь 2026): backend, админка (в т.ч. мобильная вёрстка), приложение Android,
анимации, фото блюд, график регистраций, стенд на VPS с тестовыми аккаунтами, CI.

До продажи/запуска (см. docs/client-questions.md):
- настоящий iiko (доступ к API от интегратора кофейни), SMS-провайдер, Firebase (push);
- домен + HTTPS, хостинг в РФ; ключ подписи Android (`ANDROID_KEYSTORE_*` в секретах) и Google Play;
- iOS — возможно позже; реквизиты для политики ПДн, логотип в векторе.

Обсуждали цену: пользователь думал о ~50 тыс. ₽; совет — 80–100 тыс. за запуск +
ежемесячная поддержка 5–10 тыс., код остаётся у разработчика, всё фиксировать письменно.
