import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/net_image.dart';
import 'menu_badge_chip.dart';
import 'menu_models.dart';

Future<void> showMenuItemSheet(BuildContext context, MenuItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: HcColors.text.withValues(alpha: 0.28),
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.of(context, Motion.slow),
      reverseDuration: Motion.of(context, Motion.medium),
      curve: Motion.emphasized,
    ),
    builder: (_) => MenuItemSheet(item: item),
  );
}

class MenuItemSheet extends StatelessWidget {
  const MenuItemSheet({super.key, required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      builder: (context, scroll) => Glass(
        radius: 28,
        fill: HcColors.glassFillStrong,
        blur: 24,
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + HcSpace.xl),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: HcSpace.m),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: HcColors.hairline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
              child: Hero(
                tag: 'menu-photo-${item.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(HcRadii.card),
                  child: AspectRatio(aspectRatio: 4 / 3, child: NetImage(item.imageUrl)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(HcSpace.gutter, HcSpace.xl, HcSpace.gutter, 0),
              child: FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.badges.isNotEmpty) ...[
                      Wrap(
                        spacing: HcSpace.s,
                        runSpacing: HcSpace.s,
                        children: [for (final b in item.badges) MenuBadgeChip(b)],
                      ),
                      const SizedBox(height: HcSpace.l),
                    ],
                    Text(item.title, style: HcType.serif(size: 32, weight: 600)),
                    if (item.portion != null) ...[
                      const SizedBox(height: HcSpace.xs),
                      Text(item.portion!, style: HcType.sans(color: HcColors.textSecondary)),
                    ],
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: HcSpace.l),
                      const SectionLabel('Состав'),
                      const SizedBox(height: HcSpace.xs),
                      Text(item.description!, style: HcType.sans(size: 15.5, height: 1.55)),
                    ],
                    if (item.nutrition != null) ...[
                      const SizedBox(height: HcSpace.l),
                      const SectionLabel('Пищевая ценность на порцию'),
                      const SizedBox(height: HcSpace.s),
                      _Nutrition(item.nutrition!),
                    ],
                    if (item.allergens != null && item.allergens!.isNotEmpty) ...[
                      const SizedBox(height: HcSpace.l),
                      const SectionLabel('Аллергены'),
                      const SizedBox(height: HcSpace.xs),
                      Text(item.allergens!, style: HcType.sans(size: 15.5, height: 1.5)),
                    ],
                    if (item.prices.isNotEmpty) ...[
                      const SizedBox(height: HcSpace.xl),
                      const Hairline(),
                      const SizedBox(height: HcSpace.l),
                      _Prices(prices: item.prices),
                    ],
                    if (item.story != null && item.story!.isNotEmpty) ...[
                      const SizedBox(height: HcSpace.xl),
                      AccentNote(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionLabel('Блюдо с историей', color: HcColors.accentDark),
                            const SizedBox(height: HcSpace.xs),
                            Text(item.story!, style: HcType.serif(size: 19, weight: 400, italic: true, height: 1.35)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Prices extends StatelessWidget {
  const _Prices({required this.prices});

  final List<MenuPrice> prices;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, p) in prices.indexed) ...[
          if (i > 0)
            Container(
              width: 0.6,
              height: 40,
              color: HcColors.hairline,
              margin: const EdgeInsets.symmetric(horizontal: HcSpace.l),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.label.isNotEmpty) ...[SectionLabel(p.label), const SizedBox(height: 2)],
              Text(formatRub(p.amount), style: HcType.serif(size: 26, weight: 600)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Калорийность и БЖУ в четыре ровные колонки.
class _Nutrition extends StatelessWidget {
  const _Nutrition(this.n);

  final MenuNutrition n;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final cells = [
      if (n.kcal != null) ('ккал', n.kcal!),
      if (n.proteins != null) ('белки, г', n.proteins!),
      if (n.fats != null) ('жиры, г', n.fats!),
      if (n.carbs != null) ('углеводы, г', n.carbs!),
    ];
    return Row(
      children: [
        for (final (label, v) in cells)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmt(v), style: HcType.serif(size: 24, weight: 600, tabular: true)),
                Text(label, style: HcType.sans(size: 12.5, color: HcColors.textSecondary)),
              ],
            ),
          ),
      ],
    );
  }
}
