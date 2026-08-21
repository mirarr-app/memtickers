import 'package:flutter/material.dart';

import 'spacing.dart';

/// Warm paper / vibrant coral seed used when dynamic color is unavailable.
const Color kMemtickersSeed = Color(0xFFE05338);

ThemeData memtickersTheme(ColorScheme scheme) {
  final textTheme = _buildExpressiveTextTheme(scheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MdSpacing.radiusLg),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MdSpacing.radiusXlIncreased),
        ),
      ),
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
      dragHandleSize: const Size(36, 4),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MdSpacing.radiusXl),
      ),
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
      labelStyle: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs, vertical: 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        highlightColor: scheme.primary.withValues(alpha: 0.12),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
      ),
    ),
    dividerColor: scheme.outlineVariant.withValues(alpha: 0.5),
    splashFactory: InkRipple.splashFactory,
  );
}

TextTheme _buildExpressiveTextTheme(ColorScheme scheme) {
  return TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      height: 64 / 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: scheme.onSurface,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      height: 52 / 45,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: scheme.onSurface,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      height: 44 / 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: scheme.onSurface,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      height: 40 / 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: scheme.onSurface,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
      color: scheme.onSurface,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: scheme.onSurface,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: scheme.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: scheme.onSurface,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: scheme.onSurface,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: scheme.onSurface,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: scheme.onSurface,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: scheme.onSurface,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: scheme.onSurface,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 16 / 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: scheme.onSurfaceVariant,
    ),
  );
}

ColorScheme fallbackScheme(Brightness brightness) {
  return ColorScheme.fromSeed(
    seedColor: kMemtickersSeed,
    brightness: brightness,
  );
}

