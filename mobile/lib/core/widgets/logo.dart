import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'brand_paths.dart';
import 'motion.dart';

/// Знак кофейни: зелёное кольцо, в нём H · перо · S (пути — `brand_paths.dart`,
/// источник — docs/brand/logo.svg).
///
/// С [progress] знак «рисуется»: кольцо прорисовывается линией по часовой стрелке,
/// затем проявляется H, сверху мягко опускается перо и появляется S.
/// [fill] — светлый круг внутри кольца; для приглушённых заглушек передайте прозрачный.
class HcMonogram extends StatelessWidget {
  const HcMonogram({
    super.key,
    this.size = 44,
    this.color = HcColors.brandGreen,
    this.fill = HcColors.brandLight,
    this.progress,
  });

  final double size;
  final Color color;
  final Color fill;

  /// 0…1 — стадия прорисовки (null — знак целиком).
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BrandPainter(progress ?? 1, color, fill)),
    );
  }
}

class _BrandPainter extends CustomPainter {
  _BrandPainter(this.p, this.color, this.fill);

  final double p;
  final Color color;
  final Color fill;

  static final _h = parseSvgPath(brandPathH);
  static final _feather = parseSvgPath(brandPathFeather);
  static final _s = parseSvgPath(brandPathS);
  static final _featherBox = _feather.getBounds();

  static double _stage(double p, double from, double to) =>
      Curves.easeOutCubic.transform(((p - from) / (to - from)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100;
    canvas.scale(k);
    final ring = Curves.easeInOutCubic.transform((p / 0.55).clamp(0.0, 1.0));
    // Светлый круг проявляется вместе с кольцом
    if (fill.a > 0) {
      canvas.drawCircle(const Offset(50, 50), brandRingRadius, Paint()..color = fill.withValues(alpha: fill.a * ring));
    }
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(50, 50), radius: brandRingRadius),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = brandRingWidth
          ..strokeCap = ring < 1 ? StrokeCap.round : StrokeCap.butt,
      );
    }
    void glyph(Path path, double t, {Offset shift = Offset.zero, double turn = 0, Offset? pivot}) {
      if (t <= 0) return;
      canvas.save();
      canvas.translate(shift.dx * (1 - t), shift.dy * (1 - t));
      if (turn != 0 && pivot != null) {
        canvas
          ..translate(pivot.dx, pivot.dy)
          ..rotate(turn * (1 - t))
          ..translate(-pivot.dx, -pivot.dy);
      }
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: color.a * t));
      canvas.restore();
    }

    glyph(_h, _stage(p, 0.42, 0.72), shift: const Offset(-2, 0));
    // Перо опускается сверху и чуть доворачивается, как будто ложится на место
    glyph(_feather, _stage(p, 0.52, 0.9), shift: const Offset(0, -6), turn: -0.25, pivot: _featherBox.bottomCenter);
    glyph(_s, _stage(p, 0.62, 0.95), shift: const Offset(2, 0));
  }

  @override
  bool shouldRepaint(_BrandPainter old) => old.p != p || old.color != color || old.fill != fill;
}

/// Разбор пути SVG из абсолютных команд M, L, C, Z (так их пишет трассировщик логотипа).
Path parseSvgPath(String d) {
  final path = Path()..fillType = PathFillType.evenOdd;
  final tokens = RegExp(r'[MLCZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = 'M';
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp('[MLCZ]').hasMatch(t)) {
      cmd = t;
      i++;
      if (cmd == 'Z') {
        path.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        path.moveTo(n(), n());
        cmd = 'L'; // по правилам SVG следующие пары после M — это L
      case 'L':
        path.lineTo(n(), n());
      case 'C':
        path.cubicTo(n(), n(), n(), n(), n(), n());
    }
  }
  return path;
}

/// Логотип: знак + «History» и подпись «coffee boutique» (часть фирменного логотипа — по решению заказчика).
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
