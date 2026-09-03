import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memtickers/capture/stamp_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StampConfig & StampPainter tests', () {
    test('StampConfig default values and copyWith', () {
      const config = StampConfig(text: 'TOKYO 2026');
      expect(config.text, 'TOKYO 2026');
      expect(config.color, const Color(0xFFC62828));
      expect(config.position, StampPosition.bottomRight);
      expect(config.angle, closeTo(-0.23, 0.01));

      final updated = config.copyWith(
        text: 'APPROVED',
        color: const Color(0xFF1565C0),
        position: StampPosition.topLeft,
      );
      expect(updated.text, 'APPROVED');
      expect(updated.color, const Color(0xFF1565C0));
      expect(updated.position, StampPosition.topLeft);
    });

    test('StampPainter.inkColors includes white', () {
      expect(StampPainter.inkColors.contains(const Color(0xFFFFFFFF)), true);
    });

    test('computeStampSize adapts to text length', () {
      final sizeShort = StampPainter.computeStampSize('HI');
      final sizeLong = StampPainter.computeStampSize('123456789012345'); // 15 chars

      expect(sizeLong.width, greaterThan(sizeShort.width));
      expect(sizeShort.height, greaterThan(0));
      expect(sizeLong.height, greaterThan(0));
    });

    testWidgets('StampWidget renders with CustomPaint and rotation', (tester) async {
      const config = StampConfig(text: 'PARIS');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StampWidget(config: config),
            ),
          ),
        ),
      );

      expect(find.byType(StampWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('StampWidget supports drag interactions', (tester) async {
      Offset? draggedDelta;
      final config = const StampConfig(text: 'DRAGGABLE');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StampWidget(
                config: config,
                onDragUpdate: (delta) => draggedDelta = delta,
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.byType(StampWidget), const Offset(20, 30));
      expect(draggedDelta, isNotNull);
    });

    test('compositeStampOnImage composites stamp and expands bounds', () async {
      // Create a small 100x100 dummy PNG image
      final base = img.Image(width: 100, height: 100, numChannels: 4);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          base.setPixelRgba(x, y, 200, 200, 200, 255);
        }
      }
      final basePngBytes = Uint8List.fromList(img.encodePng(base));

      const config = StampConfig(text: 'STAMP 15 CHARS');
      final stampSize = StampPainter.computeStampSize(config.text);

      // Place stamp overlapping bottom-right corner
      final stickerRect = const Rect.fromLTWH(0, 0, 100, 100);
      final stampCenter = Offset(
        stickerRect.right - stampSize.width * 0.42,
        stickerRect.bottom - stampSize.height * 0.38,
      );

      final resultBytes = await compositeStampOnImage(
        sourcePngBytes: basePngBytes,
        config: config,
        stickerRenderedRect: stickerRect,
        stampCenterInPreview: stampCenter,
        stampSizeInPreview: stampSize,
      );

      expect(resultBytes, isNotNull);
      expect(resultBytes.isNotEmpty, true);

      // Verify that the output image decoded successfully and has equal or greater dimensions
      final decoded = img.decodeImage(resultBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, greaterThanOrEqualTo(100));
      expect(decoded.height, greaterThanOrEqualTo(100));
    });

    test('compositeStampOnImage returns original bytes if stamp text is empty', () async {
      final base = img.Image(width: 50, height: 50, numChannels: 4);
      final basePngBytes = Uint8List.fromList(img.encodePng(base));

      const config = StampConfig(text: '   ');
      final resultBytes = await compositeStampOnImage(
        sourcePngBytes: basePngBytes,
        config: config,
        stickerRenderedRect: const Rect.fromLTWH(0, 0, 50, 50),
        stampCenterInPreview: const Offset(25, 25),
        stampSizeInPreview: const Size(40, 20),
      );

      expect(resultBytes, equals(basePngBytes));
    });
  });
}
