import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:m3e_core/m3e_core.dart';
import 'package:memtickers/capture/sticker_processor.dart';
import 'package:memtickers/data/sticker_repository.dart';
import 'package:memtickers/data/sticker_settings.dart';
import 'package:memtickers/settings/sticker_settings_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StickerSettings model', () {
    test('default values', () {
      const settings = StickerSettings();
      expect(settings.saturation, 1.0);
      expect(settings.brightness, 1.0);
      expect(settings.isDefault, true);
    });

    test('toMap and fromMap', () {
      const settings = StickerSettings(saturation: 1.4, brightness: 0.8);
      final map = settings.toMap();
      expect(map['saturation'], 1.4);
      expect(map['brightness'], 0.8);

      final restored = StickerSettings.fromMap(map);
      expect(restored.saturation, 1.4);
      expect(restored.brightness, 0.8);
      expect(restored.isDefault, false);
    });

    test('copyWith', () {
      const settings = StickerSettings();
      final updated = settings.copyWith(saturation: 1.25);
      expect(updated.saturation, 1.25);
      expect(updated.brightness, 1.0);
    });
  });

  group('StickerProcessor adjustments', () {
    test('applies saturation and brightness without modifying alpha', () async {
      final processor = StickerProcessor();
      final image = img.Image(width: 8, height: 8, numChannels: 4);
      image.setPixelRgba(0, 0, 0, 0, 0, 0); // transparent
      image.setPixelRgba(1, 1, 150, 100, 50, 255); // opaque colored

      final inputBytes = Uint8List.fromList(img.encodePng(image));
      final outputBytes = await processor.applyColorAdjustments(
        inputBytes,
        saturation: 1.5,
        brightness: 1.2,
      );

      final decoded = img.decodeImage(outputBytes)!;
      final transparentPixel = decoded.getPixel(0, 0);
      final coloredPixel = decoded.getPixel(1, 1);

      expect(transparentPixel.a, 0);
      expect(coloredPixel.a, 255);
      // Brightness and saturation adjusted
      expect(coloredPixel.r, isNot(150));
    });

    test('returns same bytes when settings are default (1.0, 1.0)', () async {
      final processor = StickerProcessor();
      final image = img.Image(width: 4, height: 4, numChannels: 4);
      final inputBytes = Uint8List.fromList(img.encodePng(image));

      final outputBytes = await processor.applyColorAdjustments(
        inputBytes,
        saturation: 1.0,
        brightness: 1.0,
      );
      expect(identical(inputBytes, outputBytes), true);
    });
  });

  group('StickerSettingsSheet UI', () {
    testWidgets('renders adjustments sheet and sliders correctly', (tester) async {
      final repo = StickerRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showStickerSettings(context: context, repository: repo),
                  child: const Text('Open Settings'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Sticker Adjustments'), findsOneWidget);
      expect(find.text('Saturation'), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);
      expect(find.byType(M3ESlider), findsNWidgets(2));
      expect(find.text('Reset to default'), findsOneWidget);
      expect(find.text('Save settings'), findsOneWidget);
    });
  });
}
