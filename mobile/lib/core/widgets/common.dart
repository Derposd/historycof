import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/typography.dart';
import 'motion.dart';

/// Подпись раздела: спокойный текст в строку (без капслока и разрядки).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color = HcColors.textSecondary, this.size = 13});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: HcType.sans(size: size, weight: 500, color: color, height: 1.25, letterSpacing: 0.1),
  );
}

/// Иконка в мягкой плитке со скруглёнными углами.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 44, this.color = HcColors.accentDark});

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * 0.32), color: color.withValues(alpha: 0.11)),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}

/// Выделенный текст с акцентной полосой слева (легенда блюда, ответы).
class AccentNote extends StatelessWidget {
  const AccentNote({super.key, required this.child, this.color = HcColors.gold});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Тонкий hairline-разделитель с отступами.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.vertical = 0});

  final double indent;
  final double vertical;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: vertical),
    child: Divider(indent: indent, endIndent: indent),
  );
}

/// Заголовок экрана: крупный сериф + подзаголовок капслоком.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.overline, this.trailing});

  final String title;
  final String? overline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HcSpace.gutter, HcSpace.m, HcSpace.gutter, HcSpace.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[SectionLabel(overline!), const SizedBox(height: 4)],
                Text(title, style: HcType.serif(size: 34, weight: 600)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Спокойное состояние ошибки с кнопкой «Повторить».
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconTile(Icons.wifi_off_rounded, size: 56, color: HcColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              ApiException.messageOf(error),
              textAlign: TextAlign.center,
              style: HcType.sans(color: HcColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Пустое состояние.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon, size: 64),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: HcType.serif(size: 24)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: HcType.sans(color: HcColors.textSecondary),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Мягкий «скелетон» для загрузки: по песочной плашке проходит тёплый блик.
/// Блики всех плашек на экране идут синхронно — от времени, а не от момента появления.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 10});

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 1600);
  late final AnimationController _c = AnimationController(vsync: this, duration: _period);

  @override
  void initState() {
    super.initState();
    final phase = (DateTime.now().millisecondsSinceEpoch % _period.inMilliseconds) / _period.inMilliseconds;
    _c
      ..value = phase
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = HcColors.backgroundAlt;
    final light = Color.alphaBlend(Colors.white.withValues(alpha: 0.7), base);
    final box = BorderRadius.circular(widget.radius);
    if (Motion.reduced(context)) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: base, borderRadius: box),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: box,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, light, base],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideGradient(Curves.easeInOutSine.transform(_c.value)),
          ),
        ),
      ),
    );
  }
}

/// Сдвигает градиент по ширине: 0 — блик за левым краем, 1 — за правым.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

void showHcSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
