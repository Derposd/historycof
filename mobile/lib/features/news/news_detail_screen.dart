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

class _Body extends StatefulWidget {
  const _Body({required this.post});

  final NewsPost post;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 40),
      children: [
        if (post.imageUrl != null)
          AspectRatio(
            aspectRatio: 4 / 3,
            child: _ParallaxImage(post: post, scroll: _scroll),
          )
        else
          SizedBox(height: top + 64),
        Padding(
          padding: const EdgeInsets.fromLTRB(HcSpace.gutter, HcSpace.xl, HcSpace.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(formatNewsDate(post.publishedAt)),
                    const SizedBox(height: HcSpace.s),
                    Text(post.title, style: HcType.serif(size: 34, weight: 600)),
                  ],
                ),
              ),
              const SizedBox(height: HcSpace.l),
              const _DrawnHairline(),
              const SizedBox(height: HcSpace.l),
              FadeSlideIn(
                index: 3,
                child: SelectableText(post.body, style: HcType.sans(size: 16, height: 1.6, color: HcColors.text)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Фото новости с параллаксом: при прокрутке уходит медленнее текста,
/// при оттягивании вниз мягко растягивается; низ растворяется в фоне.
class _ParallaxImage extends StatelessWidget {
  const _ParallaxImage({required this.post, required this.scroll});

  final NewsPost post;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    // Обрезаем только снизу: вверх фото может растянуться при оттягивании.
    return ClipRect(
      clipper: const _OpenTopClip(),
      child: AnimatedBuilder(
        animation: scroll,
        builder: (context, child) {
          final off = scroll.hasClients ? scroll.offset : 0.0;
          if (reduced) return child!;
          return Transform.translate(
            offset: Offset(0, off > 0 ? off * 0.45 : 0),
            child: Transform.scale(
              scale: off < 0 ? 1 + (-off / 320) : 1,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(tag: 'news-${post.id}', child: NetImage(post.imageUrl)),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00FBF7EF), Color(0x00FBF7EF), Color(0xCCFBF7EF)],
                    stops: [0, 0.62, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenTopClip extends CustomClipper<Rect> {
  const _OpenTopClip();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, -size.height * 4, size.width, size.height);

  @override
  bool shouldReclip(_OpenTopClip old) => false;
}

/// Разделитель, который «прочерчивается» слева направо.
class _DrawnHairline extends StatelessWidget {
  const _DrawnHairline();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 900)),
      curve: const Interval(0.25, 1, curve: Curves.easeInOutCubic),
      builder: (context, t, child) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(widthFactor: t, child: child),
      ),
      child: const Hairline(),
    );
  }
}
