import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'motion.dart';

/// Знак приложения: монограмма «H» в тонком кольце.
///
/// Это собственный знак приложения, а не копия логотипа с сайта. Когда заказчик
/// передаст фирменный логотип в векторе, его можно подставить здесь.
///
/// С [animate] знак «рисуется» при первом показе: кольцо прорисовывается
/// линией по часовой стрелке, затем проявляется буква.
class HcMonogram extends StatelessWidget {
  const HcMonogram({super.key, this.size = 44, this.color = HcColors.accentDark, this.progress});

  final double size;
  final Color color;

  /// 0…1 — стадия прорисовки (null — знак целиком).
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress ?? 1;
    final ring = Curves.easeInOutCubic.transform((p / 0.7).clamp(0, 1));
    final letter = Curves.easeOutCubic.transform(((p - 0.45) / 0.55).clamp(0, 1));
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(ring, color.withValues(alpha: 0.55), size < 36 ? 1 : 1.3),
        child: Opacity(
          opacity: letter,
          child: Transform.scale(
            scale: 0.86 + 0.14 * letter,
            child: Padding(
              padding: EdgeInsets.only(top: size * 0.04),
              child: Center(
                child: Text(
                  'H',
                  style: HcType.serif(size: size * 0.56, weight: 500, color: color, height: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.color, this.width);

  final double t;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(width / 2);
    // Мягкая подложка проявляется вместе с кольцом.
    canvas.drawCircle(
      rect.center,
      size.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.7 * t),
            Colors.white.withValues(alpha: 0.15 * t),
          ],
        ).createShader(rect),
    );
    if (t <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      2 * math.pi * t,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = t < 1 ? StrokeCap.round : StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.color != color || old.width != width;
}

/// Логотип: монограмма + «History» и подпись «coffee boutique».
/// С [animate] логотип собирается при первом показе (≈1,4 с).
class HcLogo extends StatefulWidget {
  const HcLogo({super.key, this.size = 44, this.showSubtitle = true, this.color = HcColors.text, this.animate = false});

  /// Диаметр монограммы; остальное масштабируется от него.
  final double size;
  final bool showSubtitle;
  final Color color;
  final bool animate;

  @override
  State<HcLogo> createState() => _HcLogoState();
}

class _HcLogoState extends State<HcLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    value: widget.animate ? 0 : 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.value < 1) {
      if (Motion.reduced(context)) {
        _c.value = 1;
      } else if (!_c.isAnimating) {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      label: 'History Coffee',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final p = _c.value;
          // Слово выезжает из-за знака, подпись проявляется последней.
          final word = Curves.easeOutCubic.transform(((p - 0.35) / 0.5).clamp(0, 1));
          final sub = Curves.easeOut.transform(((p - 0.6) / 0.4).clamp(0, 1));
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HcMonogram(size: size, progress: p),
              SizedBox(width: size * 0.28),
              ClipRect(
                child: Opacity(
                  opacity: word,
                  child: Transform.translate(
                    offset: Offset(-size * 0.35 * (1 - word), 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'History',
                          style: HcType.serif(size: size * 0.62, weight: 600, color: widget.color, height: 1),
                        ),
                        if (widget.showSubtitle)
                          Padding(
                            padding: EdgeInsets.only(top: size * 0.06, left: 1),
                            child: Opacity(
                              opacity: sub,
                              child: Text(
                                'coffee boutique',
                                style: HcType.sans(
                                  size: size * 0.24,
                                  weight: 500,
                                  color: HcColors.textSecondary,
                                  height: 1.1,
                                  // Разрядка «собирается» к обычной — как будто надпись оседает на место.
                                  letterSpacing: 1.2 * (1 - sub),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
