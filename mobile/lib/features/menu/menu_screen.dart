import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/motion.dart';
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
  int _direction = 1;
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  String? _activeCategoryId;
  List<MenuCategory> _visibleCategories = const [];
  bool _jumping = false;

  static const _chipsHeight = 60.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncActiveCategory);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _categoryKeys.putIfAbsent(id, GlobalKey.new);

  /// Подсвечиваем чип категории, которая сейчас под закреплённой строкой чипов.
  void _syncActiveCategory() {
    if (_jumping || _visibleCategories.isEmpty) return;
    final threshold = MediaQuery.paddingOf(context).top + _chipsHeight + 40;
    String? active = _visibleCategories.first.id;
    for (final c in _visibleCategories) {
      final box = _categoryKeys[c.id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy <= threshold) active = c.id;
    }
    if (active != _activeCategoryId) setState(() => _activeCategoryId = active);
  }

  Future<void> _jumpTo(MenuCategory c) async {
    setState(() => _activeCategoryId = c.id);
    final ctx = _categoryKeys[c.id]?.currentContext;
    if (ctx == null) return;
    _jumping = true;
    await Scrollable.ensureVisible(
      ctx,
      duration: Motion.of(context, Motion.slow),
      curve: Motion.emphasized,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      alignment: 0,
    );
    _jumping = false;
  }

  void _selectSection(MenuData data, String slug) {
    if (slug == _sectionSlug) return;
    final from = data.sections.indexWhere((s) => s.slug == _sectionSlug);
    final to = data.sections.indexWhere((s) => s.slug == slug);
    setState(() {
      _direction = to >= from ? 1 : -1;
      _sectionSlug = slug;
      _activeCategoryId = null;
    });
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: Motion.of(context, Motion.medium), curve: Motion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    return SafeArea(
      bottom: false,
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        child: switch (menu) {
          AsyncData(:final value) => _buildMenu(value),
          AsyncError(:final error) => ErrorState(error: error, onRetry: () => ref.invalidate(menuProvider)),
          _ => const _MenuSkeleton(),
        },
      ),
    );
  }

  Widget _buildMenu(MenuData data) {
    if (data.sections.isEmpty) {
      return const EmptyState(icon: Icons.restaurant_menu_rounded, title: 'Меню скоро появится');
    }
    final section = data.sections.firstWhere((s) => s.slug == _sectionSlug, orElse: () => data.sections.first);
    _visibleCategories = section.categories;
    final d = Motion.of(context, Motion.medium);

    return RefreshIndicator(
      color: HcColors.accent,
      onRefresh: () => ref.refresh(menuProvider.future),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          const SliverToBoxAdapter(child: ScreenTitle('Меню')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
              child: SegmentedSwitch(
                labels: [for (final s in data.sections) s.title],
                index: data.sections.indexOf(section),
                onChanged: (i) => _selectSection(data, data.sections[i].slug),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _ChipsHeader(
              height: _chipsHeight,
              sectionKey: section.slug,
              categories: section.categories,
              activeId: _activeCategoryId ?? section.categories.firstOrNull?.id,
              onTap: _jumpTo,
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: d,
              switchInCurve: Motion.curve,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              transitionBuilder: (child, a) => fadeThroughTransition(
                child,
                a,
                direction: child.key == ValueKey(section.slug) ? _direction : -_direction,
              ),
              child: _SectionBody(key: ValueKey(section.slug), section: section, keyFor: _keyFor),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(HcSpace.xxl, HcSpace.xxl, HcSpace.xxl, 0),
              child: Text(
                data.disclaimer,
                textAlign: TextAlign.center,
                style: HcType.sans(size: 12.5, color: HcColors.textSecondary),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: HcSpace.navInset(context))),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({super.key, required this.section, required this.keyFor});

  final MenuSection section;
  final GlobalKey Function(String id) keyFor;

  @override
  Widget build(BuildContext context) {
    if (section.categories.isEmpty) {
      return const EmptyState(
        icon: Icons.restaurant_menu_rounded,
        title: 'Раздел наполняется',
        subtitle: 'Загляните в кофейню — бариста расскажет, что сегодня в меню',
      );
    }
    var n = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in section.categories) ...[
          Padding(
            key: keyFor(category.id),
            padding: const EdgeInsets.fromLTRB(HcSpace.gutter, HcSpace.xl, HcSpace.gutter, HcSpace.m),
            child: Text(category.title, style: HcType.serif(size: 26, weight: 600)),
          ),
          for (final item in category.items)
            Padding(
              padding: const EdgeInsets.fromLTRB(HcSpace.gutter, 0, HcSpace.gutter, HcSpace.listGap),
              child: FadeSlideIn(
                index: n++,
                child: MenuItemCard(item: item, onTap: () => showMenuItemSheet(context, item)),
              ),
            ),
        ],
      ],
    );
  }
}

