import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';
import 'motion.dart';

/// Полупрозрачное «стекло» с размытием подложки. Применять точечно:
/// нижняя навигация, карточки новостей, карта лояльности, модалки.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = HcRadii.card,
    this.padding = EdgeInsets.zero,
    this.blur = 18,
    this.fill = HcColors.glassFill,
    this.shadow = true,
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color fill;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    final glass = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? const [BoxShadow(color: Color(0x0F362B22), blurRadius: 28, offset: Offset(0, 10), spreadRadius: -2)]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            // Заливка и лёгкий блик сверху в одном градиенте: у BoxDecoration
            // градиент перекрывает color, поэтому отдельный color здесь не работает.
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: HcColors.glassBorder, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.alphaBlend(Colors.white.withValues(alpha: 0.18), fill), fill],
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
    return onTap == null ? glass : Pressable(onTap: onTap, scale: 0.98, child: glass);
  }
}

/// Обычная (не стеклянная) карточка на песочном фоне — для второстепенных блоков.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(HcSpace.card), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(HcRadii.card),
        border: Border.all(color: HcColors.hairline, width: 0.6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HcRadii.card),
        child: Padding(padding: padding, child: child),
      ),
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.98, child: card);
  }
}
