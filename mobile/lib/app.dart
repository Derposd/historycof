import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/auth/guest_profile.dart';
import 'core/push/push_service.dart';
import 'core/theme/theme.dart';
import 'features/chat/chat.dart';
import 'features/feedback/feedback.dart';
import 'features/news/news.dart';
import 'router.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class HistoryCoffeeApp extends ConsumerStatefulWidget {
  const HistoryCoffeeApp({super.key});

  @override
  ConsumerState<HistoryCoffeeApp> createState() => _HistoryCoffeeAppState();
}

class _HistoryCoffeeAppState extends ConsumerState<HistoryCoffeeApp> {
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushServiceProvider);
    _subs
      ..add(push.openedMessages.listen(_openFromPush))
      ..add(
        push.foregroundMessages.listen((m) {
          final title = m.notification?.title;
          if (title == null) return;
          if (m.data['type'] == 'news') ref.invalidate(newsFeedProvider);
          if (m.data['type'] == 'feedback') ref.invalidate(myFeedbackProvider);
          if (m.data['type'] == 'chat') {
            ref.invalidate(chatThreadProvider);
            ref.invalidate(chatUnreadProvider);
          }
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(title),
              action: SnackBarAction(label: 'Открыть', onPressed: () => _openFromPush(m.data)),
            ),
          );
        }),
      );
  }

  void _openFromPush(Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    switch (data['type']) {
      case 'news' when data['id'] is String:
        router.push('/news/${data['id']}');
      case 'feedback':
        router.push('/feedback/mine');
      case 'chat':
        router.push('/chat');
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Вход/выход — перепривязываем токен устройства к гостю; обновлённая
    // политика ПДн — просим согласие заново.
    ref.listen<AsyncValue<GuestProfile?>>(authControllerProvider, (prev, next) {
      final before = prev?.value?.id;
      final after = next.value?.id;
      if (before != after) unawaited(ref.read(pushServiceProvider).registerDevice());
      if (next.value?.consentRequired == true && prev?.value?.consentRequired != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _askConsentAgain());
      }
    });

    return MaterialApp.router(
      title: 'History Coffee',
      debugShowCheckedModeBanner: false,
      theme: buildHcTheme(),
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }

  /// Документы обновились — согласие на обработку ПДн нужно дать заново (оно даётся
  /// на конкретный текст). Без согласия пользоваться аккаунтом нельзя — предлагаем выйти.
  Future<void> _askConsentAgain() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final router = ref.read(routerProvider);
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Мы обновили документы'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Чтобы продолжить пользоваться аккаунтом, подтвердите согласие на обработку персональных данных.',
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => router.push('/legal/consent'),
              child: const Text('Согласие на обработку данных'),
            ),
            TextButton(onPressed: () => router.push('/legal/privacy'), child: const Text('Политика обработки данных')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Выйти из аккаунта')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Даю согласие')),
        ],
      ),
    );
    if (accepted == true) {
      await ref.read(authControllerProvider.notifier).acceptConsent();
    } else if (accepted == false) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}
