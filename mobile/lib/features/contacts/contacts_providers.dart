import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'venue.dart';

/// Контакты с сервера (редактируются в админке). Без сети — данные из брифа.
final venueProvider = FutureProvider<Venue>((ref) async {
  try {
    final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/venue', auth: false);
    return Venue.fromJson(json);
  } catch (_) {
    return Venue.fallback;
  }
});

/// Тикает раз в минуту — чтобы индикатор «открыто/закрыто» обновлялся сам.
final minuteTickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

final openStateProvider = Provider<OpenState>((ref) {
  final venue = ref.watch(venueProvider).value ?? Venue.fallback;
  final now = ref.watch(minuteTickerProvider).value ?? DateTime.now();
  return computeOpenState(venue.hours, mskNow(now));
});
