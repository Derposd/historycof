import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/net_image.dart';
import 'menu_models.dart';

/// Бейджи в духе сайта: «NEW» и «Хит продаж» — приглушённое золото,
/// «Выбор команды» — оливковый, «Блюдо с историей» — тонкая обводка с пером.
class MenuBadgeChip extends StatelessWidget {
  const MenuBadgeChip(this.badge, {super.key, this.dense = false});

  final MenuBadge badge;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (badge) {
      MenuBadge.isNew || MenuBadge.bestseller => (HcColors.gold.withValues(alpha: 0.85), HcColors.text, Colors.transparent),
      MenuBadge.teamChoice => (HcColors.accent.withValues(alpha: 0.16), HcColors.accentDark, Colors.transparent),
      MenuBadge.story => (Colors.transparent, HcColors.text, HcColors.text.withValues(alpha: 0.35)),
    };
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
          if (badge == MenuBadge.story) ...[
            FeatherMark(color: HcColors.text.withValues(alpha: 0.8)).sized(dense ? 9 : 11),
            const SizedBox(width: 5),
          ],
          Text(
            badge == MenuBadge.isNew ? badge.label : badge.label.toUpperCase(),
            style: HcType.caps(size: dense ? 9.5 : 10.5, color: fg, weight: 600),
          ),
        ],
      ),
    );
  }
}

extension on FeatherMark {
  Widget sized(double h) => SizedBox(height: h, width: h * 0.66, child: FittedBox(child: this));
}
