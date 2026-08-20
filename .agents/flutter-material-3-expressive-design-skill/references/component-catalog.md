# Material Design 3 Expressive Component Catalog for Flutter

This catalog provides an exhaustive guide to implementing both standard Flutter Material 3 components and Expressive M3 components (`m3e_core` ecosystem).

---

## Table of Contents
1. [Expressive Button System (`m3e_buttons`)](#1-expressive-button-system-m3e_buttons)
2. [Expressive Card List (`m3e_card_list`)](#2-expressive-card-list-m3e_card_list)
3. [Expressive Dismissible Cards (`m3e_dismissible`)](#3-expressive-dismissible-cards-m3e_dismissible)
4. [Expressive Expandable Cards (`m3e_expandable`)](#4-expressive-expandable-cards-m3e_expandable)
5. [Expressive Dropdown Menu (`m3e_dropdown_menu`)](#5-expressive-dropdown-menu-m3e_dropdown_menu)
6. [Extended M3 Shapes (`flutter_m3shapes_extended`)](#6-extended-m3-shapes-flutter_m3shapes_extended)
7. [Expressive Floating Toolbar (`m3e_floating_toolbar`)](#7-expressive-floating-toolbar-m3e_floating_toolbar)
8. [Expressive Sliders (`m3e_slider`)](#8-expressive-sliders-m3e_slider)
9. [Expressive Haptics (`m3e_haptics`)](#9-expressive-haptics-m3e_haptics)
10. [Expressive Progress & Loading Indicators](#10-expressive-progress--loading-indicators)
11. [Standard Flutter M3 Widgets Reference](#11-standard-flutter-m3-widgets-reference)

---

## 1. Expressive Button System (`m3e_buttons`)

The `m3e_buttons` package provides spring-animated expressive buttons featuring **neighbor squish** (adjacent buttons compress on press), **shape morphing**, and 5 size presets (`M3EButtonSize.xs`, `sm`, `md`, `lg`, `xl`).

### Variants & Usage

```dart
import 'package:flutter/material.dart';
import 'package:m3e_buttons/m3e_buttons.dart';

Widget buildExpressiveButtons(BuildContext context) {
  return Column(
    children: [
      // Standard Filled M3E Button
      M3EButton(
        size: M3EButtonSize.lg,
        onPressed: () {},
        child: const Text('Primary Action'),
      ),
      const SizedBox(height: 12),

      // Tonal / Secondary M3E Button
      M3EButton.tonal(
        size: M3EButtonSize.md,
        onPressed: () {},
        icon: const Icon(Icons.add),
        child: const Text('Add Item'),
      ),
      const SizedBox(height: 12),

      // M3E Toggle Button Group with Neighbor Squish
      M3EToggleButton(
        isSelected: const [true, false, false],
        onPressed: (index) {},
        children: const [
          Icon(Icons.format_align_left),
          Icon(Icons.format_align_center),
          Icon(Icons.format_align_right),
        ],
      ),
      const SizedBox(height: 12),

      // M3E Split Button (Action + Dropdown trigger)
      M3ESplitButton(
        onPressed: () {},
        onMenuPressed: () {},
        child: const Text('Save Document'),
      ),
    ],
  );
}
```

---

## 2. Expressive Card List (`m3e_card_list`)

`m3e_card_list` calculates dynamic corner radii between adjacent items (large outer radii for list endpoints, smaller inner radii for adjoining items).

### Standard, Sliver, & Column Variants

```dart
import 'package:flutter/material.dart';
import 'package:m3e_card_list/m3e_card_list.dart';

// 1. Scrollable ListView Card List
Widget buildScrollableCardList() {
  return M3ECardList(
    itemCount: 10,
    gap: 4.0,
    outerRadius: 20.0,
    innerRadius: 8.0,
    itemBuilder: (context, index) {
      return ListTile(
        title: Text('Item ${index + 1}'),
        subtitle: const Text('Dynamic corner radius automatically applied'),
      );
    },
    onTap: (index) {
      print('Tapped item $index');
    },
  );
}

// 2. Static Non-Scrollable Column Variant
Widget buildStaticCardColumn() {
  return M3ECardColumn(
    children: [
      ListTile(title: Text('Profile Settings')),
      ListTile(title: Text('Notifications')),
      ListTile(title: Text('Privacy & Security')),
    ],
  );
}
```

---

## 3. Expressive Dismissible Cards (`m3e_dismissible`)

`m3e_dismissible` implements swipe-to-dismiss with spring-driven **neighbour pull** physics, causing adjacent list items to compress and expand dynamically during drag.

```dart
import 'package:flutter/material.dart';
import 'package:m3e_dismissible/m3e_dismissible.dart';

Widget buildDismissibleList(List<String> items, Function(int) onDelete) {
  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      final item = items[index];
      return M3EDismissible(
        key: Key(item),
        onDismissed: (direction) => onDelete(index),
        background: Container(
          color: Theme.of(context).colorScheme.errorContainer,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        child: ListTile(
          title: Text(item),
          subtitle: const Text('Swipe left or right to dismiss'),
        ),
      );
    },
  );
}
```

---

## 4. Expressive Expandable Cards (`m3e_expandable`)

`m3e_expandable` uses spring animations (`motor`) to expand and collapse card lists smoothly without choppy layout transitions.

```dart
import 'package:flutter/material.dart';
import 'package:m3e_expandable/m3e_expandable.dart';

Widget buildExpandableSection() {
  return M3EExpandable(
    title: const Text('Advanced Settings'),
    subtitle: const Text('Tap to expand spring container'),
    children: const [
      ListTile(title: Text('Option 1: Dark Mode Override')),
      ListTile(title: Text('Option 2: Tactile Haptics Engine')),
      ListTile(title: Text('Option 3: Spring Stiffness Ratio')),
    ],
  );
}
```

---

## 5. Expressive Dropdown Menu (`m3e_dropdown_menu`)

`m3e_dropdown_menu` is a fluid dropdown supporting fuzzy search, multi-selection, chip tags, and async data loading.

```dart
import 'package:flutter/material.dart';
import 'package:m3e_dropdown_menu/m3e_dropdown_menu.dart';

Widget buildExpressiveDropdown() {
  return M3EDropdownMenu<String>(
    items: const [
      DropdownItem(label: 'Flutter', value: 'flutter'),
      DropdownItem(label: 'Dart', value: 'dart'),
      DropdownItem(label: 'Jetpack Compose', value: 'compose'),
      DropdownItem(label: 'Kotlin', value: 'kotlin'),
    ],
    searchEnabled: true,
    hintText: 'Select Frameworks',
    onChanged: (selectedValues) {
      print('Selected: $selectedValues');
    },
  );
}
```

---

## 6. Extended M3 Shapes (`flutter_m3shapes_extended`)

Provides 20+ Material 3 Expressive shapes for custom clipping, avatars, badges, and background containers.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_m3shapes_extended/flutter_m3shapes_extended.dart';

Widget buildShapeAvatar(BuildContext context) {
  return ClipPath(
    clipper: ShapeBorderClipper(shape: SlantedShape()),
    child: Container(
      width: 80,
      height: 80,
      color: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.person, color: Colors.white, size: 40),
    ),
  );
}
```

---

## 7. Expressive Floating Toolbar (`m3e_floating_toolbar`)

`m3e_floating_toolbar` implements the Material 3 Expressive floating dock/toolbar family with spring recoil physics and hide-on-scroll integration.

```dart
import 'package:flutter/material.dart';
import 'package:m3e_floating_toolbar/m3e_floating_toolbar.dart';

Widget buildFloatingActionDock() {
  return M3EFloatingToolbar(
    children: [
      IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.bookmark_outline)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline)),
    ],
  );
}
```

---

## 8. Expressive Sliders (`m3e_slider`)

`m3e_slider` provides `M3ESlider` and `M3ERangeSlider` with spring docking animations, custom track morphing, and tactile feedback integration.

```dart
import 'package:flutter/material.dart';
import 'package:m3e_slider/m3e_slider.dart';

Widget buildExpressiveSlider(double value, ValueChanged<double> onChanged) {
  return M3ESlider(
    value: value,
    min: 0.0,
    max: 100.0,
    onChanged: onChanged,
  );
}
```

---

## 9. Expressive Haptics (`m3e_haptics`)

```dart
import 'package:m3e_haptics/m3e_haptics.dart';

void performActionWithHaptics() {
  M3EHapticFeedback.medium(); // Trigger spring-synchronized haptic pulse
}
```

---

## 10. Expressive Progress & Loading Indicators

```dart
import 'package:flutter/material.dart';
import 'package:m3e_progress_indicator/m3e_progress_indicator.dart';
import 'package:m3e_loading_indicator/m3e_loading_indicator.dart';

Widget buildIndicators() {
  return Column(
    children: [
      // Wavy / Morphing Progress Indicator
      M3EProgressIndicator(value: 0.65),
      const SizedBox(height: 16),

      // Shape-Morphing Loading Spinner
      const M3ELoadingIndicator(),
    ],
  );
}
```

---

## 11. Standard Flutter M3 Widgets Reference

When combining M3E packages with standard Flutter widgets, always set `useMaterial3: true` in `ThemeData`:

- **Buttons**: `FilledButton`, `FilledButton.tonal`, `OutlinedButton`, `TextButton`, `ElevatedButton`.
- **Navigation**: `NavigationBar`, `NavigationRail`, `NavigationDrawer`.
- **App Bars**: `AppBar`, `SliverAppBar.large`, `SliverAppBar.medium`.
- **Inputs**: `TextField` (with `InputDecoration(border: OutlinedInputBorder())`), `Checkbox`, `Radio`, `Switch`.
- **Sheets & Dialogs**: `showModalBottomSheet`, `showDialog` (`AlertDialog`).
