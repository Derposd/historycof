// Снимки экранов для визуальной проверки дизайна (не входит в обычный прогон тестов).
// Запуск: flutter test tool/screenshots_test.dart --dart-define=DEMO=true --update-goldens
// Картинки появятся в tool/screens/.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:history_coffee/app.dart';
import 'package:history_coffee/core/auth/token_store.dart';
import 'package:history_coffee/core/providers.dart';
import 'package:history_coffee/features/auth/phone_screen.dart';
import 'package:history_coffee/router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await _loadFont('Cormorant', ['assets/fonts/CormorantGaramond-Variable.ttf']);
    await _loadFont('Golos', ['assets/fonts/GolosText-Variable.ttf']);
    await _loadFont('MaterialIcons', [
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Future<void> Function(GoRouter r) go, {
    bool signedIn = false,
    Future<void> Function(WidgetTester t, GoRouter r)? then,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532); // iPhone-подобный 390×844 @3x
    tester.view.devicePixelRatio = 3;
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(
          MemoryTokenStore(signedIn ? const Tokens(access: 'demo', refresh: 'demo') : null),
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const HistoryCoffeeApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await go(container.read(routerProvider));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (then != null) {
      await then(tester, container.read(routerProvider));
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/$name.png'));
    container.dispose();
  }

  testWidgets('news', (t) => shoot(t, '1-news', (r) async => r.go('/news')));
  testWidgets('menu', (t) => shoot(t, '2-menu', (r) async => r.go('/menu')));
  testWidgets('card-guest', (t) => shoot(t, '3-card-guest', (r) async => r.go('/card')));
  testWidgets('contacts', (t) => shoot(t, '4-contacts', (r) async => r.go('/contacts')));
  testWidgets('profile', (t) => shoot(t, '5-profile', (r) async => r.go('/profile')));
  testWidgets(
    'login-code',
    (t) => shoot(
      t,
      '6-login-code',
      (r) async => r.go('/login/code', extra: const CodeScreenArgs(phone: '+79990000001', isNewUser: true)),
    ),
  );
  const codeArgs = CodeScreenArgs(phone: '+79990000001', isNewUser: true);
  Future<void> signIn(WidgetTester t, GoRouter r) async {
    unawaited(r.push('/login/code', extra: codeArgs));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.enterText(find.byType(TextField).first, '1234');
    await t.pump();
    await t.tap(find.byType(Checkbox).first);
    await t.pump();
    await t.tap(find.text('Войти'));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('profile-signed', (t) => shoot(t, '7-profile-signed', (r) async => r.go('/profile'), then: signIn));
  testWidgets(
    'profile-signed-bottom',
    (t) => shoot(
      t,
      '8-profile-bottom',
      (r) async => r.go('/profile'),
      then: (t, r) async {
        await signIn(t, r);
        for (var i = 0; i < 10; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await t.pump(const Duration(milliseconds: 100));
        }
        await t.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      },
    ),
  );
  testWidgets(
    'marketing-dialog',
    (t) => shoot(
      t,
      '11-marketing',
      (r) async => r.go('/profile'),
      then: (t, r) async {
        await signIn(t, r);
        for (var i = 0; i < 10; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await t.pump(const Duration(milliseconds: 100));
        }
        await t.tap(find.byType(Switch).first);
      },
    ),
  );
  testWidgets(
    'dish',
    (t) => shoot(
      t,
      '9-dish',
      (r) async => r.go('/menu'),
      then: (t, _) async {
        await t.tap(find.text('Пример блюда').first);
      },
    ),
  );
  testWidgets('consent-doc', (t) => shoot(t, '10-consent', (r) async => r.go('/legal/consent')));
  testWidgets(
    'chat',
    (t) => shoot(
      t,
      '12-chat',
      (r) async => r.go('/contacts'),
      then: (t, r) async {
        await signIn(t, r);
        unawaited(r.push('/chat'));
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        await t.enterText(find.byType(TextField).last, 'Здравствуйте! Можно забронировать столик на 19:00?');
        await t.pump();
        await t.tap(find.byTooltip('Отправить'));
      },
    ),
  );
}
