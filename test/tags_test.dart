import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/data/sticker_repository.dart';
import 'package:memtickers/data/sticker_tag.dart';
import 'package:memtickers/tags/tag_selection_sheet.dart';
import 'package:memtickers/tags/tags_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StickerTag model', () {
    test('toMap and fromMap', () {
      final now = DateTime.now();
      final tag = StickerTag(id: 'tag-1', name: 'Memories', createdAt: now);

      final map = tag.toMap();
      expect(map['id'], 'tag-1');
      expect(map['name'], 'Memories');
      expect(map['createdAt'], now.millisecondsSinceEpoch);

      final restored = StickerTag.fromMap(map);
      expect(restored.id, 'tag-1');
      expect(restored.name, 'Memories');
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });

    test('equality and copyWith', () {
      final tag1 = StickerTag(
        id: 't1',
        name: 'Travel',
        createdAt: DateTime(2025, 1, 1),
      );
      final tag2 = StickerTag(
        id: 't1',
        name: 'Travel',
        createdAt: DateTime(2025, 1, 1),
      );
      expect(tag1, equals(tag2));
      expect(tag1.hashCode, equals(tag2.hashCode));

      final updated = tag1.copyWith(name: 'Adventures');
      expect(updated.name, 'Adventures');
      expect(updated.id, 't1');
    });
  });

  group('Sticker model with tags', () {
    test('default empty tags list', () {
      final sticker = Sticker(
        id: 's1',
        imagePath: '/path/to/img.png',
        createdAt: DateTime(2025, 1, 1),
        x: 100,
        y: 100,
        rotation: 0.0,
        scale: 1.0,
        zIndex: 0,
      );
      expect(sticker.tags, isEmpty);
    });

    test('retains tags and serializes to/from map', () {
      final sticker = Sticker(
        id: 's1',
        imagePath: '/path/to/img.png',
        createdAt: DateTime(2025, 1, 1),
        tags: const ['Vacation', 'Friends'],
        x: 100,
        y: 100,
        rotation: 0.0,
        scale: 1.0,
        zIndex: 0,
      );
      expect(sticker.tags, containsAll(['Vacation', 'Friends']));

      final map = sticker.toMap();
      final restored = Sticker.fromMap(
        map,
        tags: const ['Vacation', 'Friends'],
      );
      expect(restored.tags, containsAll(['Vacation', 'Friends']));
    });

    test('copyWith tags', () {
      final sticker = Sticker(
        id: 's1',
        imagePath: '/path/to/img.png',
        createdAt: DateTime(2025, 1, 1),
        tags: const ['OldTag'],
        x: 100,
        y: 100,
        rotation: 0.0,
        scale: 1.0,
        zIndex: 0,
      );
      final updated = sticker.copyWith(tags: const ['NewTag']);
      expect(updated.tags, equals(['NewTag']));
    });

    test('retains modelTags and handles copyWith modelTags', () {
      final sticker = Sticker(
        id: 's1',
        imagePath: '/path/to/img.png',
        createdAt: DateTime(2025, 1, 1),
        tags: const ['userTag'],
        modelTags: const ['coffee', 'mug'],
        x: 100,
        y: 100,
        rotation: 0.0,
        scale: 1.0,
        zIndex: 0,
      );
      expect(sticker.tags, equals(['userTag']));
      expect(sticker.modelTags, equals(['coffee', 'mug']));

      final updated = sticker.copyWith(modelTags: const ['latte', 'drink']);
      expect(updated.tags, equals(['userTag']));
      expect(updated.modelTags, equals(['latte', 'drink']));

      final map = sticker.toMap();
      final restored = Sticker.fromMap(
        map,
        tags: const ['userTag'],
        modelTags: const ['coffee', 'mug'],
      );
      expect(restored.tags, equals(['userTag']));
      expect(restored.modelTags, equals(['coffee', 'mug']));
    });
  });

  group('TagsSheet UI Widget Tests', () {
    testWidgets('renders empty tags sheet and displays creation field', (
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
                      showTagsSheet(context: context, repository: repo),
                  child: const Text('Open Tags Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Tags Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Organize and label your memories'), findsOneWidget);
      expect(find.text('New tag name\u2026'), findsOneWidget);
      expect(find.text('No tags created yet'), findsOneWidget);
    });
  });

  group('TagSelectionSheet UI Widget Tests', () {
    testWidgets('renders search field and handles query with creation prompt', (
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
                  onPressed: () => showTagSelectionSheet(
                    context: context,
                    repository: repo,
                    initialSelectedTags: const {},
                  ),
                  child: const Text('Open Tag Selector'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Tag Selector'));
      await tester.pumpAndSettle();

      expect(find.text('Select Tags'), findsOneWidget);
      expect(find.text('Search or create tag\u2026'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Type in search bar
      await tester.enterText(find.byType(TextField), 'Summer');
      await tester.pumpAndSettle();

      expect(find.text('Create "#Summer"'), findsOneWidget);
    });
  });
}
