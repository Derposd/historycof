import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Русская плюрализация: plural(5, 'бонус', 'бонуса', 'бонусов') → «бонусов».
String pluralRu(num n, String one, String few, String many) {
  final v = n.abs().floor();
  final mod10 = v % 10;
  final mod100 = v % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

final _number = NumberFormat.decimalPattern('ru');

/// 1250 → «1 250»
String formatNumber(num n) => _number.format(n);

/// 270 → «270 ₽»
String formatRub(num n) => '${formatNumber(n)} ₽';

/// Дата новости: «28 сентября», для прошлых лет — «28 сентября 2025».
String formatNewsDate(DateTime d, {DateTime? now}) {
  final local = d.toLocal();
  final ref = now ?? DateTime.now();
  return local.year == ref.year
      ? DateFormat('d MMMM', 'ru').format(local)
      : DateFormat('d MMMM y', 'ru').format(local);
}

/// «28 сент., 14:05»
String formatDateTimeShort(DateTime d) => DateFormat('d MMM, HH:mm', 'ru').format(d.toLocal());

/// +79604316223 → +7 (960) 431-62-23
String formatPhone(String e164) {
  final d = e164.replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return e164;
  return '+7 (${d.substring(1, 4)}) ${d.substring(4, 7)}-${d.substring(7, 9)}-${d.substring(9, 11)}';
}

/// Извлекает 10 значащих цифр российского номера из пользовательского ввода.
String phoneDigits(String input) {
  var d = input.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && (d.startsWith('7') || d.startsWith('8'))) d = d.substring(1);
  return d.length > 10 ? d.substring(0, 10) : d;
}

/// Маска ввода «+7 (___) ___-__-__». Работает с вставкой номера целиком.
class RuPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Пользователь стирает символ маски — стираем и цифру перед ним.
    if (newValue.text.length < oldValue.text.length && digits == oldValue.text.replaceAll(RegExp(r'\D'), '')) {
      digits = digits.isEmpty ? '' : digits.substring(0, digits.length - 1);
    }
    if (digits.startsWith('7') || digits.startsWith('8')) digits = digits.substring(1);
    if (digits.length > 10) digits = digits.substring(0, 10);
    final text = maskPhone(digits);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  static String maskPhone(String d) {
    if (d.isEmpty) return '';
    final b = StringBuffer('+7 (');
    for (var i = 0; i < d.length; i++) {
      if (i == 3) b.write(') ');
      if (i == 6 || i == 8) b.write('-');
      b.write(d[i]);
    }
    return b.toString();
  }
}
