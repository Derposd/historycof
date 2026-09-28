import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Единые параметры анимаций: одна кривая и три длительности на всё приложение,
/// чтобы движение ощущалось согласованным. Если в системе включено
/// «Убрать анимации», длительности обнуляются.
abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 480);

  /// Мягкое «выкатывание» без отскока.
  static const curve = Curves.easeOutCubic;

  /// Для элементов, которые «пружинят» после нажатия.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

/// Лёгкая тактильная отдача на выбор (переключатели, вкладки, чипы).
void selectionHaptic() => HapticFeedback.selectionClick();

/// Мягкое «нажатие»: элемент чуть уменьшается под пальцем и плавно возвращается.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97, this.haptic = false});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) selectionHaptic();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.of(context, _down ? const Duration(milliseconds: 90) : Motion.medium),
        curve: _down ? Curves.easeOut : Motion.emphasized,
        child: widget.child,
      ),
    );
  }
}

/// Появление при первом показе: прозрачность + небольшой сдвиг снизу.
/// [index] даёт «лесенку» для списков (задержка растёт, но не бесконечно).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 14});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.slow);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Motion.curve);

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 45 * widget.index.clamp(0, 8));
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Переход «сквозь»: старое содержимое растворяется, новое проявляется со
/// сдвигом по направлению [direction] (1 — вправо, -1 — влево, 0 — снизу).
Widget fadeThroughTransition(Widget child, Animation<double> animation, {int direction = 0}) {
  final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
  final begin = direction == 0 ? const Offset(0, 0.02) : Offset(0.04 * direction, 0);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween(begin: begin, end: Offset.zero).animate(curved),
      child: child,
    ),
  );
}
