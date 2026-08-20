---
name: flutter-material-3-expressive-design-skill
description: >
  Implement Google's Material Design 3 Expressive (M3E) UI system in Flutter using the m3e_core package ecosystem.
  Covers dynamic color, expressive shapes, spring motion physics, card lists, dismissible cards, expandable card lists,
  expressive buttons, floating toolbars, sliders, dropdown menus, haptics, progress/loading indicators, responsive layouts,
  and audit checklists. Use when: "flutter material 3", "flutter m3e", "m3e_core", "expressive flutter", "flutter dynamic color",
  "m3e_buttons", "m3e_card_list", "m3e_dismissible", "m3e_expandable", "flutter_m3shapes_extended".
user-invokable: true
argument-hint: "[component|theme|layout|scaffold|audit] [description or package name]"
---

# Material Design 3 Expressive (M3E) for Flutter

This skill guides implementation of Google's **Material Design 3 Expressive (M3E)** UI system in **Flutter**. Because Flutter does not yet officially support M3 Expressive features in the core framework, this skill leverages the **`m3e_core`** package ecosystem on [pub.dev](https://pub.dev/packages/m3e_core), which provides complete parity for M3 Expressive design tokens, spring physics, dynamic radii, shape morphing, neighbor squish, floating toolbars, and tactile haptics.

---

## Philosophy

Material Design 3 Expressive builds upon core MD3 principles:
- **Personal**: Dynamic color scheme generation adapting to user wallpaper, brand seeds, or custom color palettes.
- **Adaptive**: Layouts transform fluidly across 5 window size classes (Compact, Medium, Expanded, Large, Extra Large).
- **Expressive**: Spring-driven motion physics (`motor`), shape morphing, dynamic corner radii (neighbor pull/squish), and tactile haptics (`m3e_haptics`) create moments of delight while preserving high usability.

---

## Ecosystem & Package Bundle (`m3e_core`)

The **`m3e_core`** package serves as the primary umbrella entry point for M3 Expressive in Flutter. It bundles 12 specialized packages:

| Package | Purpose & Key Features |
|---------|------------------------|
| **`m3e_card_list`** | Expressive card lists with dynamic corner radii recalculation (`M3ECardList`, `SliverM3ECardList`, `M3ECardColumn`). |
| **`m3e_dismissible`** | Swipe-to-dismiss items featuring spring-driven "neighbour pull" physics (`M3EDismissible`). |
| **`m3e_expandable`** | Spring-animated expandable card lists supporting auto-collapse and multi-expansion (`M3EExpandable`). |
| **`m3e_dropdown_menu`** | Fluid dropdown menu supporting single/multi-selection, fuzzy search, async loading, and chip tags (`M3EDropdownMenu`). |
| **`m3e_buttons`** | Expressive button system with neighbor squish, 5 sizes (XS–XL), and shape morphing (`M3EButton`, `M3EToggleButton`, `M3ESplitButton`). |
| **`flutter_m3shapes_extended`** | Complete suite of Material 3 Expressive shapes (Gem, Slanted, Flower, Arch, Cookie, Starburst, etc.). |
| **`m3e_floating_toolbar`** | Material 3 Expressive `FloatingToolbar` family with horizontal/vertical layouts and scroll-to-exit behaviors. |
| **`m3e_slider`** | Material 3 Expressive `M3ESlider` and `M3ERangeSlider` with docking physics, spring motion, and shape tracks. |
| **`m3e_color_scheme`** | AOSP-aligned dynamic color scheme utilities following M3 Expressive specifications (`M3EColorScheme`). |
| **`m3e_haptics`** | Tactile feedback engine synchronized with spring velocity and press patterns (`M3EHapticFeedback`). |
| **`m3e_progress_indicator`** | Material 3 Expressive circular and linear progress indicators with morphing/wavy patterns (`M3EProgressIndicator`). |
| **`m3e_loading_indicator`** | Expressive loading indicator with fluid shape morphing animations (`M3ELoadingIndicator`). |

---

## Decision Tree

**What are you building in Flutter?**
```
Full app scaffold        → See "Common Patterns: App Shell" + references/layout-and-responsive.md
Expressive buttons       → M3EButton / M3EToggleButton / M3ESplitButton (m3e_buttons) → references/component-catalog.md
Interactive card list    → M3ECardList / SliverM3ECardList (m3e_card_list) → references/component-catalog.md
Swipe-to-dismiss list    → M3EDismissible (m3e_dismissible) → references/component-catalog.md
Expandable card section  → M3EExpandable (m3e_expandable) → references/component-catalog.md
Floating navigation dock → M3EFloatingToolbar (m3e_floating_toolbar) → references/navigation-patterns.md
Expressive sliders       → M3ESlider / M3ERangeSlider (m3e_slider) → references/component-catalog.md
Dynamic / custom theme   → ThemeData + ColorScheme.fromSeed() + m3e_color_scheme → references/theming-and-dynamic-color.md
Audit MD3 compliance     → See "MD3 Compliance Audit" section below
```

