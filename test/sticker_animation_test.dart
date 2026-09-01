import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/data/sticker_board.dart';
import 'package:memtickers/data/sticker_repository.dart';
import 'package:memtickers/details/sticker_details_sheet.dart';
import 'package:memtickers/scrapbook/scrapbook_page.dart';
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

    testWidgets('runs Thanos Snap effect when snapping is true in StickerObject', (
      tester,
    ) async {
      final sticker = Sticker(
        id: 's-snap',
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
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: StickerObject(
                  sticker: sticker,
                  selected: false,
                  dropping: false,
                  snapping: true,
                  onTap: () {},
                  onLongPress: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StickerObject), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.byType(StickerObject), findsOneWidget);
    });
  });

  group('Sticker Details Sheet Thanos Snap Deletion Tests', () {
    testWidgets('confirming delete in details sheet pops sheet with true', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final sticker = Sticker(
        id: 's-delete-snap',
        boardId: 'default',
        imagePath: 'test/sample.png',
        createdAt: DateTime(2026, 1, 1),
        modelTags: const ['sample'],
        x: 50,
        y: 50,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );

      repo.populateForTesting(
        stickers: [sticker],
        boards: [],
        activeBoardId: 'default',
      );

      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showStickerDetails(
                      context: context,
                      sticker: sticker,
                      repository: repo,
                    );
                  },
                  child: const Text('Open Details'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      expect(find.text('Memory Details'), findsOneWidget);

      // Scroll to Delete button and tap it
      final deleteBtn = find.text('Delete');
      await tester.scrollUntilVisible(
        deleteBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Peel this sticker off?'), findsOneWidget);

      // Confirm delete in dialog
      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      );
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify dialog closed normally and details sheet popped with true
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Memory Details'), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('ScrapbookPage sticker deletion triggers board Thanos snap effect and removes sticker', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final board = StickerBoard(
        id: 'default',
        name: 'Memories',
        createdAt: DateTime(2026, 1, 1),
        isNavigationMode: true,
      );
      final sticker = Sticker(
        id: 's-board-snap',
        boardId: 'default',
        imagePath: 'test/sample.png',
        createdAt: DateTime(2026, 1, 1),
        modelTags: const ['sample'],
        x: 1916,
        y: 1916,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );

      repo.populateForTesting(
        stickers: [sticker],
        boards: [board],
        activeBoardId: 'default',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: ScrapbookPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StickerObject), findsOneWidget);

      // Tap sticker to open details
      await tester.tap(find.byType(StickerObject));
      await tester.pumpAndSettle();

      expect(find.text('Memory Details'), findsOneWidget);

      // Scroll to Delete button and tap it
      final deleteBtn = find.text('Delete');
      await tester.scrollUntilVisible(
        deleteBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Peel this sticker off?'), findsOneWidget);

      // Confirm delete in dialog
      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      );
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Details sheet and dialog are closed, back on scrapbook board
      expect(find.text('Memory Details'), findsNothing);

      // Advance async timer past the 1400ms Thanos snap dissolution duration
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Sticker has been completely deleted and removed from repository and board
      expect(repo.stickers, isEmpty);
      expect(find.byType(StickerObject), findsNothing);
    });
  });
}
