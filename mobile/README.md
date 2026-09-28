# History Coffee — мобильное приложение (Flutter)

Android и iOS из одной кодовой базы. Экраны: новости, меню (Кухня / Бар),
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

## Параметры сборки (`--dart-define`)

| Переменная | Назначение |
|---|---|
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

## iOS: перед первой сборкой

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
