import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/net_image.dart';
import 'menu_badge_chip.dart';
import 'menu_item_sheet.dart';
import 'menu_models.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String _sectionSlug = 'kitchen';
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  String? _activeCategoryId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _categoryKeys.putIfAbsent(id, GlobalKey.new);

  void _jumpTo(MenuCategory c) {
    setState(() => _activeCategoryId = c.id);
    final ctx = _categoryKeys[c.id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic, alignment: 0.02);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    return SafeArea(
      bottom: false,
      child: switch (menu) {
        AsyncData(:final value) => _buildMenu(value),
        AsyncError(:final error) => ErrorState(error: error, onRetry: () => ref.invalidate(menuProvider)),
        _ => const Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
      },
    );
  }

  Widget _buildMenu(MenuData data) {
    if (data.sections.isEmpty) {
      return const EmptyState(icon: Icons.restaurant_menu_rounded, title: 'Меню скоро появится');
    }
    final section = data.sections.firstWhere((s) => s.slug == _sectionSlug, orElse: () => data.sections.first);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 110;

    return RefreshIndicator(
      color: HcColors.accent,
      onRefresh: () => ref.refresh(menuProvider.future),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          const SliverToBoxAdapter(child: ScreenTitle('Меню', overline: 'History Coffee')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _SectionSwitch(
                sections: data.sections,
                selected: section.slug,
                onChanged: (slug) => setState(() {
                  _sectionSlug = slug;
                  _activeCategoryId = null;
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                }),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _ChipsHeader(
              categories: section.categories,
              activeId: _activeCategoryId,
              onTap: _jumpTo,
            ),
          ),
          if (section.categories.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.restaurant_menu_rounded,
                title: 'Раздел наполняется',
                subtitle: 'Загляните в кофейню — бариста расскажет, что сегодня в меню',
              ),
            ),
          for (final category in section.categories) ...[
            SliverToBoxAdapter(
              key: _keyFor(category.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                child: Text(category.title, style: HcType.serif(size: 26, weight: 500)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverList.separated(
                itemCount: category.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => MenuItemCard(
                  item: category.items[i],
                  onTap: () => showMenuItemSheet(context, category.items[i]),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              child: Text(
                data.disclaimer,
                textAlign: TextAlign.center,
                style: HcType.sans(size: 12.5, color: HcColors.textSecondary),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
        ],
      ),
    );
  }
}

/// Переключатель «Кухня / Бар» — стеклянная «пилюля».
class _SectionSwitch extends StatelessWidget {
  const _SectionSwitch({required this.sections, required this.selected, required this.onChanged});

  final List<MenuSection> sections;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: HcRadii.pill,
      padding: const EdgeInsets.all(4),
      shadow: false,
      child: Row(
        children: [
          for (final s in sections)
            Expanded(
              child: Semantics(
                selected: s.slug == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(s.slug),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: s.slug == selected ? HcColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(HcRadii.pill),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s.title.toUpperCase(),
                      style: HcType.caps(size: 12.5, color: s.slug == selected ? Colors.white : HcColors.text, weight: 600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChipsHeader extends SliverPersistentHeaderDelegate {
  _ChipsHeader({required this.categories, required this.activeId, required this.onTap});

  final List<MenuCategory> categories;
  final String? activeId;
  final ValueChanged<MenuCategory> onTap;

  static const _height = 64.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: HcColors.background.withValues(alpha: overlapsContent || shrinkOffset > 0 ? 0.94 : 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = categories[i];
          final selected = c.id == activeId;
          return ChoiceChip(
            label: Text(c.title),
            selected: selected,
            onSelected: (_) => onTap(c),
            labelStyle: HcType.sans(size: 14, weight: 500, color: selected ? Colors.white : HcColors.text),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_ChipsHeader old) => old.categories != categories || old.activeId != activeId;
}

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({super.key, required this.item, required this.onTap});

  final MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(HcRadii.small),
              child: SizedBox(width: 92, height: 92, child: NetImage(item.imageUrl)),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: item.imageUrl == null ? 6 : 0, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.badges.isNotEmpty) ...[
                    Wrap(spacing: 6, runSpacing: 6, children: [for (final b in item.badges) MenuBadgeChip(b, dense: true)]),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(item.title, style: HcType.serif(size: 20, weight: 600, height: 1.1))),
                      const SizedBox(width: 10),
                      Text(item.priceLine, style: HcType.sans(size: 15, weight: 500)),
                    ],
                  ),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HcType.sans(size: 13.5, color: HcColors.textSecondary, height: 1.35),
                    ),
                  ],
                  if (item.portion != null) ...[
                    const SizedBox(height: 6),
                    Text(item.portion!, style: HcType.sans(size: 12.5, color: HcColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
