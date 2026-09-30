// Раскадровка анимаций для просмотра «вживую» (не входит в обычный прогон тестов).
// Запуск: flutter test tool/motion_test.dart --dart-define=DEMO=true --update-goldens
// Кадры появятся в tool/screens/motion/, склейка в GIF — tool/make_gifs.py.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:history_coffee/app.dart';
import 'package:history_coffee/core/auth/auth_controller.dart';
import 'package:history_coffee/core/auth/token_store.dart';
import 'package:history_coffee/core/providers.dart';
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

  Future<(ProviderContainer, GoRouter)> start(WidgetTester tester, {bool signedIn = false}) async {
    tester.view.physicalSize = const Size(780, 1688); // 390×844 @2x
    tester.view.devicePixelRatio = 2;
    final container = ProviderContainer(overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const HistoryCoffeeApp()));
    if (signedIn) {
      // Вход по демо-коду, как это сделал бы гость
      final auth = container.read(authControllerProvider.notifier);
      await tester.runAsync(() async {
        await container.read(authControllerProvider.future);
        await auth.requestOtp('+79990000001');
        await auth.verifyOtp(phone: '+79990000001', code: '1234', acceptPrivacyPolicy: true);
      });
      await tester.pump();
    }
    return (container, container.read(routerProvider));
  }

  var frame = 0;
  Future<void> shot(String scene) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('screens/motion/$scene-${(frame++).toString().padLeft(3, '0')}.png'),
  );

  /// Снимает кадры каждые [step] мс в течение [ms].
  Future<void> film(WidgetTester tester, String scene, int ms, {int step = 50}) async {
    for (var t = 0; t <= ms; t += step) {
      await shot(scene);
      await tester.pump(Duration(milliseconds: step));
    }
  }

  testWidgets('логотип и лента', (tester) async {
    frame = 0;
    final (c, _) = await start(tester);
    await tester.pump();
    await film(tester, 'intro', 1800, step: 60);
    c.dispose();
  });

  testWidgets('нижнее меню и фон', (tester) async {
    frame = 0;
    final (c, router) = await start(tester);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot('tabs');
    for (final path in ['/menu', '/contacts', '/card', '/news']) {
      router.go(path);
      await film(tester, 'tabs', 900, step: 45);
    }
    c.dispose();
  });

  testWidgets('бонусная карта', (tester) async {
    frame = 0;
    final (c, router) = await start(tester, signedIn: true);
    await tester.pump(const Duration(seconds: 1));
    router.go('/card');
    await film(tester, 'card', 2600, step: 60);
    // Наклон за пальцем и возврат
    final card = find.text('Баланс');
    final g = await tester.startGesture(tester.getCenter(card) + const Offset(120, -20));
    await film(tester, 'card', 200, step: 50);
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(-22, 3));
      await tester.pump(const Duration(milliseconds: 40));
      await shot('card');
    }
    await g.up();
    await film(tester, 'card', 800, step: 50);
    c.dispose();
  });

  testWidgets('новость: параллакс фото', (tester) async {
    frame = 0;
    final (c, router) = await start(tester);
    await tester.pump(const Duration(seconds: 1));
    unawaited(router.push('/news/demo-welcome'));
    await film(tester, 'news', 900, step: 60);
    // Прокрутка вверх: фото уходит медленнее текста
    final g = await tester.startGesture(const Offset(200, 700));
    for (var i = 0; i < 14; i++) {
      await g.moveBy(const Offset(0, -16));
      await tester.pump(const Duration(milliseconds: 40));
      await shot('news');
    }
    await g.up();
    await film(tester, 'news', 700, step: 60);
    c.dispose();
  });

  testWidgets('обращение отправлено', (tester) async {
    frame = 0;
    final (c, router) = await start(tester);
    await tester.pump(const Duration(seconds: 1));
    unawaited(router.push('/feedback/new?type=thanks'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.enterText(find.byType(TextFormField).first, 'Спасибо за тыквенный латте!');
    await tester.tap(find.text('Отправить'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await film(tester, 'sent', 1700, step: 50);
    c.dispose();
  });
}
