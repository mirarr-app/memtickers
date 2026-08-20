import 'package:flutter/material.dart';

import 'spacing.dart';

/// Warm paper / coral seed used when dynamic color is unavailable.
const Color kMemtickersSeed = Color(0xFFC45C3E);

ThemeData memtickersTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MdSpacing.sm),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MdSpacing.xxs),
      ),
    ),
    dividerColor: scheme.outlineVariant,
    splashFactory: InkRipple.splashFactory,
  );
}

ColorScheme fallbackScheme(Brightness brightness) {
  return ColorScheme.fromSeed(
    seedColor: kMemtickersSeed,
    brightness: brightness,
  );
}
