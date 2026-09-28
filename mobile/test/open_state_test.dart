import 'package:flutter_test/flutter_test.dart';
import 'package:history_coffee/features/contacts/venue.dart';

/// Те же сценарии, что в backend/src/venue/hours.spec.ts.
void main() {
  // Московское время → «МСК-дата» (UTC-объект со сдвигом +3, как возвращает mskNow).
  DateTime msk(String iso) => mskNow(DateTime.parse('$iso+03:00'));
  final hours = Venue.fallback.hours;

  test('mskNow не зависит от часового пояса телефона', () {
    final m = mskNow(DateTime.utc(2026, 9, 28, 5, 30));
    expect(m.weekday, DateTime.monday);
    expect(m.hour, 8);
    expect(m.minute, 30);
  });

  group('часы History Coffee', () {
    test('пн 08:00 — открыто до 23:00', () {
      final s = computeOpenState(hours, msk('2026-09-28T08:00:00'));
      expect(s.isOpen, isTrue);
      expect(s.closesAt, '23:00');
      expect(describeOpenState(s, msk('2026-09-28T08:00:00')), 'Открыто до 23:00');
    });

    test('пн 07:59 — откроется сегодня в 08:00', () {
      final now = msk('2026-09-28T07:59:00');
      final s = computeOpenState(hours, now);
      expect(s.isOpen, isFalse);
      expect(describeOpenState(s, now), 'Закрыто · откроется сегодня в 08:00');
    });

    test('пт 23:00 — откроется завтра в 09:00', () {
      final now = msk('2026-10-02T23:00:00');
      expect(describeOpenState(computeOpenState(hours, now), now), 'Закрыто · откроется завтра в 09:00');
    });

    test('вс 08:30 — ещё закрыто', () {
      expect(computeOpenState(hours, msk('2026-10-04T08:30:00')).isOpen, isFalse);
    });
  });

  group('ночные смены и выходные', () {
    const custom = [
      DayHours(day: 1),
      DayHours(day: 2, open: '18:00', close: '02:00'),
      DayHours(day: 3, open: '10:00', close: '20:00'),
      DayHours(day: 4),
      DayHours(day: 5),
      DayHours(day: 6),
      DayHours(day: 7),
    ];

    test('ср 01:00 — открыто по хвосту вторника', () {
      final s = computeOpenState(custom, msk('2026-09-30T01:00:00'));
      expect(s.isOpen, isTrue);
      expect(s.closesAt, '02:00');
    });

    test('ср 03:00 — откроется в 10:00', () {
      final s = computeOpenState(custom, msk('2026-09-30T03:00:00'));
      expect(s.nextOpenDay, 3);
      expect(s.nextOpenTime, '10:00');
    });

    test('чт — ближайшее открытие во вторник, в винительном падеже', () {
      final now = msk('2026-10-01T12:00:00');
      expect(describeOpenState(computeOpenState(custom, now), now), 'Закрыто · откроется в вторник в 18:00');
    });

    test('пятница → «в пятницу»', () {
      const onlyFriday = [DayHours(day: 5, open: '10:00', close: '12:00')];
      final now = msk('2026-09-28T12:00:00');
      expect(describeOpenState(computeOpenState(onlyFriday, now), now), 'Закрыто · откроется в пятницу в 10:00');
    });
  });
}
