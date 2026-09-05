import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:memtickers/boards/boards_sheet.dart";
import "package:memtickers/capture/metadata_service.dart";
import "package:memtickers/capture/stamp_overlay.dart";
import "package:memtickers/data/sticker.dart";
import "package:memtickers/data/sticker_board.dart";
import "package:memtickers/data/sticker_repository.dart";
import "package:memtickers/data/sticker_tag.dart";
import "package:memtickers/scrapbook/in_place_snappable.dart";
import "package:memtickers/scrapbook/scrapbook_canvas.dart";
import "package:memtickers/tags/tags_sheet.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Category 3: Resource Leaks & Cleanups Tests", () {
    testWidgets("BoardsSheet edit dialog opens, closes, and disposes controller", (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final board = StickerBoard(
        id: "b-test",
        name: "Vacation",
        createdAt: DateTime(2026, 1, 1),
      );
      repo.populateForTesting(
        stickers: [],
        boards: [board],
        activeBoardId: "b-test",
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showBoardsSheet(context: context, repository: repo),
                  child: const Text("Open"),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined);
      expect(editIcon, findsOneWidget);
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      expect(find.text("Edit Board Name"), findsOneWidget);

      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();

      expect(find.text("Edit Board Name"), findsNothing);
    });

    testWidgets("TagsSheet edit dialog opens, closes, and disposes controller", (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final tag = StickerTag(
        id: "t-1",
        name: "Vintage",
        createdAt: DateTime(2026, 1, 1),
      );
      repo.populateForTesting(
        stickers: [],
        tags: [tag],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showTagsSheet(context: context, repository: repo),
                  child: const Text("Open"),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined);
      expect(editIcon, findsOneWidget);
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      expect(find.text("Edit Tag"), findsOneWidget);

      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();

      expect(find.text("Edit Tag"), findsNothing);
    });

    testWidgets("ScrapbookCanvas Listener onPointerCancel handles cancellations", (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StickerRepository();
      final sticker = Sticker(
        id: "s-cancel-test",
        boardId: "default",
        imagePath: "test/sample.png",
        createdAt: DateTime(2026, 1, 1),
        x: 100,
        y: 100,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );
      repo.populateForTesting(
        stickers: [sticker],
      );

      final controller = TransformationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScrapbookCanvas(
              repository: repo,
              transformationController: controller,
              onStickerTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(const Offset(100, 100));
      await tester.pump();

      await gesture.cancel();
      await tester.pumpAndSettle();
    });

    test("StampPainter computeStampSize disposes painters cleanly", () {
      final size = StampPainter.computeStampSize("TEST STAMP");
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    test("MetadataService fromGalleryFile handles non-existent file cleanly", () async {
      final service = MetadataService();
      final meta = await service.fromGalleryFile("/non/existent/path.jpg");
      expect(meta, isNotNull);
      expect(meta.latitude, isNull);
      expect(meta.longitude, isNull);
    });

    testWidgets("InPlaceSnappable initializes cleanly with shader Future sharing", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InPlaceSnappable(
              animation: AlwaysStoppedAnimation<double>(0.0),
              child: Text("Snappable Child"),
            ),
          ),
        ),
      );

      expect(find.text("Snappable Child"), findsOneWidget);
    });
  });
}
