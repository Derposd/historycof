import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/net_image.dart';
import 'news.dart';

class NewsDetailScreen extends ConsumerWidget {
  const NewsDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(newsPostProvider(id));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const Padding(padding: EdgeInsets.all(6), child: _RoundBack()),
      ),
      body: HcBackground(
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium),
          child: switch (post) {
            AsyncData(:final value) => _Body(post: value),
            AsyncError(:final error) => ErrorState(error: error, onRetry: () => ref.invalidate(newsPostProvider(id))),
            _ => const Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
          },
        ),
      ),
    );
  }
}

class _RoundBack extends StatelessWidget {
  const _RoundBack();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.7),
      shape: const CircleBorder(side: BorderSide(color: HcColors.glassBorder)),
      child: IconButton(
        tooltip: 'Назад',
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.post});

  final NewsPost post;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 40),
      children: [
        if (post.imageUrl != null)
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Hero(tag: 'news-${post.id}', child: NetImage(post.imageUrl)),
          )
        else
          SizedBox(height: top + 64),
        Padding(
          padding: const EdgeInsets.fromLTRB(HcSpace.gutter, HcSpace.xl, HcSpace.gutter, 0),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(formatNewsDate(post.publishedAt)),
                const SizedBox(height: HcSpace.s),
                Text(post.title, style: HcType.serif(size: 34, weight: 600)),
                const SizedBox(height: HcSpace.l),
                const Hairline(),
                const SizedBox(height: HcSpace.l),
                SelectableText(post.body, style: HcType.sans(size: 16, height: 1.6, color: HcColors.text)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
