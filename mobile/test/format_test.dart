import 'package:flutter_test/flutter_test.dart';
import 'package:history_coffee/core/utils/format.dart';

void main() {
  group('pluralRu', () {
    String b(int n) => pluralRu(n, 'бонус', 'бонуса', 'бонусов');

    test('формы', () {
      expect(b(1), 'бонус');
      expect(b(21), 'бонус');
      expect(b(2), 'бонуса');
      expect(b(34), 'бонуса');
      expect(b(0), 'бонусов');
      expect(b(5), 'бонусов');
      expect(b(11), 'бонусов');
      expect(b(12), 'бонусов');
      expect(b(114), 'бонусов');
      expect(b(1250), 'бонусов');
    });
  });

  group('телефон', () {
    test('formatPhone', () {
      expect(formatPhone('+79604316223'), '+7 (960) 431-62-23');
    });

    test('phoneDigits', () {
      expect(phoneDigits('+7 (960) 431-62-23'), '9604316223');
      expect(phoneDigits('89604316223'), '9604316223');
      expect(phoneDigits('960431'), '960431');
    });

    test('маска ввода', () {
      final f = RuPhoneInputFormatter();
      TextEditingValue type(String old, String next) =>
          f.formatEditUpdate(TextEditingValue(text: old), TextEditingValue(text: next));

      expect(type('', '9').text, '+7 (9');
      expect(type('', '9604316223').text, '+7 (960) 431-62-23');
      // вставка номера с восьмёркой
      expect(type('', '8 960 431 62 23').text, '+7 (960) 431-62-23');
      // лишние цифры отбрасываются
      expect(type('', '960431622399').text, '+7 (960) 431-62-23');
      // стирание цифры
      expect(type('+7 (960) 4', '+7 (960) ').text, '+7 (960');
      // стирание символа маски (пробела) стирает и цифру — иначе курсор «застревает»
      expect(type('+7 (960) 4', '+7 (960)4').text, '+7 (960');
    });
  });

  test('formatRub', () {
    expect(formatRub(270), '270 ₽');
    expect(formatRub(1250).replaceAll(' ', ' '), '1 250 ₽');
  });
}
