# Material Design 3 Expressive Typography, Shape & Motion in Flutter

This reference guide details typography scales, shape tokens, `flutter_m3shapes_extended`, shape morphing animations, spring motion physics (`motor`), and tactile haptics (`m3e_haptics`).

---

## 1. Typography Scales (`TextTheme`)

Material 3 defines 5 type scales with 3 size variants each (15 total roles), available in Flutter via `Theme.of(context).textTheme`:

| Scale | Role | Size | Line Height | Usage |
|-------|------|------|-------------|-------|
| **Display** | `displayLarge` | 57sp | 64sp | Hero text, large numbers, cover headers |
| | `displayMedium` | 45sp | 52sp | Section hero headers |
| | `displaySmall` | 36sp | 44sp | Prominent headlines |
| **Headline** | `headlineLarge` | 32sp | 40sp | Page titles, primary section headers |
| | `headlineMedium` | 28sp | 36sp | Card group headers |
| | `headlineSmall` | 24sp | 32sp | Sub-section headers |
| **Title** | `titleLarge` | 22sp | 28sp | App bar titles, modal titles |
| | `titleMedium` | 16sp | 24sp | Card titles, list tile primary text |
| | `titleSmall` | 14sp | 20sp | Sub-titles, dense list headers |
| **Body** | `bodyLarge` | 16sp | 24sp | Primary paragraph body text |
| | `bodyMedium` | 14sp | 20sp | Secondary body text, card content |
| | `bodySmall` | 12sp | 16sp | Captions, helper text |
| **Label** | `labelLarge` | 14sp | 20sp | Button text, chip labels, tabs |
| | `labelMedium` | 12sp | 16sp | Badges, small buttons |
| | `labelSmall` | 11sp | 16sp | Overline labels, timestamps |

---

## 2. Corner Shape Tokens in Flutter

Material 3 uses rounded corners by default. In Flutter, shape tokens are defined as `BorderRadius` or `ShapeBorder`:

| Token Name | DP Value | Flutter Code Representation | Typical Usage |
|------------|----------|-----------------------------|---------------|
| `none` | 0dp | `BorderRadius.zero` | Flat full-bleed containers |
| `extraSmall` | 4dp | `BorderRadius.circular(4)` | Chips, tooltips, snackbars |
| `small` | 8dp | `BorderRadius.circular(8)` | Text fields, menus, dropdowns |
| `medium` | 12dp | `BorderRadius.circular(12)` | Cards, small dialogs |
| `large` | 16dp | `BorderRadius.circular(16)` | Navigation drawers, FABs, card lists |
| `largeIncreased` | 20dp | `BorderRadius.circular(20)` | M3 Expressive card lists |
| `extraLarge` | 28dp | `BorderRadius.circular(28)` | Dialogs, bottom sheets |
| `extraLargeIncreased` | 32dp | `BorderRadius.circular(32)` | Large expressive sheets |
| `full` | 9999dp | `BorderRadius.circular(9999)` / `StadiumBorder()` | Buttons, pills, search bars |

---

## 3. Extended Expressive Shapes (`flutter_m3shapes_extended`)

The `flutter_m3shapes_extended` package provides the full suite of Material 3 Expressive geometric shapes for custom clips, cards, buttons, and avatars:

### Available Extended Shapes
- `GemShape`: Faceted diamond/gem geometry.
- `SlantedShape`: Parallel parallelogram / slanted polygon.
- `FlowerShape`: Multi-petal scalloped border shape.
- `ArchShape`: Arched top with flat bottom.
- `CookieShape`: Scalloped circular cookie outline.
- `StarburstShape`: Multi-pointed star shape for badges / callouts.

### Code Example: Clipping & Shape Borders

```dart
import 'package:flutter/material.dart';
import 'package:flutter_m3shapes_extended/flutter_m3shapes_extended.dart';

Widget buildExpressiveShapeCard(BuildContext context) {
  return ClipPath(
    clipper: ShapeBorderClipper(shape: GemShape()),
    child: Container(
      width: 120,
      height: 120,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.auto_awesome,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        size: 40,
      ),
    ),
  );
}
```

---

## 4. Spring Motion Physics (`motor`) & Tactile Haptics (`m3e_haptics`)

M3 Expressive motion relies on physics-based spring models (`motor`) instead of fixed cubic-bezier curves.

### 1. Spring Physics Configuration
- **Stiffness**: Higher values increase snap speed; lower values create fluid, soft motion.
- **Damping Ratio**: Controls oscillation rebound.
  - Overdamped (>1.0): Smooth, non-bouncing transition.
  - Critically Damped (=1.0): Fast snap without bounce.
  - Underdamped (<1.0): Natural spring overshoot bounce.

### 2. Expressive Haptic Feedback Engine (`m3e_haptics`)

The `m3e_haptics` package provides tactile feedback synchronized with spring press and drag gestures:

```dart
import 'package:m3e_haptics/m3e_haptics.dart';

// Trigger expressive haptic feedback patterns
void triggerHaptics() {
  M3EHapticFeedback.selection(); // Subtle tick on selection
  M3EHapticFeedback.medium();    // Button tap squish
  M3EHapticFeedback.heavy();     // Dismiss / drag snap
}
```
