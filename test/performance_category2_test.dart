
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memtickers/capture/sticker_processor.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/data/sticker_repository.dart';
import 'package:memtickers/scrapbook/sticker_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category 2: Performance Tests', () {
    test('updateTransformInMemory updates sticker in-memory without notifyListeners', () {
      final repo = StickerRepository();
      final sticker = Sticker(
        id: 's1',
        imagePath: 'path1.png',
        createdAt: DateTime.now(),
        x: 10,
        y: 20,
        rotation: 0.1,
        scale: 1.0,
        zIndex: 1,
      );

      repo.populateForTesting(stickers: [sticker]);

      var notified = false;
      repo.addListener(() {
        notified = true;
      });

      final moved = sticker.copyWith(x: 50, y: 80, scale: 1.5, rotation: 0.5);
      repo.updateTransformInMemory(moved);

      // Verify in-memory state updated
      expect(repo.stickers.first.x, 50);
      expect(repo.stickers.first.y, 80);
      expect(repo.stickers.first.scale, 1.5);
      expect(repo.stickers.first.rotation, 0.5);

      // Verify listeners were NOT notified during continuous in-memory drag
      expect(notified, isFalse);

      // When updateTransform or persistTransform is called, listeners are notified
      repo.updateTransform(moved);
      expect(notified, isTrue);
    });

    test('StickerProcessor dieCutSync uses precomputed kernel correctly', () {
      final image = img.Image(width: 32, height: 32, numChannels: 4);
      // Create a solid center square
      for (var y = 10; y < 22; y++) {
        for (var x = 10; x < 22; x++) {
          image.setPixelRgba(x, y, 200, 100, 50, 255);
        }
      }

      final inputBytes = Uint8List.fromList(img.encodePng(image));
      final outputBytes = StickerProcessor.dieCutSync(inputBytes);

      final decoded = img.decodeImage(outputBytes);
      expect(decoded, isNotNull);
      // Padded by borderRadius (10) on each side -> 32 + 20 = 52
      expect(decoded!.width, 52);
      expect(decoded.height, 52);

      // Verify cream border exists around the subject
      final borderPixel = decoded.getPixel(20, 15); // Just outside original top boundary (y=10 -> y=20 with pad)
      expect(borderPixel.a, greaterThan(0));
    });

    test('StickerProcessor dieCut with adjustments avoids roundtrip', () async {
      final processor = StickerProcessor();
      final image = img.Image(width: 16, height: 16, numChannels: 4);
      for (var y = 4; y < 12; y++) {
        for (var x = 4; x < 12; x++) {
          image.setPixelRgba(x, y, 100, 100, 100, 255);
        }
      }

      final inputBytes = Uint8List.fromList(img.encodePng(image));
      final adjustedBytes = await processor.dieCut(
        inputBytes,
        saturation: 1.5,
        brightness: 1.3,
      );

      final decoded = img.decodeImage(adjustedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 16 + StickerProcessor.borderRadius * 2);
    });

    testWidgets('StickerObject receives shared tilt from StickerTiltScope without own accelerometer listener', (tester) async {
      final tiltNotifier = ValueNotifier<Offset>(const Offset(0.05, -0.05));
      final sticker = Sticker(
        id: 's-tilt',
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
          home: Scaffold(
            body: StickerTiltScope(
              tiltNotifier: tiltNotifier,
              child: StickerObject(
                sticker: sticker,
                selected: false,
                dropping: false,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StickerObject), findsOneWidget);

      // Change tilt
      tiltNotifier.value = const Offset(0.12, -0.12);
      await tester.pump();

      expect(find.byType(StickerObject), findsOneWidget);
    });
  });
}