---

## Setup & Dependency Configuration

Add `m3e_core` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  m3e_core: ^0.1.5
  dynamic_color: ^1.7.0 # Optional for Android 12+ wallpaper dynamic color
```

Import in your Dart code:

```dart
import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
```

---

## Design Token System in Flutter

### 1. Color Tokens (`ColorScheme`)
Flutter maps Material 3 color roles directly to `ColorScheme`. Use `ColorScheme.fromSeed` or `M3EColorScheme` utilities:

| Token Role | Flutter Access | Purpose |
|------------|----------------|---------|
| Primary | `Theme.of(context).colorScheme.primary` | High-emphasis fills, primary buttons |
| On Primary | `Theme.of(context).colorScheme.onPrimary` | Text/icons on primary fill |
| Primary Container | `Theme.of(context).colorScheme.primaryContainer` | Standout container fills (FAB, active chips) |
| Surface | `Theme.of(context).colorScheme.surface` | Background for app screens |
| Surface Container Lowest | `Theme.of(context).colorScheme.surfaceContainerLowest` | Lowest emphasis card background |
| Surface Container Low | `Theme.of(context).colorScheme.surfaceContainerLow` | Low emphasis card fill |
| Surface Container | `Theme.of(context).colorScheme.surfaceContainer` | Default card / navigation fill |
| Surface Container High | `Theme.of(context).colorScheme.surfaceContainerHigh` | Elevated card / modal background |
| Surface Container Highest | `Theme.of(context).colorScheme.surfaceContainerHighest` | Top app bar / dialog fill |
| Outline | `Theme.of(context).colorScheme.outline` | Input field borders |
| Outline Variant | `Theme.of(context).colorScheme.outlineVariant` | Dividers, subtle borders |

Full color details: `references/color-system.md`

### 2. Shape Tokens & Extended Shapes
Material 3 Expressive shapes expand beyond standard rounded rectangles:

- Standard radii: Extra Small (4dp), Small (8dp), Medium (12dp), Large (16dp), Extra Large (28dp), Full (9999dp).
- Extended Expressive shapes via `flutter_m3shapes_extended`: `GemShape`, `SlantedShape`, `FlowerShape`, `ArchShape`, `CookieShape`, `StarburstShape`.

Full shape details: `references/typography-and-shape.md`

### 3. Motion & Haptics Physics
Expressive UI replaces static cubic-bezier curves with **spring physics** (`motor`) and tactile haptics (`m3e_haptics`):
- Stiffness & Damping: Springs react dynamically to user gesture velocity.
- Neighbor squish & pull: Adjacent cards or buttons deform during drag/press interactions.

---

## Component Quick Reference Table

| Component Category | Flutter Standard Widget | M3E Expressive Package / Widget | Key Features |
|--------------------|------------------------|--------------------------------|--------------|
| **Button System** | `ElevatedButton`, `FilledButton`, `OutlinedButton`, `TextButton` | `M3EButton`, `M3EToggleButton`, `M3ESplitButton` (`m3e_buttons`) | Neighbor squish, 5 sizes (XS–XL), shape morphing |
| **Card List** | `ListView.builder` + `Card` | `M3ECardList`, `SliverM3ECardList`, `M3ECardColumn` (`m3e_card_list`) | Dynamic corner radii calculation (first/middle/last items) |
| **Dismissible** | `Dismissible` | `M3EDismissible` (`m3e_dismissible`) | "Neighbour pull" spring physics, haptic feedback |
| **Expandable Card** | `ExpansionTile` | `M3EExpandable` (`m3e_expandable`) | Spring-animated expandable card sections |
| **Dropdown Menu** | `DropdownMenu`, `PopupMenuButton` | `M3EDropdownMenu` (`m3e_dropdown_menu`) | Fuzzy search, multi-selection, chip tags, async loading |
| **Floating Dock** | `BottomAppBar` | `M3EFloatingToolbar` (`m3e_floating_toolbar`) | Floating pill toolbar, horizontal/vertical spring dock |
| **Slider** | `Slider`, `RangeSlider` | `M3ESlider`, `M3ERangeSlider` (`m3e_slider`) | Docking spring physics, custom shape track |
| **Shapes** | `RoundedRectangleBorder` | `flutter_m3shapes_extended` | 20+ M3 expressive geometric shapes |
| **Progress** | `CircularProgressIndicator` | `M3EProgressIndicator` (`m3e_progress_indicator`) | Wavy patterns, morphing progress bars |
| **Loading** | `CircularProgressIndicator` | `M3ELoadingIndicator` (`m3e_loading_indicator`) | Fluid shape-morphing loading spinner |
| **Haptics** | `HapticFeedback` | `M3EHapticFeedback` (`m3e_haptics`) | Velocity-based spring haptic engine |

Full component documentation and code examples: `references/component-catalog.md`

---

## Common Patterns

### 1. App Shell with Responsive Navigation & Theme Setup

```dart
import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M3E Expressive App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      home: const ResponsiveAppShell(),
    );
  }
}

