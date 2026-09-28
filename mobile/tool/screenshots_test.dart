// Снимки экранов для визуальной проверки дизайна (не входит в обычный прогон тестов).
// Запуск: flutter test tool/screenshots_test.dart --dart-define=DEMO=true --update-goldens
// Картинки появятся в tool/screens/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:history_coffee/app.dart';
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

  Future<void> shoot(WidgetTester tester, String name, Future<void> Function(GoRouter r) go) async {
    tester.view.physicalSize = const Size(1170, 2532); // iPhone-подобный 390×844 @3x
    tester.view.devicePixelRatio = 3;
    final container = ProviderContainer(overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const HistoryCoffeeApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await go(container.read(routerProvider));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/$name.png'));
    container.dispose();
  }

  testWidgets('news', (t) => shoot(t, '1-news', (r) async => r.go('/news')));
  testWidgets('menu', (t) => shoot(t, '2-menu', (r) async => r.go('/menu')));
  testWidgets('card-guest', (t) => shoot(t, '3-card-guest', (r) async => r.go('/card')));
  testWidgets('contacts', (t) => shoot(t, '4-contacts', (r) async => r.go('/contacts')));
  testWidgets('profile', (t) => shoot(t, '5-profile', (r) async => r.go('/profile')));
}
