/// Конфигурация сборки через --dart-define (см. mobile/README.md).
abstract final class AppConfig {
  /// Базовый URL API. По умолчанию — backend на хост-машине из Android-эмулятора.
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');

  /// Firebase (push). Если не заданы — push-уведомления отключены, приложение работает без них.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosBundleId = String.fromEnvironment('IOS_BUNDLE_ID', defaultValue: 'ru.historycoffee.historyCoffee');

  static bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty && firebaseSenderId.isNotEmpty;

  /// Топик FCM для новостей — совпадает с FCM_NEWS_TOPIC на backend.
  static const newsTopic = 'news';
}