class ResponsiveAppShell extends StatefulWidget {
  const ResponsiveAppShell({super.key});

  @override
  State<ResponsiveAppShell> createState() => _ResponsiveAppShellState();
}

class _ResponsiveAppShellState extends State<ResponsiveAppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material 3 Expressive'),
        actions: [
          M3EButton(
            size: M3EButtonSize.sm,
            onPressed: () {},
            child: const Text('Action'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          if (!isCompact)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
                NavigationRailDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: Text('Explore')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
              ],
            ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: _buildBody(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
              ],
            )
          : null,
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        M3ECardList(
          itemCount: 3,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text('Expressive Card Item ${index + 1}'),
              subtitle: const Text('Dynamic radii automatically calculated'),
              trailing: const Icon(Icons.chevron_right),
            );
          },
          onTap: (index) {},
        ),
      ],
    );
  }
}
```

### 2. Expressive Card List with Swipe-to-Dismiss

```dart
M3ECardList(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return M3EDismissible(
      key: Key(item.id),
      onDismissed: (direction) {
        setState(() => items.removeAt(index));
      },
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      child: ListTile(
        title: Text(item.title),
        subtitle: Text(item.subtitle),
      ),
    );
  },
)
```

---

## Anti-Patterns in Flutter M3E

- **Hardcoding Colors**: Never use `Color(0xFF123456)` directly on UI components. Always resolve colors from `Theme.of(context).colorScheme`.
- **Mixing MD2 and MD3 APIs**: Do not use deprecated `ButtonTheme`, `FlatButton`, or `RaisedButton`. Always use `M3EButton` or MD3 widgets with `useMaterial3: true`.
- **Hardcoding Corner Radii**: Avoid `BorderRadius.circular(8)` on lists. Use `M3ECardList` or token shapes so corner radii adapt dynamically between outer and inner items.
- **Fixed Easing Curves**: Do not wrap interactive drag components in fixed `Curves.easeInOut` animations when physics-based spring motions (`motor`) provide natural user feedback.
- **Ignoring Responsive Screen Widths**: Avoid fixed `width: 360` wrappers. Use `MediaQuery` window size classes to adapt between mobile, tablet, desktop, and foldables.

---

## M3E Compliance Audit Checklist

When auditing a Flutter project for M3E compliance:

1. **Theming (`ThemeData`)**: Verify `useMaterial3: true` is enabled and `ColorScheme.fromSeed` or `M3EColorScheme` is configured.
2. **Color Tokens**: Check that all containers, text, and icons source colors from `Theme.of(context).colorScheme`.
3. **Buttons**: Ensure primary interactive actions leverage `M3EButton` variants (`M3EButtonSize`, squish physics, shape morphing).
4. **Lists & Cards**: Check if lists utilize `M3ECardList` for dynamic corner radii instead of plain `Card` items.
5. **Dismissible Items**: Verify swipeable list items use `M3EDismissible` for spring "neighbour pull" feedback.
6. **Sliders & Controls**: Verify input sliders use `M3ESlider` with spring docking.
7. **Responsiveness**: Check layout behavior across screen widths (<600dp compact, 600–840dp medium, >840dp expanded).

---

## Reference Documents

- `references/color-system.md` — Complete ColorScheme tokens, dynamic color setup, surface containers, contrast levels.
- `references/typography-and-shape.md` — TextTheme mapping, shape corner tokens, `flutter_m3shapes_extended`, spring motion curves.
- `references/component-catalog.md` — Complete Flutter catalog for standard M3 + all 12 `m3e_*` packages with Dart code examples.
- `references/layout-and-responsive.md` — Responsive breakpoints, window size classes, canonical layouts, 8dp grid spacing.
- `references/navigation-patterns.md` — NavigationBar, NavigationRail, NavigationDrawer, `M3EFloatingToolbar`, GoRouter setup.
- `references/theming-and-dynamic-color.md` — Advanced Flutter theming, `M3ETheme`, light/dark mode switching, theme extensions.