/// Переключатель на несколько вариантов с одним скользящим «ползунком»:
/// подсветка переезжает под выбранный вариант, цвет текста меняется синхронно.
class SegmentedSwitch extends StatelessWidget {
  const SegmentedSwitch({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.medium);
    return Glass(
      radius: HcRadii.pill,
      padding: const EdgeInsets.all(HcSpace.xs),
      shadow: false,
      child: SizedBox(
        height: 44,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / labels.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: d,
                  curve: Motion.emphasized,
                  left: w * index,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: HcColors.accent,
                      borderRadius: BorderRadius.circular(HcRadii.pill),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (i, label) in labels.indexed)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == index,
                          child: Pressable(
                            haptic: true,
                            scale: 0.96,
                            onTap: () => onChanged(i),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: HcSpace.s),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: AnimatedDefaultTextStyle(
                                  duration: d,
                                  curve: Motion.curve,
                                  style: HcType.sans(
                                    size: 15,
                                    weight: 600,
                                    color: i == index ? Colors.white : HcColors.text,
                                    height: 1.2,
                                  ),
                                  child: Text(label, maxLines: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChipsHeader extends SliverPersistentHeaderDelegate {
  _ChipsHeader({
    required this.height,
    required this.sectionKey,
    required this.categories,
    required this.activeId,
    required this.onTap,
  });

  final double height;
  final String sectionKey;
  final List<MenuCategory> categories;
  final String? activeId;
  final ValueChanged<MenuCategory> onTap;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final stuck = overlapsContent || shrinkOffset > 0;
    return AnimatedContainer(
      height: height,
      duration: Motion.of(context, Motion.fast),
      decoration: BoxDecoration(
        color: HcColors.background.withValues(alpha: stuck ? 0.94 : 0),
        border: Border(bottom: BorderSide(color: stuck ? HcColors.hairline : Colors.transparent, width: 0.6)),
      ),
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        child: _Chips(key: ValueKey(sectionKey), categories: categories, activeId: activeId, onTap: onTap),
      ),
    );
  }

  @override
  bool shouldRebuild(_ChipsHeader old) =>
      old.categories != categories || old.activeId != activeId || old.sectionKey != sectionKey;
}

class _Chips extends StatefulWidget {
  const _Chips({super.key, required this.categories, required this.activeId, required this.onTap});

  final List<MenuCategory> categories;
  final String? activeId;
  final ValueChanged<MenuCategory> onTap;

  @override
  State<_Chips> createState() => _ChipsState();
}

class _ChipsState extends State<_Chips> {
  final _keys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(_Chips old) {
    super.didUpdateWidget(old);
    // Активный чип держим в зоне видимости горизонтального списка.
    if (old.activeId != widget.activeId && widget.activeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.activeId]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: Motion.of(context, Motion.medium),
            curve: Motion.curve,
            alignment: 0.3,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.medium);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter, vertical: HcSpace.m),
      child: Row(
        children: [
          for (final c in widget.categories)
            Padding(
              key: _keys.putIfAbsent(c.id, GlobalKey.new),
              padding: const EdgeInsets.only(right: HcSpace.s),
              child: Pressable(
                haptic: true,
                scale: 0.95,
                onTap: () => widget.onTap(c),
                child: AnimatedContainer(
                  duration: d,
                  curve: Motion.curve,
                  padding: const EdgeInsets.symmetric(horizontal: HcSpace.l, vertical: HcSpace.s),
                  decoration: BoxDecoration(
                    color: c.id == widget.activeId
                        ? HcColors.accent.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(HcRadii.pill),
                    border: Border.all(
                      color: c.id == widget.activeId ? HcColors.accent.withValues(alpha: 0.5) : HcColors.hairline,
                      width: 0.8,
                    ),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: d,
                    style: HcType.sans(
                      size: 14,
                      weight: c.id == widget.activeId ? 600 : 500,
                      color: c.id == widget.activeId ? HcColors.accentDark : HcColors.text,
                      height: 1.2,
                    ),
                    child: Text(c.title),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({super.key, required this.item, required this.onTap});

  final MenuItem item;
  final VoidCallback onTap;

  static const photoSize = 92.0;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(HcSpace.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Место под фото есть всегда — меню выглядит ровно, даже если часть фото ещё не загружена.
          Hero(
            tag: 'menu-photo-${item.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(HcRadii.small),
              child: SizedBox(width: photoSize, height: photoSize, child: NetImage(item.imageUrl)),
            ),
          ),
          const SizedBox(width: HcSpace.l),
          Expanded(
            child: SizedBox(
              height: photoSize,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HcType.serif(size: 20, weight: 600, height: 1.1),
                  ),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: HcSpace.xs),
                    Text(
                      item.description!,
                      maxLines: item.badges.isEmpty ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: HcType.sans(size: 13, color: HcColors.textSecondary, height: 1.35),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: item.badges.isEmpty
                            ? const SizedBox.shrink()
                            : ClipRect(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [for (final b in item.badges.take(2)) MenuBadgeChip(b, dense: true)],
                                ),
                              ),
                      ),
                      if (item.priceLine.isNotEmpty) ...[
                        const SizedBox(width: HcSpace.s),
                        Text(item.priceLine, style: HcType.sans(size: 15, weight: 600)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSkeleton extends StatelessWidget {
  const _MenuSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
      children: [
        const SizedBox(height: 76),
        const SkeletonBox(height: 52, radius: 26),
        const SizedBox(height: HcSpace.xl),
        for (var i = 0; i < 4; i++) ...[
          const Row(
            children: [
              SkeletonBox(height: 92, width: 92, radius: 14),
              SizedBox(width: HcSpace.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [SkeletonBox(height: 18, width: 140), SizedBox(height: 10), SkeletonBox(height: 12)],
                ),
              ),
            ],
          ),
          const SizedBox(height: HcSpace.l),
        ],
      ],
    );
  }
}
