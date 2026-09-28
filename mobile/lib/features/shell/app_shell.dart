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
  int? _leaving;

  @override
  void didUpdateWidget(_FadeBranches old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _leaving = old.index;
  }

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.medium);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (i, child) in widget.children.indexed)
          IgnorePointer(
            ignoring: i != widget.index,
            child: TickerMode(
              // Уходящей вкладке оставляем анимации, иначе её растворение замрёт на полпути.
              enabled: i == widget.index || i == _leaving,
              child: AnimatedOpacity(
                opacity: i == widget.index ? 1 : 0,
                duration: d,
                curve: Motion.curve,
                onEnd: () {
                  if (i == _leaving && mounted) setState(() => _leaving = null);
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
                  // Одна подсветка, которая переезжает под выбранную вкладку.
                  AnimatedPositioned(
                    duration: Motion.of(context, Motion.medium),
                    curve: Motion.emphasized,
                    left: w * index,
                    width: w,
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HcColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(HcRadii.pill),
                      ),
                    ),
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
