import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/data/sticker_board.dart';
import 'package:memtickers/data/sticker_repository.dart';
import 'package:memtickers/scrapbook/scrapbook_page.dart';
import 'package:memtickers/share/share_canvas_settings.dart';
import 'package:memtickers/share/share_light_source.dart';
import 'package:memtickers/share/share_sticker_item.dart';
import 'package:memtickers/share/share_studio_page.dart';
import 'package:memtickers/share/sticker_reflection_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareLightSource unit tests', () {
    test('specularOffset shifts toward light source position', () {
      const light = ShareLightSource(
        position: Offset(100, 50),
        height: 100.0,
      );
      final stickerCenter = const Offset(100, 150);

      // Light is directly above the sticker center (dy = -100, dx = 0)
      final offset = light.specularOffset(stickerCenter, 0.0);
      expect(offset.x, closeTo(0.0, 0.05));
      expect(offset.y, lessThan(0.0)); // Shifted upward toward light
    });

    test('specularOffset centered on sticker produces Alignment.center', () {
      const light = ShareLightSource(
        position: Offset(200, 200),
      );
      final offset = light.specularOffset(const Offset(200, 200), 0.0);
      expect(offset, equals(Alignment.center));
    });

    test('specularIntensity drops with distance from light', () {
      const light = ShareLightSource(
        position: Offset(0, 0),
        intensity: 0.9,
      );
      final near = light.specularIntensityFor(const Offset(50, 50));
      final far = light.specularIntensityFor(const Offset(800, 800));

      expect(near, greaterThan(far));
    });

    test('customizable light intensity affects specular reflection', () {
      const brightLight = ShareLightSource(
        position: Offset(100, 100),
        intensity: 1.0,
      );
      final subtleLight = brightLight.copyWith(intensity: 0.3);

      final point = const Offset(120, 120);
      expect(brightLight.specularIntensityFor(point),
          greaterThan(subtleLight.specularIntensityFor(point)));
      expect(subtleLight.intensity, 0.3);
    });

    test('shadowOffset casts opposite from the light position', () {
      const light = ShareLightSource(
        position: Offset(100, 100),
      );
      // Sticker is to the right and below light
      final stickerCenter = const Offset(200, 200);
      final shadow = light.shadowOffsetFor(stickerCenter);

      // Shadow direction should continue down and right (+dx, +dy)
      expect(shadow.dx, greaterThan(0));
      expect(shadow.dy, greaterThan(0));
    });

    test('invisible light source state maintains calculations', () {
      final lightVisible = const ShareLightSource(
        position: Offset(150, 150),
        isReticleVisible: true,
      );
      final lightInvisible = lightVisible.copyWith(isReticleVisible: false);

      expect(lightInvisible.isReticleVisible, false);
      expect(
        lightInvisible.specularOffset(const Offset(200, 200), 0.0),
        equals(lightVisible.specularOffset(const Offset(200, 200), 0.0)),
      );
      expect(
        lightInvisible.shadowOffsetFor(const Offset(200, 200)),
        equals(lightVisible.shadowOffsetFor(const Offset(200, 200))),
      );
    });

    test('disabled flat lighting state', () {
      final light = const ShareLightSource(
        position: Offset(150, 150),
        isEnabled: true,
      );
      final flat = light.copyWith(isEnabled: false);

      expect(flat.isEnabled, false);
      expect(flat, isNot(equals(light)));
    });

    test('ShareLightTone values have valid labels and colors', () {
      expect(ShareLightTone.values.length, 5);
      for (final tone in ShareLightTone.values) {
        expect(tone.label.isNotEmpty, true);
        expect(tone.color.a, greaterThan(0));
      }
    });
  });

  group('ShareStickerItem & ShareCanvasSettings', () {
    test('ShareStickerItem geometry and copyWith', () {
      final sticker = Sticker(
        id: 's-1',
        imagePath: '/fake/path.png',
        createdAt: DateTime(2026, 1, 1),
        x: 0,
        y: 0,
        rotation: 0,
        scale: 1,
        zIndex: 0,
      );

      final item = ShareStickerItem(
        id: 'item-1',
        sticker: sticker,
        position: const Offset(100, 150),
        scale: 1.2,
        rotation: 0.1,
      );

      expect(item.effectiveWidth, 160.0 * 1.2);
      expect(item.rect.center, const Offset(100, 150));

      final flipped = item.copyWith(isFlipped: true);
      expect(flipped.isFlipped, true);
      expect(flipped.position, item.position);
    });

    test('ShareCanvasSettings presets', () {
      const settings = ShareCanvasSettings();
      expect(settings.aspectRatio, ShareAspectRatio.story);
      expect(settings.backgroundStyle, ShareBackgroundStyle.studioNoir);
      expect(settings.showWatermark, true);

      final updated = settings.copyWith(
        aspectRatio: ShareAspectRatio.square,
        backgroundStyle: ShareBackgroundStyle.cleanWhite,
        showWatermark: false,
      );
      expect(updated.aspectRatio.ratio, 1.0);
      expect(updated.backgroundStyle, ShareBackgroundStyle.cleanWhite);
      expect(updated.showWatermark, false);
    });
  });

  group('Share in Bottom Bar & ShareStudioPage widget tests', () {
    late StickerRepository repo;

    setUp(() {
      repo = StickerRepository();
      final board = StickerBoard(
        id: 'board-main',
        name: 'Memories',
        createdAt: DateTime(2026, 1, 1),
      );
      final sticker1 = Sticker(
        id: 'st-1',
        boardId: 'board-main',
        imagePath: '/tmp/non_existent_1.png',
        createdAt: DateTime(2026, 1, 1),
        x: 100,
        y: 100,
        rotation: 0.0,
        scale: 1.0,
        zIndex: 1,
        placeLabel: 'Tokyo',
        tags: const ['vacation'],
      );
      final sticker2 = Sticker(
        id: 'st-2',
        boardId: 'board-main',
        imagePath: '/tmp/non_existent_2.png',
        createdAt: DateTime(2026, 1, 2),
        x: 200,
        y: 200,
        rotation: 0.05,
        scale: 1.0,
        zIndex: 2,
        placeLabel: 'Kyoto',
        tags: const ['nature'],
      );

      repo.populateForTesting(
        boards: [board],
        stickers: [sticker1, sticker2],
        activeBoardId: 'board-main',
      );
    });

    testWidgets('Scrapbook bottom bar renders Share button and navigates',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScrapbookPage(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Share button exists in bottom floating toolbar
      final shareFinder = find.byTooltip('Share');
      expect(shareFinder, findsOneWidget);

      // Tap Share button
      await tester.tap(shareFinder);
      await tester.pumpAndSettle();

      // Verify ShareStudioPage opened
      expect(find.text('Share Studio'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets(
        'ShareStudioPage has lighting disabled by default, toggles to dynamic lighting',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShareStudioPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share Studio'), findsOneWidget);

      // Verify lighting chip indicates flat mode by default
      final lightingChip = find.text('Lighting (Flat)');
      expect(lightingChip, findsOneWidget);

      // Tap Lighting chip in bottom toolbar
      await tester.tap(lightingChip);
      await tester.pumpAndSettle();

      // Verify lighting is flat by default
      expect(find.text('Lighting: Flat (Disabled)'), findsOneWidget);
      expect(find.text('Enable Light'), findsOneWidget);

      // Enable dynamic lighting
      await tester.tap(find.text('Enable Light'));
      await tester.pumpAndSettle();

      expect(find.text('Disable (Flat)'), findsOneWidget);
      expect(find.text('Make Invisible'), findsOneWidget);

      // Verify customizable intensity slider
      expect(find.text('Intensity'), findsOneWidget);
      final intensitySlider = find.byType(Slider);
      expect(intensitySlider, findsOneWidget);

      // Drag the intensity slider
      await tester.drag(intensitySlider, const Offset(-40, 0));
      await tester.pumpAndSettle();

      // Disable lighting again to return to flat
      await tester.tap(find.text('Disable (Flat)'));
      await tester.pumpAndSettle();

      expect(find.text('Enable Light'), findsOneWidget);
    });

    testWidgets(
        'Tapping sticker allows resizing via outer box handles, rotating via top handle and bottom bar, and removing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShareStudioPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 stickers on canvas'), findsOneWidget);

      // Tap the first sticker on canvas
      final firstSticker = find.byType(StickerReflectionView).first;
      await tester.tap(firstSticker);
      await tester.pumpAndSettle();

      // Verify selected sticker toolbar appeared with "Remove Sticker" and scale & rotate buttons
      final removeButton = find.text('Remove Sticker');
      expect(removeButton, findsOneWidget);
      expect(find.byTooltip('Larger (+)'), findsOneWidget);
      expect(find.byTooltip('Smaller (-)'), findsOneWidget);
      expect(find.byTooltip('Rotate left (-15°)'), findsOneWidget);
      expect(find.byTooltip('Rotate right (+15°)'), findsOneWidget);

      // Verify 4 corner resize handles exist on the outer box
      final resizeHandles = find.byTooltip('Drag to resize sticker');
      expect(resizeHandles, findsNWidgets(4));

      // Verify rotation handle exists on top of outer box
      final rotateHandle = find.byTooltip('Drag to rotate sticker');
      expect(rotateHandle, findsOneWidget);

      // Drag rotation handle to rotate
      await tester.drag(rotateHandle, const Offset(30, 0));
      await tester.pumpAndSettle();

      // Tap rotate buttons in bottom bar
      await tester.tap(find.byTooltip('Rotate left (-15°)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rotate right (+15°)'));
      await tester.pumpAndSettle();

      // Drag a corner resize handle to resize
      await tester.drag(resizeHandles.first, const Offset(30, 30));
      await tester.pumpAndSettle();

      // Tap "Remove Sticker" button in the bottom menu
      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      // Verify one sticker was removed
      expect(find.text('1 stickers on canvas'), findsOneWidget);

      // Select remaining sticker and remove via bottom contextual button
      final remainingSticker = find.byType(StickerReflectionView).first;
      await tester.tap(remainingSticker);
      await tester.pumpAndSettle();

      expect(find.text('Remove Sticker'), findsOneWidget);
      await tester.tap(find.text('Remove Sticker'));
      await tester.pumpAndSettle();

      // Verify all stickers removed
      expect(find.text('0 stickers on canvas'), findsOneWidget);
    });

    testWidgets('Clear all stickers removes everything from canvas',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShareStudioPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 stickers on canvas'), findsOneWidget);

      // Open Auto-Layout popup
      final layoutButton = find.byTooltip('Align & Layout');
      await tester.tap(layoutButton);
      await tester.pumpAndSettle();

      // Tap Clear Canvas
      expect(find.text('Clear Canvas'), findsOneWidget);
      await tester.tap(find.text('Clear Canvas'));
      await tester.pumpAndSettle();

      expect(find.text('0 stickers on canvas'), findsOneWidget);
    });

    testWidgets('ShareStudioPage aspect ratio and backdrop cycle',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShareStudioPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Tap aspect ratio button
      final ratioButton = find.byTooltip('Aspect ratio: 9:16 Story');
      expect(ratioButton, findsOneWidget);
      await tester.tap(ratioButton);
      await tester.pumpAndSettle();

      // It should advance to Square
      expect(find.byTooltip('Aspect ratio: 1:1 Square'), findsOneWidget);

      // Tap backdrop button
      final backdropButton = find.byTooltip('Backdrop: Studio Noir');
      expect(backdropButton, findsOneWidget);
      await tester.tap(backdropButton);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Backdrop: Craft Paper'), findsOneWidget);
    });
  });
}
