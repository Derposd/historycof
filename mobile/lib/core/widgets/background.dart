import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Тёплый фон с едва заметными цветовыми пятнами — чтобы стеклу было что размывать.
/// [intensity] 1.0 — для экрана бонусной карты, 0.5 — для обычных экранов.
class HcBackground extends StatelessWidget {
  const HcBackground({super.key, required this.child, this.intensity = 0.5});

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: HcColors.background),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BlobsPainter(intensity)),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BlobsPainter extends CustomPainter {
  _BlobsPainter(this.intensity);

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset c, double r, Color color, double alpha) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha * intensity), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }

    final w = size.width;
    final h = size.height;
    blob(Offset(w * 0.95, h * 0.06), w * 0.75, HcColors.gold, 0.45);
    blob(Offset(w * -0.05, h * 0.38), w * 0.8, HcColors.accent, 0.28);
    blob(Offset(w * 0.85, h * 0.78), w * 0.7, HcColors.terracotta, 0.16);
    blob(Offset(w * 0.2, h * 1.02), w * 0.6, HcColors.gold, 0.25);
  }

  @override
  bool shouldRepaint(_BlobsPainter old) => old.intensity != intensity;
}
