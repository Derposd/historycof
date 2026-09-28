import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/providers.dart';

class LoyaltyCard {
  const LoyaltyCard({required this.cardNumber, required this.barcode});

  /// «7707 1234 5678»
  final String cardNumber;

  /// Трек карты iikoCard — кодируется в QR, бариста сканирует его на кассе.
  final String barcode;

  factory LoyaltyCard.fromJson(Map<String, dynamic> j) =>
      LoyaltyCard(cardNumber: j['cardNumber'] as String, barcode: j['barcode'] as String);
}

class LoyaltySummary {
  const LoyaltySummary({required this.card, required this.balance, this.guestName});

  final LoyaltyCard card;
  final num balance;
  final String? guestName;

  factory LoyaltySummary.fromJson(Map<String, dynamic> j) => LoyaltySummary(
        card: LoyaltyCard.fromJson(j['card'] as Map<String, dynamic>),
        balance: j['balance'] as num,
        guestName: j['guestName'] as String?,
      );
}

class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.kind,
    required this.title,
    this.orderNumber,
  });

  final String id;
  final DateTime date;
  final num amount;

  /// accrual | redeem | other
  final String kind;
  final String title;
  final String? orderNumber;

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> j) => LoyaltyTransaction(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        amount: j['amount'] as num,
        kind: j['kind'] as String? ?? 'other',
        title: j['title'] as String? ?? 'Операция',
        orderNumber: j['orderNumber'] as String?,
      );
}

/// Баланс и карта. Пересоздаётся при входе/выходе.
final loyaltySummaryProvider =
    AsyncNotifierProvider.autoDispose<LoyaltySummaryController, LoyaltySummary?>(LoyaltySummaryController.new);

class LoyaltySummaryController extends AsyncNotifier<LoyaltySummary?> {
  @override
  Future<LoyaltySummary?> build() {
    ref.watch(isSignedInProvider); // пересобираемся при входе/выходе
    return _load(fresh: false);
  }

  Future<LoyaltySummary?> _load({required bool fresh}) async {
    if (!ref.read(isSignedInProvider)) return null;
    final json = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
          '/loyalty',
          query: fresh ? {'refresh': 'true'} : null,
        );
    return LoyaltySummary.fromJson(json);
  }

  /// Pull-to-refresh: просим сервер не брать баланс из кэша, а сходить в iiko.
  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(fresh: true));
  }
}

final loyaltyTransactionsProvider = FutureProvider.autoDispose<List<LoyaltyTransaction>>((ref) async {
  final signedIn = ref.watch(isSignedInProvider);
  if (!signedIn) return const [];
  final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>(
    '/loyalty/transactions',
    query: {'pageSize': 30},
  );
  return (json['items'] as List<dynamic>).map((e) => LoyaltyTransaction.fromJson(e as Map<String, dynamic>)).toList();
});
