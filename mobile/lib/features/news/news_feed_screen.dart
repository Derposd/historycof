import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/net_image.dart';
import '../contacts/contacts_providers.dart';
import '../contacts/venue.dart';
import 'news.dart';

class NewsFeedScreen extends ConsumerStatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  ConsumerState<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends ConsumerState<NewsFeedScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ref.read(newsFeedProvider.notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(newsFeedProvider);

    return RefreshIndicator(
      color: HcColors.accent,
      onRefresh: () => ref.read(newsFeedProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: SafeArea(bottom: false, child: _Header())),
          ...switch (feed) {
            AsyncData(:final value) when value.items.isEmpty => [
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.local_cafe_outlined,
                  title: 'Пока тихо',
                  subtitle: 'Скоро здесь появятся новости кофейни — новые десерты, события и истории',
                ),
              ),
            ],
            AsyncData(:final value) => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
                sliver: SliverList.separated(
                  itemCount: value.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: HcSpace.l),
                  itemBuilder: (context, i) => FadeSlideIn(
                    index: i,
                    child: NewsCard(post: value.items[i], onTap: () => context.push('/news/${value.items[i].id}')),
                  ),
                ),
              ),
              if (value.loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
                  ),
                ),
            ],
            AsyncError(:final error) when !feed.hasValue => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(error: error, onRetry: () => ref.invalidate(newsFeedProvider)),
              ),
            ],
            _ => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
                sliver: SliverList.separated(
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(height: HcSpace.l),
                  itemBuilder: (_, _) => const _NewsCardSkeleton(),
                ),
              ),
            ],
          },
          SliverToBoxAdapter(child: SizedBox(height: HcSpace.navInset(context))),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagline = (ref.watch(venueProvider).value ?? Venue.fallback).tagline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(HcSpace.gutter, HcSpace.l, HcSpace.gutter, HcSpace.xl),
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HcLogo(size: 44, animate: true),
            if (tagline.isNotEmpty) ...[
              const SizedBox(height: HcSpace.xl),
              Text(tagline, style: HcType.serif(size: 30, weight: 500, height: 1.1)),
            ],
            const SizedBox(height: HcSpace.xs),
            Text('Новости и события кофейни', style: HcType.sans(color: HcColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.post, required this.onTap});

  final NewsPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Glass(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Hero(tag: 'news-${post.id}', child: NetImage(post.imageUrl)),
            ),
          Padding(
            padding: const EdgeInsets.all(HcSpace.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SectionLabel(formatNewsDate(post.publishedAt)),
                    if (post.pinned) ...[
                      const SizedBox(width: HcSpace.s),
                      const Icon(Icons.push_pin_outlined, size: 14, color: HcColors.accent),
                    ],
                  ],
                ),
                const SizedBox(height: HcSpace.s),
                Text(post.title, style: HcType.serif(size: 24, weight: 600)),
                const SizedBox(height: HcSpace.s),
                Text(
                  post.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: HcType.sans(size: 14.5, color: HcColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCardSkeleton extends StatelessWidget {
  const _NewsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Glass(
      padding: EdgeInsets.all(HcSpace.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 150),
          SizedBox(height: 16),
          SkeletonBox(height: 12, width: 90),
          SizedBox(height: 12),
          SkeletonBox(height: 22, width: 220),
          SizedBox(height: 10),
          SkeletonBox(height: 12),
        ],
      ),
    );
  }
}
