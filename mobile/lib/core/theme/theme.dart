import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';
import 'typography.dart';

/// Сетка отступов: всё кратно 4, базовый шаг — 8.
/// [gutter] — единое боковое поле всех экранов: по нему выровнены заголовки,
/// подписи разделов и края карточек.
abstract final class HcSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const gutter = 20.0;

  /// Внутренний отступ карточек.
  static const card = 20.0;

  /// Между карточками в списке.
  static const listGap = 12.0;

  /// Между смысловыми блоками экрана.
  static const section = 28.0;

  /// Запас снизу под плавающую навигацию.
  static double navInset(BuildContext context) => MediaQuery.paddingOf(context).bottom + 104;
}

abstract final class HcRadii {
  static const card = 20.0;
  static const small = 14.0;
  static const pill = 999.0;
}

ThemeData buildHcTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: HcColors.accent,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE6EADB),
    onPrimaryContainer: HcColors.accentDark,
    secondary: HcColors.gold,
    onSecondary: HcColors.text,
    tertiary: HcColors.terracotta,
    onTertiary: Colors.white,
    error: HcColors.terracotta,
    onError: Colors.white,
    surface: HcColors.background,
    onSurface: HcColors.text,
    onSurfaceVariant: HcColors.textSecondary,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFDFAF4),
    surfaceContainer: HcColors.backgroundAlt,
    surfaceContainerHigh: Color(0xFFF0E7D6),
    outline: Color(0x40362B22),
    outlineVariant: HcColors.hairline,
    shadow: HcColors.glassShadow,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: HcColors.background,
    fontFamily: HcType.sansFamily,
    // Мягкая «волна» вместо искрящегося эффекта — спокойнее и дешевле по производительности.
    splashFactory: InkRipple.splashFactory,
    splashColor: HcColors.accent.withValues(alpha: 0.10),
    highlightColor: Colors.transparent,
  );

  final textTheme = base.textTheme.copyWith(
    displayLarge: HcType.serif(size: 44, weight: 400),
    displayMedium: HcType.serif(size: 38, weight: 400),
    displaySmall: HcType.serif(size: 32, weight: 500),
    headlineLarge: HcType.serif(size: 30, weight: 500),
    headlineMedium: HcType.serif(size: 26, weight: 500),
    headlineSmall: HcType.serif(size: 22, weight: 600),
    titleLarge: HcType.serif(size: 21, weight: 600),
    titleMedium: HcType.sans(size: 16, weight: 500),
    titleSmall: HcType.sans(size: 14, weight: 500),
    bodyLarge: HcType.sans(size: 16),
    bodyMedium: HcType.sans(size: 14.5),
    bodySmall: HcType.sans(size: 12.5, color: HcColors.textSecondary),
    labelLarge: HcType.sans(size: 15, weight: 500, letterSpacing: 0.2),
    labelMedium: HcType.caps(size: 12),
    labelSmall: HcType.caps(size: 10.5),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: HcColors.text,
      titleTextStyle: HcType.serif(size: 22, weight: 600),
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    ),
    dividerTheme: const DividerThemeData(color: HcColors.hairline, thickness: 0.6, space: 0.6),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        textStyle: WidgetStatePropertyAll(HcType.sans(size: 15, weight: 500, letterSpacing: 0.3)),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return HcColors.accent.withValues(alpha: 0.35);
          if (s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered)) return HcColors.accentDark;
          return HcColors.accent;
        }),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        foregroundColor: HcColors.text,
        side: const BorderSide(color: Color(0x40362B22), width: 0.8),
        textStyle: HcType.sans(size: 15, weight: 500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: HcColors.accentDark, textStyle: HcType.sans(size: 15, weight: 500)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: HcType.sans(color: HcColors.textSecondary.withValues(alpha: 0.7)),
      labelStyle: HcType.sans(color: HcColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HcRadii.small),
        borderSide: const BorderSide(color: HcColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HcRadii.small),
        borderSide: const BorderSide(color: HcColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HcRadii.small),
        borderSide: const BorderSide(color: HcColors.accent, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HcRadii.small),
        borderSide: const BorderSide(color: HcColors.terracotta),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.55),
      selectedColor: HcColors.accent,
      side: const BorderSide(color: HcColors.hairline),
      shape: const StadiumBorder(),
      labelStyle: HcType.sans(size: 14, weight: 500),
      secondaryLabelStyle: HcType.sans(size: 14, weight: 500, color: Colors.white),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? HcColors.accent : HcColors.backgroundAlt,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(HcColors.hairline),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? HcColors.accent : Colors.transparent,
      ),
      side: const BorderSide(color: HcColors.textSecondary, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HcColors.text,
      contentTextStyle: HcType.sans(color: HcColors.background),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HcRadii.small)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0),
    dialogTheme: DialogThemeData(
      backgroundColor: HcColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HcRadii.card)),
      titleTextStyle: HcType.serif(size: 24, weight: 600),
      contentTextStyle: HcType.sans(color: HcColors.textSecondary),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: HcColors.accent),
  );
}
