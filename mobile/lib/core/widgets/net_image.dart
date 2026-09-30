import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'logo.dart';

/// Картинка блюда или новости: из сети, из ассетов (`asset:` — демо) или
/// аккуратная заглушка с монограммой, если фото ещё не загрузили.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.placeholderMark = true});

  final String? url;
  final BoxFit fit;
  final bool placeholderMark;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7F1E5), HcColors.backgroundAlt],
        ),
      ),
      child: placeholderMark
          ? Center(
              child: LayoutBuilder(
                builder: (_, c) => Opacity(
                  opacity: 0.35,
                  child: HcMonogram(
                    size: (c.biggest.shortestSide * 0.32).clamp(20, 64),
                    color: HcColors.textSecondary,
                    fill: const Color(0x00000000),
                  ),
                ),
              ),
            )
          : null,
    );
    final u = url;
    if (u == null || u.isEmpty) return SizedBox.expand(child: placeholder);
    if (u.startsWith('asset:')) {
      return Image.asset(u.substring(6), fit: fit, width: double.infinity, height: double.infinity);
    }
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 320),
      fadeInCurve: Curves.easeOutCubic,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
