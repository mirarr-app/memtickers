# Material Design 3 Expressive Layout & Responsive System in Flutter

This guide details responsive window size classes, canonical layouts, 8dp spacing grids, edge-to-edge system insets, and adaptive screen handling in Flutter.

---

## 1. Window Size Classes (5 Breakpoints)

Material 3 defines 5 responsive window size classes based on available screen width. Flutter apps should query window constraints using `MediaQuery.of(context).size.width` or `LayoutBuilder`:

| Size Class | Width Range (dp) | Target Devices | Recommended Primary Layout Structure |
|------------|------------------|----------------|--------------------------------------|
| **Compact** | `< 600` | Phones (portrait), small foldables | Single column, `NavigationBar` (bottom nav) |
| **Medium** | `600 – 839` | Tablets (portrait), large foldables, phone landscape | Dual pane or single column with `NavigationRail` |
| **Expanded** | `840 – 1199` | Tablets (landscape), small laptops, desktop | List-Detail dual pane + `NavigationRail` / `NavigationDrawer` |
| **Large** | `1200 – 1599` | Laptops, desktop monitors | Multi-pane layout with max-width content constraints |
| **Extra Large** | `>= 1600` | Large desktop, ultra-wide monitors | Multi-column / multi-pane layout constrained to ~1040dp content width |

---

## 2. Canonical Layout Patterns in Flutter

### 1. List-Detail Layout (Adaptive Dual Pane)

```dart
import 'package:flutter/material.dart';

class AdaptiveListDetailScreen extends StatefulWidget {
  const AdaptiveListDetailScreen({super.key});

  @override
  State<AdaptiveListDetailScreen> createState() => _AdaptiveListDetailScreenState();
}

class _AdaptiveListDetailScreenState extends State<AdaptiveListDetailScreen> {
  int? _selectedItemId;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDualPane = width >= 840;

    if (isDualPane) {
      // Expanded/Large/Extra Large: Show List + Detail side-by-side
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              flex: 4,
              child: _buildItemList((id) => setState(() => _selectedItemId = id)),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 6,
              child: _selectedItemId != null
                  ? _buildDetailPane(_selectedItemId!)
                  : const Center(child: Text('Select an item to view details')),
            ),
          ],
        ),
      );
    }

    // Compact/Medium: Stacked navigation (Push to detail page)
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: _buildItemList((id) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Scaffold(
            appBar: AppBar(title: Text('Item $id')),
            body: _buildDetailPane(id),
          )),
        );
      }),
    );
  }

  Widget _buildItemList(ValueChanged<int> onSelect) {
    return ListView.builder(
      itemCount: 20,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text('Item ${index + 1}'),
          onTap: () => onSelect(index + 1),
        );
      },
    );
  }

  Widget _buildDetailPane(int id) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details for Item $id', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          const Text('Detailed item content goes here...'),
        ],
      ),
    );
  }
}
```

---

## 3. Spacing Token System (8dp Grid)

Material Design 3 enforces an **8dp baseline grid** for layout margins, paddings, and component gaps (with 4dp micro-spacing for dense elements):

| Token Name | Value | Recommended Usage |
|------------|-------|-------------------|
| `space4` | 4dp | Micro gap between icon and label, tight list item padding |
| `space8` | 8dp | Compact gap between adjacent buttons, chip spacing |
| `space12` | 12dp | Medium internal component padding, list item gaps |
| `space16` | 16dp | Standard screen content padding, card inner padding |
| `space24` | 24dp | Large section spacing, dialog content padding |
| `space32` | 32dp | Hero section margin, multi-pane divider gaps |
| `space48` | 48dp | Minimum touch target boundary for accessibility |

---

## 4. Edge-to-Edge & System Insets in Flutter

Enable edge-to-edge rendering in Flutter so app content flows naturally behind the system status bar and navigation bar:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void setupEdgeToEdge() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      navigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      navigationBarIconBrightness: Brightness.dark,
    ),
  );
}
```

Handling system safe areas and keyboard insets in Flutter:

```dart
Widget buildEdgeToEdgeContainer(BuildContext context) {
  final padding = MediaQuery.of(context).padding;
  final viewInsets = MediaQuery.of(context).viewInsets;

  return Padding(
    padding: EdgeInsets.only(
      top: padding.top,
      bottom: padding.bottom + viewInsets.bottom,
    ),
    child: const ContentWidget(),
  );
}
```
