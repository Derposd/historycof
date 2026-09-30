import 'package:flutter/painting.dart';

/// Палитра History Coffee — тёплая гамма сайта, но заметно светлее и воздушнее
/// (по просьбе заказчика: менее насыщенный беж, под глассморфизм).
abstract final class HcColors {
  /// Фон (база) — очень светлый тёплый айвори.
  static const background = Color(0xFFFBF7EF);

  /// Фон вторичный — бледный песочный, для лёгкого разделения блоков.
  static const backgroundAlt = Color(0xFFF5EEE0);

  /// Основной акцент — приглушённый оливковый.
  static const accent = Color(0xFF8A9770);

  /// Акцент hover/pressed — зелёный из логотипа кофейни.
  static const accentDark = brandGreen;

  /// Цвета логотипа: зелёное кольцо и знак, светлый круг внутри.
  static const brandGreen = Color(0xFF5E6D50);
  static const brandLight = Color(0xFFEAE9E5);

  /// Текст основной — эспрессо.
  static const text = Color(0xFF362B22);

  /// Текст вторичный — тёплый серо-коричневый.
  static const textSecondary = Color(0xFF7A6F5E);

  /// Бейджи «Новинка» / «Хит продаж» — приглушённое золото.
  static const gold = Color(0xFFE3C57F);

  /// Предупреждения, жалобы, списания — терракотовый (не резкий красный).
  static const terracotta = Color(0xFFC97B5D);

  /// Стекло: заливка, обводка, тень.
  static const glassFill = Color(0x9EFFFFFF); // ~0.62
  static const glassFillStrong = Color(0xB8FFFFFF); // ~0.72, для модалок
  static const glassBorder = Color(0x66FFFFFF); // 0.4
  static const glassShadow = Color(0x14362B22);

  /// Тонкие hairline-разделители.
  static const hairline = Color(0x1F362B22);
}
