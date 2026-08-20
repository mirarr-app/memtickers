# Material Design 3 Expressive Color System in Flutter

This guide details the Material 3 Expressive (M3E) color system in Flutter, including `ColorScheme` semantic roles, surface containers, dynamic color harmonization, and `m3e_color_scheme` utilities.

---

## 1. Color Scheme Semantic Roles

In Flutter, Material Design 3 organizes colors into semantic roles inside `ColorScheme`. Components consume these roles so themes can change dynamically without component code modification.

### Primary Roles
- `primary`: Used for high-emphasis elements such as filled buttons, active states, and prominent icons.
- `onPrimary`: Text and icons placed on top of `primary`.
- `primaryContainer`: Standout fill for key elements (e.g., FABs, active chips, prominent cards).
- `onPrimaryContainer`: Text and icons placed on top of `primaryContainer`.

### Secondary & Tertiary Roles
- `secondary` / `onSecondary`: Used for less prominent accents, filter chips, and secondary buttons.
- `secondaryContainer` / `onSecondaryContainer`: Recessive fills for selected items or tonal buttons.
- `tertiary` / `onTertiary`: Used for contrasting accents, badges, or callouts.
- `tertiaryContainer` / `onTertiaryContainer`: Fills for complementary containers and highlight cards.

### Surface Container Hierarchy
MD3 replaces elevation shadows with surface container color tones. Flutter 3.19+ and M3 Expressive define a 5-level surface container hierarchy:

| Surface Container Role | Flutter API | Relative Tint / Luminance | Primary Use Cases |
|------------------------|-------------|---------------------------|-------------------|
| **Surface Dim** | `colorScheme.surfaceDim` | Slightly darker background tint | Darkened background states |
| **Surface** | `colorScheme.surface` | Baseline surface background | Default page background |
| **Surface Bright** | `colorScheme.surfaceBright` | Slightly brighter surface | Highlighted surface areas |
| **Surface Container Lowest** | `colorScheme.surfaceContainerLowest` | Lowest emphasis container fill | Inner nested cards, white/darkest background cards |
| **Surface Container Low** | `colorScheme.surfaceContainerLow` | Low emphasis container fill | Content cards on surface |
| **Surface Container** | `colorScheme.surfaceContainer` | Default container fill | Navigation bars, list items, search bars |
| **Surface Container High** | `colorScheme.surfaceContainerHigh` | High emphasis container fill | Dialogs, elevated cards, dropdown menus |
| **Surface Container Highest** | `colorScheme.surfaceContainerHighest` | Highest emphasis container fill | Top app bars, bottom sheets, toolbars |

---

## 2. Dynamic Color & `m3e_color_scheme` Integration

M3 Expressive color schemes can be generated dynamically from user wallpaper (Android 12+ Monet engine), seed colors, or brand assets.

### Using `ColorScheme.fromSeed` (Standard Flutter)

```dart
final ColorScheme lightScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF6750A4),
  brightness: Brightness.light,
);

final ColorScheme darkScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF6750A4),
  brightness: Brightness.dark,
);
```

### Using `dynamic_color` Package (Android 12+ Wallpaper Integration)

```dart
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

Widget buildDynamicThemeApp() {
  return DynamicColorBuilder(
    builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      final ColorScheme lightColorScheme = lightDynamic ?? ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
      );

      final ColorScheme darkColorScheme = darkDynamic ?? ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      );

      return MaterialApp(
        theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
        darkTheme: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),
      );
    },
  );
}
```

### Using `m3e_color_scheme` (Expressive AOSP-Aligned Color System)

The `m3e_color_scheme` package provides Expressive color scheme generators with fine-tuned fidelity, custom contrast levels, and seed palette adjustments:

```dart
import 'package:m3e_color_scheme/m3e_color_scheme.dart';

// Generate M3 Expressive color scheme with custom contrast and mood
final expressiveScheme = M3EColorScheme.fromSeed(
  seedColor: const Color(0xFF0061A4),
  brightness: Brightness.light,
  // Expressive color options
);
```

---

## 3. Tonal Pairing Rules

To ensure proper WCAG accessibility and visual harmony, always follow tonal pairing rules:

| Fill Color Role | Mandatory Foreground Role (`on-`) | Incorrect Pairing (Anti-Pattern) |
|-----------------|----------------------------------|----------------------------------|
| `primary` | `onPrimary` | `onSurface` or raw black/white |
| `primaryContainer` | `onPrimaryContainer` | `primary` or `onPrimary` |
| `secondary` | `onSecondary` | `onSurface` |
| `secondaryContainer` | `onSecondaryContainer` | `secondary` |
| `surfaceContainer` | `onSurface` / `onSurfaceVariant` | `onPrimary` |
| `error` | `onError` | `onSurface` |
| `errorContainer` | `onErrorContainer` | `error` |

---

## 4. Code Example: Theme Color Usage in Custom Widgets

```dart
class ExpressiveStatusCard extends StatelessWidget {
  final String title;
  final String status;

  const ExpressiveStatusCard({
    super.key,
    required this.title,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```
