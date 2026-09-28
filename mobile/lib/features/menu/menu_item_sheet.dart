import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/net_image.dart';
import 'menu_badge_chip.dart';
import 'menu_models.dart';

Future<void> showMenuItemSheet(BuildContext context, MenuItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: HcColors.text.withValues(alpha: 0.25),
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
      initialChildSize: item.imageUrl != null ? 0.82 : 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Glass(
        radius: 28,
        fill: HcColors.glassFillStrong,
        blur: 24,
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: HcColors.hairline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            if (item.imageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(HcRadii.card),
                  child: AspectRatio(aspectRatio: 1, child: NetImage(item.imageUrl)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.badges.isNotEmpty) ...[
                    Wrap(spacing: 8, runSpacing: 8, children: [for (final b in item.badges) MenuBadgeChip(b)]),
                    const SizedBox(height: 14),
                  ],
                  Text(item.title, style: HcType.serif(size: 32, weight: 500)),
                  if (item.portion != null) ...[
                    const SizedBox(height: 4),
                    Text(item.portion!, style: HcType.sans(color: HcColors.textSecondary)),
                  ],
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const CapsLabel('Состав'),
                    const SizedBox(height: 6),
                    Text(item.description!, style: HcType.sans(size: 15.5, height: 1.55)),
                  ],
                  if (item.prices.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Hairline(),
                    const SizedBox(height: 14),
                    _Prices(prices: item.prices),
                  ],
                  if (item.story != null && item.story!.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _Story(text: item.story!),
                  ],
                ],
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
          if (i > 0) Container(width: 0.6, height: 36, color: HcColors.hairline, margin: const EdgeInsets.symmetric(horizontal: 18)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.label.isNotEmpty) CapsLabel(p.label),
              if (p.label.isNotEmpty) const SizedBox(height: 4),
              Text(formatRub(p.amount), style: HcType.serif(size: 26, weight: 600)),
            ],
          ),
        ],
      ],
    );
  }
}

/// «Блюдо с историей» — лёгкая легенда с крупной декоративной кавычкой.
class _Story extends StatelessWidget {
  const _Story({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: HcColors.backgroundAlt.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(HcRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuoteMark(size: 56),
          const CapsLabel('Блюдо с историей'),
          const SizedBox(height: 8),
          Text(text, style: HcType.serif(size: 19, weight: 400, italic: true, height: 1.35)),
        ],
      ),
    );
  }
}
