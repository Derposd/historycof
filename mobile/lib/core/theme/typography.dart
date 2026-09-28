import 'package:flutter/material.dart';

import 'colors.dart';

/// Шрифты подключены как variable-TTF, поэтому вес задаём и через [FontWeight],
/// и явно через ось `wght` — так начертание одинаково на Android и iOS.
abstract final class HcType {
  static const serifFamily = 'Cormorant';
  static const sansFamily = 'Golos';

  static TextStyle serif({
    double size = 28,
    int weight = 500,
    Color color = HcColors.text,
    double height = 1.15,
    double letterSpacing = 0,
    bool italic = false,
  }) =>
      TextStyle(
        fontFamily: serifFamily,
        fontSize: size,
        fontWeight: _weight(weight),
        fontVariations: [FontVariation('wght', weight.clamp(300, 700).toDouble())],
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle sans({
    double size = 15,
    int weight = 400,
    Color color = HcColors.text,
    double height = 1.45,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        fontSize: size,
        fontWeight: _weight(weight),
        fontVariations: [FontVariation('wght', weight.clamp(400, 900).toDouble())],
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Капслок-лейбл с трекингом, как «МЕНЮ», «О НАС», «ТЕЛЕФОН» на сайте.
  /// Текст передавайте уже в верхнем регистре или через [HcCapsLabel].
  static TextStyle caps({double size = 11.5, Color color = HcColors.textSecondary, int weight = 500}) =>
      sans(size: size, weight: weight, color: color, height: 1.2, letterSpacing: size * 0.16);

  static FontWeight _weight(int w) => switch (w) {
        <= 300 => FontWeight.w300,
        <= 400 => FontWeight.w400,
        <= 500 => FontWeight.w500,
        <= 600 => FontWeight.w600,
        <= 700 => FontWeight.w700,
        _ => FontWeight.w800,
      };
}
