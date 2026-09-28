import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';

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
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? const [
                BoxShadow(color: HcColors.glassShadow, blurRadius: 30, offset: Offset(0, 12), spreadRadius: -6),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: borderRadius,
              border: Border.all(color: HcColors.glassBorder, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.0)],
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Обычная (не стеклянная) карточка на песочном фоне — для второстепенных блоков.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HcRadii.card);
    return Material(
      color: Colors.white.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: HcColors.hairline, width: 0.6)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}
