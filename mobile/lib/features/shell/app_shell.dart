import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/glass.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _tabs = [
  _Tab('Главная', Icons.auto_stories_outlined, Icons.auto_stories),
  _Tab('Меню', Icons.restaurant_menu_outlined, Icons.restaurant_menu),
  _Tab('Бонусы', Icons.qr_code_2_rounded, Icons.qr_code_2_rounded),
  _Tab('Контакты', Icons.place_outlined, Icons.place),
  _Tab('Профиль', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Каркас с плавающей стеклянной нижней навигацией.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: HcBackground(intensity: shell.currentIndex == 2 ? 0.9 : 0.5, child: shell),
      bottomNavigationBar: _GlassNavBar(
        index: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
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
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom : 14),
      child: Glass(
        radius: HcRadii.pill,
        blur: 22,
        fill: const Color(0xB3FFFFFF),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            for (final (i, tab) in _tabs.indexed)
              Expanded(child: _NavItem(tab: tab, selected: i == index, onTap: () => onTap(i))),
          ],
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
    final color = selected ? HcColors.accentDark : HcColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? HcColors.accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(HcRadii.pill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? tab.activeIcon : tab.icon, size: 23, color: color),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: HcType.sans(size: 10.5, weight: selected ? 600 : 500, color: color, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
