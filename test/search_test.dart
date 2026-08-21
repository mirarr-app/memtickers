import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/data/sticker_repository.dart';
import 'package:memtickers/scrapbook/scrapbook_canvas.dart';
import 'package:memtickers/search/search_sheet.dart';
import 'package:memtickers/search/sticker_search_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StickerSearchFilter Tests', () {
    final sticker1 = Sticker(
      id: 's1',
      imagePath: '/path/1.png',
      createdAt: DateTime(2026, 6, 15, 12, 0),
      placeLabel: 'Eiffel Tower, Paris',
      tags: const ['vacation', 'europe'],
      x: 100,
      y: 100,
      rotation: 0,
      scale: 1,
      zIndex: 1,
    );

    final sticker2 = Sticker(
      id: 's2',
      imagePath: '/path/2.png',
      createdAt: DateTime(2026, 7, 20, 15, 30),
      placeLabel: 'Shibuya Crossing, Tokyo',
      tags: const ['vacation', 'asia', 'food'],
      x: 500,
      y: 500,
      rotation: 0.1,
      scale: 1.2,
      zIndex: 2,
    );

    final sticker3 = Sticker(
      id: 's3',
      imagePath: '/path/3.png',
      createdAt: DateTime(2026, 8, 10, 9, 0),
      placeLabel: 'Central Park, New York',
      tags: const ['friends', 'nature'],
      x: 900,
      y: 900,
      rotation: -0.2,
      scale: 0.9,
      zIndex: 3,
    );

    test('empty filter matches all stickers', () {
      const filter = StickerSearchFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.matches(sticker1), isTrue);
      expect(filter.matches(sticker2), isTrue);
      expect(filter.matches(sticker3), isTrue);
    });

    test('filters by tag', () {
      const filter = StickerSearchFilter(tags: ['asia']);
      expect(filter.matches(sticker1), isFalse);
      expect(filter.matches(sticker2), isTrue);
      expect(filter.matches(sticker3), isFalse);

      const multiTagFilter = StickerSearchFilter(tags: ['europe', 'nature']);
      expect(multiTagFilter.matches(sticker1), isTrue);
      expect(multiTagFilter.matches(sticker2), isFalse);
      expect(multiTagFilter.matches(sticker3), isTrue);
    });

    test('filters by date range', () {
      final filter = StickerSearchFilter(
        dateRange: DateTimeRange(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 31),
        ),
      );
      expect(filter.matches(sticker1), isFalse);
      expect(filter.matches(sticker2), isTrue);
      expect(filter.matches(sticker3), isFalse);
    });

    test('filters by location substring (case-insensitive)', () {
      const filter = StickerSearchFilter(locationQuery: 'paris');
      expect(filter.matches(sticker1), isTrue);
      expect(filter.matches(sticker2), isFalse);
      expect(filter.matches(sticker3), isFalse);

      const filterYork = StickerSearchFilter(locationQuery: 'New York');
      expect(filterYork.matches(sticker1), isFalse);
      expect(filterYork.matches(sticker2), isFalse);
      expect(filterYork.matches(sticker3), isTrue);
    });

    test('combines tags, date range, and location (AND logic)', () {
      final combined = StickerSearchFilter(
        tags: const ['vacation'],
        dateRange: DateTimeRange(
          start: DateTime(2026, 6, 1),
          end: DateTime(2026, 6, 30),
        ),
        locationQuery: 'Paris',
      );
      expect(combined.matches(sticker1), isTrue);
      expect(
        combined.matches(sticker2),
        isFalse,
      ); // date and location don't match
      expect(combined.matches(sticker3), isFalse);
    });
  });

  group('BundledStickerLayout Tests', () {
    test('computes bundled positions for stickers', () {
      final stickers = List.generate(
        5,
        (i) => Sticker(
          id: 's$i',
          imagePath: '/path/$i.png',
          createdAt: DateTime.now(),
          x: i * 200.0,
          y: i * 200.0,
          rotation: 0,
          scale: 1,
          zIndex: i,
        ),
      );

      final bundled = BundledStickerLayout.compute(
        stickers: stickers,
        center: const Offset(2000, 2000),
      );

      expect(bundled.length, 5);
      // All items should be centered around (2000, 2000)
      for (final item in bundled) {
        expect(item.position.dx, greaterThan(1500));
        expect(item.position.dx, lessThan(2500));
        expect(item.position.dy, greaterThan(1500));
        expect(item.position.dy, lessThan(2500));
      }
    });

    test('empty stickers returns empty list', () {
      final bundled = BundledStickerLayout.compute(
        stickers: const [],
        center: const Offset(2000, 2000),
      );
      expect(bundled, isEmpty);
    });
  });

  group('SearchSheet UI Widget Tests', () {
    testWidgets(
      'renders search modal with tags, date range, and location sections',
      (tester) async {
        final repo = StickerRepository();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => showStickerSearchSheet(
                      context: context,
                      repository: repo,
                    ),
                    child: const Text('Open Search Sheet'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Search Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Search Memories'), findsOneWidget);
        expect(
          find.text('Filter board by tags, date & location'),
          findsOneWidget,
        );
        expect(find.text('Tags'), findsOneWidget);
        expect(find.text('Date Range'), findsOneWidget);
        expect(find.text('Location'), findsOneWidget);
        expect(find.text('View on Board'), findsOneWidget);
      },
    );
  });
}
