import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Капслок-лейбл с трекингом.
class CapsLabel extends StatelessWidget {
  const CapsLabel(this.text, {super.key, this.color = HcColors.textSecondary, this.size = 11.5});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: HcType.caps(size: size, color: color));
}

/// Лёгкая круглая иконка-аутлайн в кружке (как блок «Четыре причины зайти к нам»).
class RoundOutlineIcon extends StatelessWidget {
  const RoundOutlineIcon(this.icon, {super.key, this.size = 44, this.color = HcColors.accentDark});

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.9),
        color: Colors.white.withValues(alpha: 0.35),
      ),
      child: Icon(icon, size: size * 0.45, color: color),
    );
  }
}

/// Крупная декоративная кавычка для цитат и «Блюда с историей».
class QuoteMark extends StatelessWidget {
  const QuoteMark({super.key, this.size = 64, this.color = HcColors.gold});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Text('“', style: HcType.serif(size: size, weight: 500, color: color, height: 0.9)),
      );
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
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[CapsLabel(overline!), const SizedBox(height: 6)],
                Text(title, style: HcType.serif(size: 36, weight: 500)),
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
            const RoundOutlineIcon(Icons.wifi_off_rounded, size: 56, color: HcColors.textSecondary),
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
          RoundOutlineIcon(icon, size: 64),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: HcType.serif(size: 24)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, textAlign: TextAlign.center, style: HcType.sans(color: HcColors.textSecondary)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Мягкий «скелетон» для загрузки.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 10});

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.9).animate(_c),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: HcColors.backgroundAlt, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

void showHcSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
