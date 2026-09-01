import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/boards/boards_sheet.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/data/sticker_board.dart';
import 'package:memtickers/data/sticker_repository.dart';

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
}
