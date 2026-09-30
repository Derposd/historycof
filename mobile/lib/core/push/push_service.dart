import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../config.dart';
import '../providers.dart';

/// Push-уведомления через Firebase Cloud Messaging.
///
/// Все уведомления адресные: токен устройства регистрируется на сервере только
/// после входа. Служебные (ответ на обращение) приходят владельцу аккаунта,
/// новости и акции — только гостям с отдельным согласием на рекламу
/// (38-ФЗ, ст. 18): кому отправлять, решает сервер по журналу согласий.
/// Общих подписок («топиков») нет. Если Firebase не сконфигурирован через
/// --dart-define, сервис тихо отключается.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _enabled = false;
  String? _token;
  final _opened = StreamController<Map<String, dynamic>>.broadcast();
  final _foreground = StreamController<RemoteMessage>.broadcast();

  bool get enabled => _enabled;

  /// Пользователь открыл уведомление — data: { type: 'news'|'feedback', id }.
  Stream<Map<String, dynamic>> get openedMessages => _opened.stream;

  /// Уведомление пришло, пока приложение открыто.
  Stream<RemoteMessage> get foregroundMessages => _foreground.stream;

  static FirebaseOptions? _options() {
    if (!AppConfig.firebaseConfigured) return null;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final appId = ios ? AppConfig.firebaseIosAppId : AppConfig.firebaseAndroidAppId;
    if (appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: AppConfig.firebaseApiKey,
      appId: appId,
      messagingSenderId: AppConfig.firebaseSenderId,
      projectId: AppConfig.firebaseProjectId,
      iosBundleId: ios ? AppConfig.iosBundleId : null,
    );
  }

  Future<void> init() async {
    final options = _options();
    if (options == null || kIsWeb) {
      debugPrint('Push: Firebase не настроен — уведомления отключены');
      return;
    }
    try {
      await Firebase.initializeApp(options: options);
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      _enabled = true;

      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      // Прежние версии подписывали на общий топик новостей без согласия — снимаем эту подписку
      unawaited(messaging.unsubscribeFromTopic('news').catchError((_) {}));

      _token = await messaging.getToken();
      messaging.onTokenRefresh.listen((t) {
        _token = t;
        unawaited(registerDevice());
      });
      await registerDevice();

      FirebaseMessaging.onMessage.listen(_foreground.add);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _opened.add(m.data));
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        // Даём роутеру построиться, прежде чем переходить по deeplink.
        Future<void>.delayed(const Duration(milliseconds: 400), () => _opened.add(initial.data));
      }
    } catch (e) {
      debugPrint('Push: ошибка инициализации: $e');
      _enabled = false;
    }
  }

  /// Привязывает токен устройства к вошедшему гостю. Без входа токен не отправляется.
  Future<void> registerDevice() async {
    final token = _token;
    if (!_enabled || token == null || !_ref.read(isSignedInProvider)) return;
    try {
      await _ref
          .read(apiClientProvider)
          .post<void>(
            '/devices',
            data: {'token': token, 'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'},
          );
    } catch (e) {
      debugPrint('Push: не удалось зарегистрировать устройство: $e');
    }
  }

  /// При выходе отвязываем устройство от гостя.
  Future<void> unregisterDevice() async {
    final token = _token;
    if (!_enabled || token == null) return;
    try {
      await _ref.read(apiClientProvider).delete<void>('/devices/${Uri.encodeComponent(token)}');
    } catch (_) {}
  }
}

final pushServiceProvider = Provider<PushService>(PushService.new);
