import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// Знак приложения: монограмма «H» в тонком кольце.
///
/// Это собственный знак приложения, а не копия логотипа с сайта. Когда заказчик
/// передаст фирменный логотип в векторе, его можно подставить здесь.
class HcMonogram extends StatelessWidget {
  const HcMonogram({super.key, this.size = 44, this.color = HcColors.accentDark});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.55), width: size < 36 ? 1 : 1.3),
        gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.15)]),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: size * 0.04),
        child: Text(
          'H',
          style: HcType.serif(size: size * 0.56, weight: 500, color: color, height: 1),
        ),
      ),
    );
  }
}

/// Логотип: монограмма + «History» и подпись «coffee boutique».
class HcLogo extends StatelessWidget {
  const HcLogo({super.key, this.size = 44, this.showSubtitle = true, this.color = HcColors.text});

  /// Диаметр монограммы; остальное масштабируется от него.
  final double size;
  final bool showSubtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'History Coffee',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HcMonogram(size: size),
          SizedBox(width: size * 0.28),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'History',
                style: HcType.serif(size: size * 0.62, weight: 600, color: color, height: 1),
              ),
              if (showSubtitle)
                Padding(
                  padding: EdgeInsets.only(top: size * 0.06, left: 1),
                  child: Text(
                    'coffee boutique',
                    style: HcType.sans(size: size * 0.24, weight: 500, color: HcColors.textSecondary, height: 1.1),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
