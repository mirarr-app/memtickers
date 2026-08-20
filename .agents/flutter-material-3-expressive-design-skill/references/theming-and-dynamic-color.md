# Material Design 3 Expressive Theming & Dynamic Color in Flutter

This guide provides complete instructions for configuring `ThemeData`, dynamic color schemes, dark theme mode switching, custom `ThemeExtension` classes, and `m3e_color_scheme` in Flutter.

---

## 1. Core ThemeData & M3 Setup

In Flutter, Material 3 theming is activated by passing `useMaterial3: true` into `ThemeData`:

```dart
import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class AppTheme {
  static ThemeData light(ColorScheme? dynamicColorScheme) {
    final scheme = dynamicColorScheme ?? ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData dark(ColorScheme? dynamicColorScheme) {
    final scheme = dynamicColorScheme ?? ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
```

---

## 2. Dynamic Color Scheme Integration (`dynamic_color`)

Use `DynamicColorBuilder` to fetch user wallpaper palette tokens on Android 12+ (API level 31+):

```dart
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

class ExpressiveDynamicApp extends StatelessWidget {
  const ExpressiveDynamicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Dynamic Expressive Theme',
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
        );
      },
    );
  }
}
```

---

## 3. Custom Brand Tokens via `ThemeExtension`

When your design requires tokens not present in standard `ColorScheme`, extend `ThemeExtension`:

```dart
import 'package:flutter/material.dart';

@immutable
class BrandTokens extends ThemeExtension<BrandTokens> {
  final Color brandAccent;
  final Color brandBackground;
  final double expressiveness;

  const BrandTokens({
    required this.brandAccent,
    required this.brandBackground,
    required this.expressiveness,
  });

  @override
  BrandTokens copyWith({
    Color? brandAccent,
    Color? brandBackground,
    double? expressiveness,
  }) {
    return BrandTokens(
      brandAccent: brandAccent ?? this.brandAccent,
      brandBackground: brandBackground ?? this.brandBackground,
      expressiveness: expressiveness ?? this.expressiveness,
    );
  }

  @override
  BrandTokens lerp(ThemeExtension<BrandTokens>? other, double t) {
    if (other is! BrandTokens) return this;
    return BrandTokens(
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      brandBackground: Color.lerp(brandBackground, other.brandBackground, t)!,
      expressiveness: lerpDouble(expressiveness, other.expressiveness, t)!,
    );
  }
}

// Access in widgets:
// final brand = Theme.of(context).extension<BrandTokens>();
```

---

## 4. Theme Mode Switching

Support system, light, and dark mode toggling cleanly in Flutter:

```dart
class ThemeModeNotifier extends ValueNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void setMode(ThemeMode mode) {
    value = mode;
  }
}

final themeModeNotifier = ThemeModeNotifier();

// Usage in MaterialApp:
// ValueListenableBuilder<ThemeMode>(
//   valueListenable: themeModeNotifier,
//   builder: (context, mode, child) => MaterialApp(themeMode: mode, ...),
// );
```
