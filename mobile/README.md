# History Coffee — мобильное приложение (Flutter)

Сейчас в работе **Android**. Код общий с iOS: сборку под iPhone можно добавить
позже без переписывания (см. раздел «iOS» ниже). Экраны: новости, меню (Кухня / Бар),
бонусная карта с QR, контакты с индикатором «открыто сейчас», обратная связь,
профиль.

## Запуск

```bash
flutter pub get

# Android-эмулятор: backend на хост-машине доступен как 10.0.2.2
flutter run

# iOS-симулятор или реальное устройство — укажите адрес API явно
flutter run --dart-define=API_URL=http://localhost:3000/api/v1
```

Backend в dev-режиме пишет SMS-коды в лог (`SMS_PROVIDER=console`), бонусы
работают на mock-клиенте iiko (`IIKO_MODE=mock`) — приложение можно
прогнать целиком без внешних сервисов.

## Android: готовый APK

APK собирает GitHub Actions (`.github/workflows/android.yml`) при каждом изменении в `mobile/`:
вкладка **Actions** → «Android APK» → последний запуск → **Artifacts** → `history-coffee-android`.
Внутри лежат `.apk` для установки на телефон и `.aab` для Google Play.

- Пока backend не развёрнут, собирается **демо-версия** (`history-coffee-demo.apk`):
  встроенные примерные данные, вход по любому номеру с кодом **1234**.
- Когда появится сервер, задайте переменную репозитория `API_URL`
  (Settings → Secrets and variables → Actions → Variables) или укажите адрес при ручном
  запуске (Run workflow). Тогда соберётся рабочая версия `history-coffee.apk`.

Демо-APK также публикуется в пре-релиз с постоянной ссылкой (без входа в GitHub):
https://github.com/Derposd/historycof/releases/download/android-demo/history-coffee-demo.apk
(облегчённый, только arm64: `history-coffee-demo-arm64.apk` по той же ссылке)

Установка на телефон: скачать `.apk`, открыть, разрешить установку из этого источника.

Локально (нужен Android SDK):

```bash
flutter build apk --release --dart-define=DEMO=true                                  # демо
flutter build apk --release --dart-define=API_URL=https://api.historycoffee.ru/api/v1 # рабочая
```

### Ключ подписи для Google Play

Без ключа релиз подписывается debug-ключом: такой APK ставится на телефон, но в Google Play
его не загрузить. Для публикации:

1. Создать upload-ключ (**хранить надёжно, потеря = проблемы с обновлениями**):
   `keytool -genkey -v -keystore history-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Локально: скопировать `android/key.properties.example` в `android/key.properties` и заполнить.
3. В CI: добавить секреты репозитория `ANDROID_KEYSTORE_BASE64` (`base64 -w0 history-upload.jks`),
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
4. В Google Play Console включить Play App Signing и загрузить `.aab`.

Идентификатор приложения: `ru.historycoffee.app`. После первой публикации его менять нельзя.

Иконка и сплэш — временные (перо из логотипа на айвори), заменить после получения векторного логотипа.

## Параметры сборки (`--dart-define`)

| Переменная | Назначение |
|---|---|
| `DEMO` | `true` — демо-версия без сервера |
| `API_URL` | Базовый URL API, например `https://api.historycoffee.ru/api/v1` |
| `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID` | Общие параметры проекта Firebase |
| `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID` | App ID приложений в Firebase |
| `IOS_BUNDLE_ID` | Bundle ID iOS (по умолчанию `ru.historycoffee.historyCoffee`) |

Без параметров Firebase push-уведомления отключаются, остальное работает.
Firebase инициализируется из `FirebaseOptions`, поэтому `google-services.json`
и gradle-плагин не нужны.

Релизная сборка:

```bash
flutter build appbundle --release \
  --dart-define=API_URL=https://api.historycoffee.ru/api/v1 \
  --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_ANDROID_APP_ID=...
```

## iOS (позже): перед первой сборкой

1. В Xcode: Signing & Capabilities → добавить **Push Notifications** и
   **Background Modes → Remote notifications** (в `Info.plist` режим уже прописан).
2. Загрузить APNs Auth Key в консоль Firebase (Project Settings → Cloud Messaging).
3. В `ios/Podfile` поднять `platform :ios` до версии, которую требует текущий
   `firebase_messaging` (сейчас 15.0), затем выполнить `pod install`.

## Структура

```
lib/
  core/            тема, API-клиент, авторизация, push, общие виджеты
    theme/         палитра (colors.dart), шрифты, ThemeData
    widgets/       Glass (глассморфизм), фон, словесный знак HISTORY, общие элементы
  features/
    news/          лента и карточка новости
    menu/          меню, бейджи, карточка блюда
    loyalty/       бонусная карта и история операций
    contacts/      контакты, часы работы, маршрут
    feedback/      форма обращения и «Мои обращения»
    auth/          вход по SMS, согласие на обработку ПДн, политика
    profile/       профиль, уведомления, выход, удаление аккаунта
  router.dart      маршруты (go_router), нижняя навигация
```

## Дизайн

- Шрифты лежат в проекте (`assets/fonts`, лицензия OFL): **Cormorant Garamond** для
  заголовков и словесного знака, **Golos Text** для интерфейса. Кириллица в обоих
  проверена полностью, знак ₽ тоже есть. Шрифты не скачиваются с Google во время работы.
- Словесный знак HISTORY с пером в `core/widgets/wordmark.dart` восстановлен по
  скриншотам. Когда будет вектор от заказчика, его нужно заменить на оригинал.
- Глассморфизм применяется точечно: нижняя навигация, карточки новостей, карта
  лояльности, модальные окна.

## Тесты

```bash
flutter analyze
flutter test
```
