import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/boards/boards_sheet.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/data/sticker_board.dart';
import 'package:memtickers/data/sticker_repository.dart';

import 'package:memtickers/details/sticker_details_sheet.dart';
import 'package:memtickers/scrapbook/scrapbook_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StickerBoard model', () {
    test('toMap and fromMap with isNavigationMode', () {
      final now = DateTime.now();
      final board = StickerBoard(
        id: 'b-1',
        name: 'Japan 2026',
        createdAt: now,
        isNavigationMode: true,
      );

      final map = board.toMap();
      expect(map['id'], 'b-1');
      expect(map['name'], 'Japan 2026');
      expect(map['createdAt'], now.millisecondsSinceEpoch);
      expect(map['isNavigationMode'], 1);

      final restored = StickerBoard.fromMap(map);
      expect(restored.id, 'b-1');
      expect(restored.name, 'Japan 2026');
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      expect(restored.isNavigationMode, true);
    });

    test('copyWith isNavigationMode', () {
      final board = StickerBoard(
        id: 'b-1',
        name: 'Road Trip',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(board.isNavigationMode, false);

      final updated = board.copyWith(
        name: 'California Trip',
        isNavigationMode: true,
      );
      expect(updated.id, 'b-1');
      expect(updated.name, 'California Trip');
      expect(updated.isNavigationMode, true);
      expect(updated.createdAt, board.createdAt);
    });

    test('equality and hashCode', () {
      final now = DateTime(2026, 1, 1);
      final b1 = StickerBoard(
        id: 'b-1',
        name: 'Board',
        createdAt: now,
        isNavigationMode: false,
      );
      final b2 = StickerBoard(
        id: 'b-1',
        name: 'Board',
        createdAt: now,
        isNavigationMode: false,
      );
      final b3 = StickerBoard(
        id: 'b-2',
        name: 'Board',
        createdAt: now,
        isNavigationMode: false,
      );

      expect(b1, equals(b2));
      expect(b1.hashCode, equals(b2.hashCode));
      expect(b1, isNot(equals(b3)));
    });
  });

  group('Sticker model with boardId', () {
    test('default boardId is default', () {
      final sticker = Sticker(
        id: 's1',
        imagePath: '/path/to/img.png',
        createdAt: DateTime(2026, 1, 1),
        x: 100,
        y: 100,
        rotation: 0.0,
        scale: 1.0,
        zIndex: 0,
      );
      expect(sticker.boardId, 'default');
    });

    test('custom boardId serializes to and from map', () {
      final sticker = Sticker(
        id: 's1',
        boardId: 'custom-board-123',
        imagePath: '/path/to/img.png',
        createdAt: DateTime(2026, 1, 1),
        x: 100,
        y: 100,
        rotation: 0.0,
        scale: 1.0,
        zIndex: 0,
      );
      expect(sticker.boardId, 'custom-board-123');

      final map = sticker.toMap();
      expect(map['boardId'], 'custom-board-123');

      final restored = Sticker.fromMap(map);
      expect(restored.boardId, 'custom-board-123');
    });

    test('copyWith boardId', () {
      final sticker = Sticker(
        id: 's1',
        boardId: 'default',
        imagePath: '/path/to/img.png',
        createdAt: DateTime(2026, 1, 1),
        x: 100,
        y: 100,
        rotation: 0.0,
        scale: 1.0,
        zIndex: 0,
      );
      final updated = sticker.copyWith(boardId: 'vacation-board');
      expect(updated.boardId, 'vacation-board');
    });

    test('equality and hashCode', () {
      final now = DateTime(2026, 1, 1);
      final s1 = Sticker(
        id: 's1',
        boardId: 'b1',
        imagePath: '/path/1.png',
        createdAt: now,
        x: 10,
        y: 20,
        rotation: 0.1,
        scale: 1.2,
        zIndex: 1,
        tags: const ['tagA'],
        modelTags: const ['mtagA'],
      );
      final s2 = Sticker(
        id: 's1',
        boardId: 'b1',
        imagePath: '/path/1.png',
        createdAt: now,
        x: 10,
        y: 20,
        rotation: 0.1,
        scale: 1.2,
        zIndex: 1,
        tags: const ['tagA'],
        modelTags: const ['mtagA'],
      );
      final s3 = s1.copyWith(scale: 1.5);

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));
    });
  });

  group('StickerRepository deleteBoard', () {
    test('throws StateError when attempting to delete the only board', () async {
      final repo = StickerRepository();
      final board = StickerBoard(
        id: 'b-only',
        name: 'Only Board',
        createdAt: DateTime(2026, 1, 1),
      );
      repo.populateForTesting(boards: [board], activeBoardId: 'b-only');

      expect(() => repo.deleteBoard('b-only'), throwsStateError);
    });

    test('deletes board and its stickers, switching activeBoardId', () async {
      final repo = StickerRepository();
      final board1 = StickerBoard(
        id: 'b-1',
        name: 'Board 1',
        createdAt: DateTime(2026, 1, 1),
      );
      final board2 = StickerBoard(
        id: 'b-2',
        name: 'Board 2',
        createdAt: DateTime(2026, 1, 2),
      );
      final s1 = Sticker(
        id: 's-1',
        boardId: 'b-1',
        imagePath: '/path/1.png',
        createdAt: DateTime(2026, 1, 1),
        x: 0,
        y: 0,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );
      final s2 = Sticker(
        id: 's-2',
        boardId: 'b-2',
        imagePath: '/path/2.png',
        createdAt: DateTime(2026, 1, 2),
        x: 0,
        y: 0,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );

      repo.populateForTesting(
        boards: [board1, board2],
        stickers: [s1, s2],
        activeBoardId: 'b-1',
      );

      expect(repo.boards.length, 2);
      expect(repo.allStickers.length, 2);

      await repo.deleteBoard('b-1');

      expect(repo.boards.length, 1);
      expect(repo.boards.first.id, 'b-2');
      expect(repo.activeBoardId, 'b-2');
      expect(repo.allStickers.length, 1);
      expect(repo.allStickers.first.id, 's-2');
    });
  });

  group('BoardsSheet UI Widget Tests', () {
    testWidgets('renders boards sheet and displays creation input field', (
      tester,
    ) async {
      final repo = StickerRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () =>
                      showBoardsSheet(context: context, repository: repo),
                  child: const Text('Open Boards Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Boards Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Boards'), findsOneWidget);
      expect(
        find.text('Switch between, manage, or lock boards in navigation mode'),
        findsOneWidget,
      );
      expect(find.text('New board name…'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('Move Sticker to Board Tests', () {
    test('moveStickerToBoard updates sticker boardId and repo state', () async {
      final repo = StickerRepository();
      final sticker = Sticker(
        id: 's-move-1',
        boardId: 'b-source',
        imagePath: '/path/1.png',
        createdAt: DateTime(2026, 1, 1),
        x: 50,
        y: 50,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );
      final board1 = StickerBoard(
        id: 'b-source',
        name: 'Source Board',
        createdAt: DateTime(2026, 1, 1),
      );
      final board2 = StickerBoard(
        id: 'b-dest',
        name: 'Destination Board',
        createdAt: DateTime(2026, 1, 2),
      );

      repo.populateForTesting(
        stickers: [sticker],
        boards: [board1, board2],
        activeBoardId: 'b-source',
      );

      expect(repo.stickers.length, 1);
      expect(repo.stickers.first.boardId, 'b-source');

      await repo.moveStickerToBoard('s-move-1', 'b-dest');

      expect(repo.allStickers.first.boardId, 'b-dest');
      // On b-source, stickers list is now empty
      expect(repo.stickers, isEmpty);
    });

    testWidgets('Move sticker to another board from detail sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final sticker = Sticker(
        id: 's-detail-1',
        boardId: 'b-1',
        imagePath: '/path/1.png',
        createdAt: DateTime(2026, 1, 1),
        modelTags: const ['sample'],
        x: 50,
        y: 50,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );
      final board1 = StickerBoard(
        id: 'b-1',
        name: 'First Board',
        createdAt: DateTime(2026, 1, 1),
      );
      final board2 = StickerBoard(
        id: 'b-2',
        name: 'Second Board',
        createdAt: DateTime(2026, 1, 2),
      );

      repo.populateForTesting(
        stickers: [sticker],
        boards: [board1, board2],
        activeBoardId: 'b-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showStickerDetails(
                    context: context,
                    sticker: sticker,
                    repository: repo,
                  ),
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
      expect(find.text('First Board'), findsOneWidget);
      expect(find.text('Move Board'), findsOneWidget);

      // Tap Move Board button
      await tester.tap(find.text('Move Board'));
      await tester.pumpAndSettle();

      expect(find.text('Move Sticker to Board'), findsOneWidget);
      expect(find.text('Second Board'), findsOneWidget);

      // Select Second Board
      await tester.tap(find.text('Second Board'));
      await tester.pumpAndSettle();

      expect(repo.allStickers.first.boardId, 'b-2');
    });

    testWidgets('Create new board and move sticker to it from detail sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final sticker = Sticker(
        id: 's-detail-2',
        boardId: 'b-1',
        imagePath: '/path/2.png',
        createdAt: DateTime(2026, 1, 1),
        modelTags: const ['sample'],
        x: 50,
        y: 50,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );
      final board1 = StickerBoard(
        id: 'b-1',
        name: 'First Board',
        createdAt: DateTime(2026, 1, 1),
      );

      repo.populateForTesting(
        stickers: [sticker],
        boards: [board1],
        activeBoardId: 'b-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showStickerDetails(
                    context: context,
                    sticker: sticker,
                    repository: repo,
                  ),
                  child: const Text('Open Details'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      // Tap 'Board' row in metadata list
      await tester.tap(find.text('First Board'));
      await tester.pumpAndSettle();

      expect(find.text('Move Sticker to Board'), findsOneWidget);
      expect(find.text('New board name…'), findsOneWidget);

      // Type new board name
      await tester.enterText(
        find.widgetWithText(TextField, 'New board name…'),
        'Vacation 2026',
      );
      await tester.pumpAndSettle();

      // Tap Add & Move button
      await tester.tap(find.text('Add & Move'));
      await tester.pumpAndSettle();

      expect(repo.boards.any((b) => b.name == 'Vacation 2026'), isTrue);
      final newBoard = repo.boards.firstWhere((b) => b.name == 'Vacation 2026');
      expect(repo.allStickers.first.boardId, newBoard.id);
    });
  });

  group('Navigation Mode UI in ScrapbookPage', () {
    testWidgets('shows small lock icon on top right and no pillbar when locked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final lockedBoard = StickerBoard(
        id: 'b-locked',
        name: 'My Locked Memories',
        createdAt: DateTime(2026, 1, 1),
        isNavigationMode: true,
      );

      repo.populateForTesting(
        stickers: [],
        boards: [lockedBoard],
        activeBoardId: 'b-locked',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: ScrapbookPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no pillbar text with board name or navigation mode text
      expect(find.text('• Navigation Mode (Locked)'), findsNothing);
      expect(find.text('My Locked Memories • Navigation Mode (Locked)'), findsNothing);

      // Verify lock icon is present with tooltip
      expect(
        find.widgetWithIcon(Tooltip, Icons.lock_rounded),
        findsOneWidget,
      );

      // Verify tapping lock icon opens boards sheet
      await tester.tap(find.widgetWithIcon(Tooltip, Icons.lock_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Boards'), findsOneWidget);
    });

    testWidgets('does not show lock icon when navigation mode is disabled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final unlockedBoard = StickerBoard(
        id: 'b-unlocked',
        name: 'Open Board',
        createdAt: DateTime(2026, 1, 1),
        isNavigationMode: false,
      );

      repo.populateForTesting(
        stickers: [],
        boards: [unlockedBoard],
        activeBoardId: 'b-unlocked',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: ScrapbookPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithIcon(Tooltip, Icons.lock_rounded),
        findsNothing,
      );
      expect(find.text('• Navigation Mode (Locked)'), findsNothing);
    });

    testWidgets('unlocking and locking from the board menu updates ScrapbookPage immediately', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final board = StickerBoard(
        id: 'b-main',
        name: 'My Board',
        createdAt: DateTime(2026, 1, 1),
        isNavigationMode: false,
      );

      repo.populateForTesting(
        stickers: [],
        boards: [board],
        activeBoardId: 'b-main',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: ScrapbookPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Initially unlocked: no lock icon on ScrapbookPage
      expect(find.byTooltip('Navigation mode (locked)'), findsNothing);

      // Open boards sheet via bottom toolbar
      await tester.tap(find.byTooltip('Boards'));
      await tester.pumpAndSettle();

      // Tap lock button on board in sheet
      await tester.tap(find.byTooltip('Lock board (Enable navigation mode)'));
      await tester.pumpAndSettle();

      // ScrapbookPage now has lock icon immediately
      expect(find.byTooltip('Navigation mode (locked)'), findsOneWidget);

      // Tap unlock button in sheet
      await tester.tap(find.byTooltip('Unlock board (Exit navigation mode)'));
      await tester.pumpAndSettle();

      // ScrapbookPage immediately removes lock icon
      expect(find.byTooltip('Navigation mode (locked)'), findsNothing);
    });
  });
}
