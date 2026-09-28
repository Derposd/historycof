import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import 'menu_models.dart';

/// Бейджи меню: «NEW» и «Хит продаж» — приглушённое золото, «Выбор команды» — олива,
/// «Блюдо с историей» — тонкая обводка с иконкой книги.
class MenuBadgeChip extends StatelessWidget {
  const MenuBadgeChip(this.badge, {super.key, this.dense = false});

  final MenuBadge badge;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (badge) {
      MenuBadge.isNew ||
      MenuBadge.bestseller => (HcColors.gold.withValues(alpha: 0.55), HcColors.text, Colors.transparent),
      MenuBadge.teamChoice => (HcColors.accent.withValues(alpha: 0.16), HcColors.accentDark, Colors.transparent),
      MenuBadge.story => (Colors.transparent, HcColors.text, HcColors.text.withValues(alpha: 0.25)),
    };
    final icon = switch (badge) {
      MenuBadge.story => Icons.menu_book_outlined,
      MenuBadge.teamChoice => Icons.favorite_border_rounded,
      MenuBadge.bestseller => Icons.local_fire_department_outlined,
      MenuBadge.isNew => null,
    };
    final size = dense ? 11.0 : 12.5;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: size + 1, color: fg), const SizedBox(width: 4)],
          Text(
            badge.label,
            style: HcType.sans(size: size, weight: 600, color: fg, height: 1.2),
          ),
        ],
      ),
    );
  }
}
