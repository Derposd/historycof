import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'motion.dart';

/// Тёплый фон с едва заметными цветовыми пятнами — чтобы стеклу было что размывать.
///
/// У каждой вкладки своя композиция пятен ([variant]); при переключении пятна
/// плавно перетекают на новые места. Анимация идёт только во время перехода —
/// в покое фон статичен и не тратит батарею.
/// [intensity] 1.0 — для экрана бонусной карты, 0.5 — для обычных экранов.
class HcBackground extends StatefulWidget {
  const HcBackground({super.key, required this.child, this.intensity = 0.5, this.variant = 0});

  final Widget child;
  final double intensity;
  final int variant;

  @override
  State<HcBackground> createState() => _HcBackgroundState();
}

class _HcBackgroundState extends State<HcBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);

  late _Scene _from = _Scene.of(widget.variant, widget.intensity);
  late _Scene _to = _from;

  _Scene get _current => _Scene.lerp(_from, _to, _t.value);

  @override
  void didUpdateWidget(HcBackground old) {
    super.didUpdateWidget(old);
    if (old.variant == widget.variant && old.intensity == widget.intensity) return;
    // Начинаем с того места, где пятна сейчас, — даже если прошлый переход не доиграл.
    _from = _current;
    _to = _Scene.of(widget.variant, widget.intensity);
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: HcColors.background),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _t,
                  builder: (context, _) => CustomPaint(painter: _BlobsPainter(_current)),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Пятно: центр и радиус в долях экрана, цвет и насыщенность.
class _Blob {
  const _Blob(this.x, this.y, this.r, this.color, this.alpha);

  final double x, y, r, alpha;
  final Color color;

  static _Blob lerp(_Blob a, _Blob b, double t) => _Blob(
    lerpDouble(a.x, b.x, t)!,
    lerpDouble(a.y, b.y, t)!,
    lerpDouble(a.r, b.r, t)!,
    Color.lerp(a.color, b.color, t)!,
    lerpDouble(a.alpha, b.alpha, t)!,
  );
}

class _Scene {
  const _Scene(this.blobs, this.intensity);

  final List<_Blob> blobs;
  final double intensity;

  /// Композиции для вкладок: Главная, Меню, Бонусы, Контакты, Профиль.
  static const _layouts = <List<_Blob>>[
    [
      _Blob(0.95, 0.06, 0.75, HcColors.gold, 0.45),
      _Blob(-0.05, 0.38, 0.80, HcColors.accent, 0.28),
      _Blob(0.85, 0.78, 0.70, HcColors.terracotta, 0.16),
      _Blob(0.20, 1.02, 0.60, HcColors.gold, 0.25),
    ],
    [
      _Blob(0.05, 0.02, 0.70, HcColors.gold, 0.40),
      _Blob(1.05, 0.30, 0.75, HcColors.accent, 0.26),
      _Blob(0.10, 0.80, 0.65, HcColors.terracotta, 0.14),
      _Blob(0.90, 1.00, 0.60, HcColors.gold, 0.22),
    ],
    [
      _Blob(0.85, 0.10, 0.85, HcColors.gold, 0.50),
      _Blob(0.05, 0.22, 0.75, HcColors.accent, 0.34),
      _Blob(0.60, 0.62, 0.70, HcColors.terracotta, 0.20),
      _Blob(0.10, 0.95, 0.60, HcColors.gold, 0.28),
    ],
    [
      _Blob(1.00, 0.20, 0.80, HcColors.accent, 0.32),
      _Blob(0.00, 0.08, 0.65, HcColors.gold, 0.40),
      _Blob(0.25, 0.70, 0.70, HcColors.gold, 0.18),
      _Blob(0.95, 0.95, 0.60, HcColors.terracotta, 0.16),
    ],
    [
      _Blob(0.10, 0.05, 0.75, HcColors.terracotta, 0.20),
      _Blob(0.95, 0.30, 0.70, HcColors.gold, 0.36),
      _Blob(0.00, 0.72, 0.70, HcColors.accent, 0.26),
      _Blob(0.80, 1.05, 0.60, HcColors.gold, 0.22),
    ],
  ];

  static _Scene of(int variant, double intensity) => _Scene(_layouts[variant.clamp(0, _layouts.length - 1)], intensity);

  static _Scene lerp(_Scene a, _Scene b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return _Scene([
      for (var i = 0; i < a.blobs.length; i++) _Blob.lerp(a.blobs[i], b.blobs[i], t),
    ], lerpDouble(a.intensity, b.intensity, t)!);
  }
}

class _BlobsPainter extends CustomPainter {
  _BlobsPainter(this.scene);

  final _Scene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (final b in scene.blobs) {
      final c = Offset(w * b.x, h * b.y);
      final r = w * b.r;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withValues(alpha: b.alpha * scene.intensity),
            b.color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobsPainter old) => old.scene != scene;
}
