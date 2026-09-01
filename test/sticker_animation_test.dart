import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/scrapbook/sticker_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StickerObject Sticking Animation Tests', () {
    testWidgets('renders StickerObject statically when dropping is false', (
      tester,
    ) async {
      final sticker = Sticker(
        id: 's-static',
        imagePath: 'test/non_existent.png',
        createdAt: DateTime(2026, 1, 1),
        x: 100,
        y: 100,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: StickerObject(
              sticker: sticker,
              selected: false,
              dropping: false,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      expect(find.byType(StickerObject), findsOneWidget);
      expect(find.bySemanticsLabel('Memory sticker'), findsOneWidget);
    });

    testWidgets('runs sticking animation when mounted with dropping=true and settles', (
      tester,
    ) async {
      final sticker = Sticker(
        id: 's-dropping',
        imagePath: 'test/non_existent.png',
        createdAt: DateTime(2026, 1, 1),
        x: 100,
        y: 100,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: StickerObject(
              sticker: sticker,
              selected: false,
              dropping: true,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      expect(find.byType(StickerObject), findsOneWidget);

      // Mid-animation frame (approx impact / slap stage)
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(StickerObject), findsOneWidget);

      // Rebound / settle stage
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(StickerObject), findsOneWidget);

      // Fully settled
      await tester.pumpAndSettle();
      expect(find.byType(StickerObject), findsOneWidget);
    });

    testWidgets('triggers sticking animation when dropping becomes true dynamically', (
      tester,
    ) async {
      final sticker = Sticker(
        id: 's-dynamic',
        imagePath: 'test/non_existent.png',
        createdAt: DateTime(2026, 1, 1),
        x: 100,
        y: 100,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );

      var isDropping = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: Scaffold(
                body: Column(
                  children: [
                    StickerObject(
                      sticker: sticker,
                      selected: false,
                      dropping: isDropping,
                      onTap: () {},
                      onLongPress: () {},
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => isDropping = true),
                      child: const Text('Trigger Drop'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Trigger Drop'), findsOneWidget);
      await tester.tap(find.text('Trigger Drop'));
      await tester.pump();

      // Verify animation frames progress smoothly
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(StickerObject), findsOneWidget);
    });
  });
}
