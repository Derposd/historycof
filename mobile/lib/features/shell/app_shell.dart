import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/motion.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _tabs = [
  _Tab('Главная', Icons.home_outlined, Icons.home_rounded),
  _Tab('Меню', Icons.restaurant_menu_outlined, Icons.restaurant_menu),
  _Tab('Бонусы', Icons.qr_code_2_rounded, Icons.qr_code_2_rounded),
  _Tab('Контакты', Icons.place_outlined, Icons.place),
  _Tab('Профиль', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Каркас с плавающей стеклянной нижней навигацией.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell, required this.children});

  final StatefulNavigationShell shell;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: HcBackground(
        variant: shell.currentIndex,
        intensity: shell.currentIndex == 2 ? 0.9 : 0.5,
        child: _FadeBranches(index: shell.currentIndex, children: children),
      ),
      bottomNavigationBar: _GlassNavBar(
        index: shell.currentIndex,
        onTap: (i) {
          if (i != shell.currentIndex) selectionHaptic();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    );
  }
}

/// Вкладки лежат стопкой и сохраняют состояние; активная плавно проявляется
/// с лёгким «подъёмом», предыдущая дорисовывает исчезновение, остальные
/// не рисуются, не анимируются и не получают касаний.
class _FadeBranches extends StatefulWidget {
  const _FadeBranches({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_FadeBranches> createState() => _FadeBranchesState();
}

class _FadeBranchesState extends State<_FadeBranches> {
  /// Вкладки, которые сейчас растворяются. Множество, а не одна вкладка: при быстрых
  /// переключениях (Главная → Меню → Бонусы) исчезновение каждой должно доиграть до конца,
  /// иначе недорастворённая вкладка остаётся видна сквозь стекло.
  final Set<int> _leaving = {};

  @override
  void didUpdateWidget(_FadeBranches old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _leaving
        ..add(old.index)
        ..remove(widget.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.medium);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (i, child) in widget.children.indexed)
          Offstage(
            // Полностью скрытые вкладки не рисуются вовсе (состояние сохраняется).
            offstage: i != widget.index && !_leaving.contains(i),
            child: IgnorePointer(
              ignoring: i != widget.index,
              child: TickerMode(
                enabled: i == widget.index || _leaving.contains(i),
                child: AnimatedOpacity(
                  opacity: i == widget.index ? 1 : 0,
                  duration: d,
                  curve: Motion.curve,
                  onEnd: () {
                    if (i != widget.index && _leaving.contains(i) && mounted) setState(() => _leaving.remove(i));
                  },
                  child: AnimatedSlide(
                    offset: i == widget.index ? Offset.zero : const Offset(0, 0.012),
                    duration: d,
                    curve: Motion.curve,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(HcSpace.l, 0, HcSpace.l, bottom > 0 ? bottom : HcSpace.l),
      child: Glass(
        radius: HcRadii.pill,
        blur: 22,
        fill: const Color(0xB8FFFFFF),
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / _tabs.length;
            return SizedBox(
              height: 56,
              child: Stack(
                children: [
                  // Одна подсветка, которая «перетекает» под выбранную вкладку.
                  Positioned.fill(
                    child: _LiquidPill(index: index, slot: w),
                  ),
                  Row(
                    children: [
                      for (final (i, tab) in _tabs.indexed)
                        Expanded(
                          child: _NavItem(tab: tab, selected: i == index, onTap: () => onTap(i)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Подсветка выбранной вкладки, которая переезжает как капля: передний край
/// уходит к новой вкладке первым, задний догоняет — на полпути пилюля
/// вытягивается, а у цели собирается обратно.
class _LiquidPill extends StatefulWidget {
  const _LiquidPill({required this.index, required this.slot});

  final int index;
  final double slot;

  @override
  State<_LiquidPill> createState() => _LiquidPillState();
}

class _LiquidPillState extends State<_LiquidPill> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))
    ..value = 1;
  late double _fromLeft = widget.index * widget.slot;
  late double _fromRight = _fromLeft + widget.slot;

  static const _lead = Interval(0, 0.72, curve: Cubic(0.3, 0, 0, 1));
  static const _trail = Interval(0.22, 1, curve: Cubic(0.3, 0, 0, 1));

  /// Положение краёв на пути к вкладке [index]: край по направлению движения —
  /// «ведущий», противоположный — «догоняющий».
  (double, double) _edgesTo(int index, double slot) {
    final toLeft = index * slot;
    final toRight = toLeft + slot;
    final forward = toLeft >= _fromLeft;
    final t = _c.value;
    return (
      _fromLeft + (toLeft - _fromLeft) * (forward ? _trail : _lead).transform(t),
      _fromRight + (toRight - _fromRight) * (forward ? _lead : _trail).transform(t),
    );
  }

  @override
  void didUpdateWidget(_LiquidPill old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index && old.slot == widget.slot) return;
    if (old.slot != widget.slot && old.index == widget.index) {
      // Поменялась ширина (поворот экрана) — просто встаём на место.
      _fromLeft = widget.index * widget.slot;
      _fromRight = _fromLeft + widget.slot;
      _c.value = 1;
      return;
    }
    // Стартуем оттуда, где пилюля сейчас, даже если прошлый переход не доиграл.
    final (l, r) = _edgesTo(old.index, old.slot);
    _fromLeft = l;
    _fromRight = r;
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
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final (left, right) = _edgesTo(widget.index, widget.slot);
        return Stack(
          children: [
            Positioned(
              left: left,
              width: right - left,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HcColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(HcRadii.pill),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.medium);
    final color = selected ? HcColors.accentDark : HcColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: d,
              curve: Motion.emphasized,
              child: AnimatedSwitcher(
                duration: d,
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                child: Icon(selected ? tab.activeIcon : tab.icon, key: ValueKey(selected), size: 23, color: color),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: d,
              curve: Motion.curve,
              style: HcType.sans(size: 10.5, weight: selected ? 600 : 500, color: color, height: 1.1),
              child: Text(tab.label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}
