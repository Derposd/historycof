import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'wordmark.dart';

/// Картинка из сети с тёплой заглушкой.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.placeholderMark = true});

  final String? url;
  final BoxFit fit;
  final bool placeholderMark;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: HcColors.backgroundAlt,
      child: placeholderMark
          ? const Center(child: FractionallySizedBox(widthFactor: 0.12, child: FittedBox(child: FeatherMark())))
          : null,
    );
    if (url == null || url!.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

/// Одиночное перо из логотипа — как декоративный знак.
class FeatherMark extends StatelessWidget {
  const FeatherMark({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(20, 30),
        painter: FeatherPainter(color ?? HcColors.textSecondary.withValues(alpha: 0.35)),
      );
}
