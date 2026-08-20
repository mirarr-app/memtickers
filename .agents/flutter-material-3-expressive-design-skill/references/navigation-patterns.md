# Material Design 3 Navigation Patterns in Flutter

This reference guide details Material 3 navigation structures in Flutter, including `NavigationBar`, `NavigationRail`, `NavigationDrawer`, `M3EFloatingToolbar`, top app bars, and GoRouter integration.

---

## 1. Navigation Components Selection Matrix

Choose navigation components based on screen size class and app structure:

| Navigation Component | Screen Size Class | Position | Primary Use Case |
|----------------------|-------------------|----------|------------------|
| **`NavigationBar`** | Compact (< 600dp) | Bottom | 3–5 primary top-level destinations |
| **`NavigationRail`** | Medium / Expanded (600dp–1199dp) | Left side | 3–7 destinations with optional FAB at top |
| **`NavigationDrawer`** | Expanded / Large (840dp+) | Left side (modal or standard) | 7+ destinations, grouped categories, account profiles |
| **`M3EFloatingToolbar`** | Compact / Medium / Expanded | Floating dock | Quick context-sensitive action dock / floating nav |

---

## 2. GoRouter Integration Example

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavigation(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExploreScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

class ScaffoldWithNavigation extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavigation({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 600;

    return Scaffold(
      body: Row(
        children: [
          if (!isCompact)
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) => _onItemTapped(index, context),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
                NavigationRailDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: Text('Explore')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
              ],
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) => _onItemTapped(index, context),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
              ],
            )
          : null,
    );
  }

  int _locationToIndex(String location) {
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/explore'); break;
      case 2: context.go('/settings'); break;
    }
  }
}
```

---

## 3. Top App Bars in Material 3

Flutter provides 4 standard M3 app bar styles via `AppBar` and `SliverAppBar`:

```dart
// 1. Center-Aligned App Bar
AppBar(
  centerTitle: true,
  title: const Text('Title'),
);

// 2. Large Collapsing Top App Bar (CustomScrollView)
SliverAppBar.large(
  title: const Text('Large Headline Title'),
  actions: [
    IconButton(icon: const Icon(Icons.search), onPressed: () {}),
  ],
);

// 3. Medium Collapsing Top App Bar
SliverAppBar.medium(
  title: const Text('Medium Title'),
);
```

---

## 4. M3E Floating Toolbar Navigation Dock

For expressive floating toolbar navigation overlay (`m3e_floating_toolbar`):

```dart
Widget buildFloatingNavDock(BuildContext context) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: M3EFloatingToolbar(
        children: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {},
          ),
        ],
      ),
    ),
  );
}
```
