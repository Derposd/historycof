import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:history_coffee/core/auth/auth_controller.dart';
import 'package:history_coffee/core/auth/guest_profile.dart';
import 'package:history_coffee/core/theme/theme.dart';
import 'package:history_coffee/features/loyalty/loyalty.dart';
import 'package:history_coffee/features/loyalty/loyalty_screen.dart';
import 'package:history_coffee/features/menu/menu_models.dart';
import 'package:history_coffee/features/menu/menu_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

final _menu = MenuData.fromJson({
  'disclaimer': 'Цены и состав блюд носят информационный характер, актуальное меню — в кофейне',
  'sections': [
    {
      'id': 'k',
      'slug': 'kitchen',
      'title': 'Кухня',
      'categories': [
        {
          'id': 'c1',
          'title': 'Завтраки',
          'items': [
            {
              'id': 'i1',
              'title': 'Сырники',
              'description': 'Творог, сметана',
              'prices': [
                {'label': '', 'amount': 390},
              ],
              'badges': ['story', 'team_choice'],
              'story': 'Рецепт, который передаётся в семье',
            },
          ],
        },
      ],
    },
    {
      'id': 'b',
      'slug': 'bar',
      'title': 'Бар',
      'categories': [
        {
          'id': 'c2',
          'title': 'Кофе',
          'items': [
            {
              'id': 'i2',
              'title': 'Капучино',
              'prices': [
                {'label': 'S', 'amount': 270},
                {'label': 'L', 'amount': 290},
              ],
              'badges': ['bestseller'],
            },
          ],
        },
      ],
    },
  ],
});

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: buildHcTheme(),
    home: Scaffold(body: child),
  ),
);

class _SignedIn extends AuthController {
  @override
  Future<GuestProfile?> build() async => const GuestProfile(id: 'g1', phone: '+79604316223', name: 'Мадина');
}

class _SignedOut extends AuthController {
  @override
  Future<GuestProfile?> build() async => null;
}

class _FakeSummary extends LoyaltySummaryController {
  @override
  Future<LoyaltySummary?> build() async => const LoyaltySummary(
    card: LoyaltyCard(cardNumber: '7707 1234 5678', barcode: '770712345678'),
    balance: 1250,
    guestName: 'Мадина',
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  testWidgets('меню: переключение Кухня/Бар, цены, бейджи и «Блюдо с историей»', (tester) async {
    await tester.pumpWidget(_wrap(const MenuScreen(), [menuProvider.overrideWith((ref) async => _menu)]));
    await tester.pumpAndSettle();

    expect(find.text('Сырники'), findsOneWidget);
    expect(find.text('390 ₽'), findsOneWidget);
    expect(find.text('Выбор команды'), findsOneWidget);
    expect(find.textContaining('информационный характер'), findsOneWidget);

    await tester.tap(find.text('Бар'));
    await tester.pumpAndSettle();
    expect(find.text('Капучино'), findsOneWidget);
    expect(find.text('270 / 290 ₽'), findsOneWidget);
    expect(find.text('Сырники'), findsNothing);

    await tester.tap(find.text('Кухня'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сырники'));
    await tester.pumpAndSettle();
    expect(find.text('Рецепт, который передаётся в семье'), findsOneWidget);
  });

  testWidgets('бонусы: гость без входа видит приглашение', (tester) async {
    await tester.pumpWidget(_wrap(const LoyaltyScreen(), [authControllerProvider.overrideWith(_SignedOut.new)]));
    await tester.pumpAndSettle();
    expect(find.text('Войти по номеру'), findsOneWidget);
  });

  testWidgets('бонусы: баланс с правильной формой слова и номер карты', (tester) async {
    await tester.pumpWidget(
      _wrap(const LoyaltyScreen(), [
        authControllerProvider.overrideWith(_SignedIn.new),
        loyaltySummaryProvider.overrideWith(_FakeSummary.new),
        loyaltyTransactionsProvider.overrideWith(
          (ref) async => [
            LoyaltyTransaction(
              id: 't1',
              date: DateTime.utc(2026, 9, 27, 9),
              amount: 27,
              kind: 'accrual',
              title: 'Начисление бонусов',
            ),
            LoyaltyTransaction(
              id: 't2',
              date: DateTime.utc(2026, 9, 26, 9),
              amount: -100,
              kind: 'redeem',
              title: 'Списание бонусов',
            ),
          ],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('бонусов'), findsOneWidget);
    expect(find.text('7707 1234 5678'), findsOneWidget);
    expect(find.text('+27'), findsOneWidget);
    expect(find.text('−100'), findsOneWidget);
  });
}
