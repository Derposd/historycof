import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:history_coffee/app.dart';
import 'package:history_coffee/core/auth/token_store.dart';
import 'package:history_coffee/core/providers.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  testWidgets('быстрые переключения вкладок не оставляют предыдущую страницу видимой', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())],
        child: const HistoryCoffeeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    Offstage offstageOf(String text) => tester.widget<Offstage>(
      find.ancestor(of: find.text(text, skipOffstage: false).first, matching: find.byType(Offstage)).first,
    );

    // Главная → Меню → Бонусы → Контакты с интервалом короче анимации
    for (final tab in ['Меню', 'Бонусы', 'Контакты']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(const Duration(seconds: 1));

    expect(offstageOf('Новости и события кофейни').offstage, isTrue, reason: 'Главная должна быть скрыта');
    expect(offstageOf('Карта гостя в телефоне').offstage, isTrue, reason: 'Бонусы должны быть скрыты');
    expect(offstageOf('Часы работы').offstage, isFalse, reason: 'Контакты — текущая вкладка');
  });
}
