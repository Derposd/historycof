import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// Словесный знак «HISTORY»: тонкий сериф с трекингом и стилизованным пером
/// над «I» вместо точки.
///
/// Это реконструкция по скриншотам сайта. Когда заказчик передаст оригинальный
/// логотип в SVG — заменить на него (см. docs/client-questions.md, п. 5).
class HistoryWordmark extends StatelessWidget {
  const HistoryWordmark({super.key, this.size = 30, this.color = HcColors.text});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = HcType.serif(size: size, weight: 400, color: color, letterSpacing: size * 0.22, height: 1);
    // Перо рисуем над второй буквой; её центр находим через TextPainter.
    final tp = TextPainter(text: TextSpan(text: 'H', style: style), textDirection: TextDirection.ltr)..layout();
    final iTp = TextPainter(text: TextSpan(text: 'I', style: style.copyWith(letterSpacing: 0)), textDirection: TextDirection.ltr)
      ..layout();
    final iCenter = tp.width + iTp.width / 2;

    return Semantics(
      label: 'History',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(top: size * 0.55),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text('HISTORY', style: style),
            Positioned(
              left: iCenter - size * 0.2,
              top: -size * 0.62,
              child: CustomPaint(size: Size(size * 0.4, size * 0.6), painter: FeatherPainter(color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Стилизованное перо: лёгкая изогнутая лопасть и тонкий стержень.
class FeatherPainter extends CustomPainter {
  FeatherPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final vane = Path()
      ..moveTo(w * 0.38, h * 0.98)
      ..cubicTo(w * 0.05, h * 0.62, w * 0.2, h * 0.2, w * 0.92, h * 0.0)
      ..cubicTo(w * 0.86, h * 0.42, w * 0.7, h * 0.74, w * 0.38, h * 0.98)
      ..close();
    canvas.drawPath(vane, Paint()..color = color.withValues(alpha: 0.9));

    final quill = Path()
      ..moveTo(w * 0.3, h * 1.05)
      ..quadraticBezierTo(w * 0.52, h * 0.55, w * 0.9, h * 0.04);
    canvas.drawPath(
      quill,
      Paint()
        ..color = HcColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.05).clamp(0.6, 1.6),
    );
  }

  @override
  bool shouldRepaint(FeatherPainter old) => old.color != color;
}
