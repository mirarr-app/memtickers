import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/data/sticker_board.dart';
import 'package:memtickers/data/sticker_repository.dart';
import 'package:memtickers/share/share_canvas_shader_painter.dart';
import 'package:memtickers/share/share_shader_config.dart';
import 'package:memtickers/share/share_shader_controls_sheet.dart';
import 'package:memtickers/share/share_studio_page.dart';
import 'package:paper_shaders/paper_shaders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutedGlassShaderConfig unit tests', () {
    test('Default configuration matches screenshot values', () {
      const config = FlutedGlassShaderConfig.presetDefault;
      expect(config.shadows, 0.25);
      expect(config.highlights, 0.10);
      expect(config.size, 0.52);
      expect(config.shape, FlutedGlassShape.lines);
      expect(config.angle, 12.0);
      expect(config.distortionShape, FlutedGlassDistortionShape.prism);
      expect(config.distortion, 0.15);
      expect(config.shift, 0.00);
      expect(config.stretch, 0.00);
      expect(config.blur, 0.00);
      expect(config.edges, 0.25);
      expect(config.margin, 0.00);
      expect(config.grainMixer, 0.49);
      expect(config.grainOverlay, 0.00);
      expect(config.scale, 0.96);
    });

    test('Presets provide distinct valid configurations', () {
      expect(FlutedGlassShaderConfig.presetWaves.shape, FlutedGlassShape.wave);
      expect(FlutedGlassShaderConfig.presetWaves.distortionShape,
          FlutedGlassDistortionShape.lens);

      expect(FlutedGlassShaderConfig.presetAbstract.shape,
          FlutedGlassShape.linesIrregular);
      expect(FlutedGlassShaderConfig.presetAbstract.distortionShape,
          FlutedGlassDistortionShape.cascade);

      expect(FlutedGlassShaderConfig.presetFolds.shape, FlutedGlassShape.zigzag);
      expect(FlutedGlassShaderConfig.presetFolds.distortionShape,
          FlutedGlassDistortionShape.flat);
    });

    test('uniforms packing matches fluted_glass.frag specification', () {
      const config = FlutedGlassShaderConfig();
      final uniforms = config.uniforms;

      // 3 colors (colorBack, colorShadow, colorHighlight) + 17 scalar floats = 20 uniforms
      expect(uniforms.length, 20);
      expect(uniforms[0], isA<Float4Uniform>());
      expect(uniforms[1], isA<Float4Uniform>());
      expect(uniforms[2], isA<Float4Uniform>());
      for (int i = 3; i < 20; i++) {
        expect(uniforms[i], isA<FloatUniform>());
      }
    });

    test('copyWith updates individual fields while preserving others', () {
      const config = FlutedGlassShaderConfig();
      final updated = config.copyWith(
        shadows: 0.8,
        shape: FlutedGlassShape.zigzag,
        scale: 1.5,
      );

      expect(updated.shadows, 0.8);
      expect(updated.shape, FlutedGlassShape.zigzag);
      expect(updated.scale, 1.5);
      expect(updated.highlights, config.highlights);
      expect(updated.size, config.size);
    });

    test('equality and hashCode contract', () {
      const a = FlutedGlassShaderConfig(shadows: 0.3);
      const b = FlutedGlassShaderConfig(shadows: 0.3);
      const c = FlutedGlassShaderConfig(shadows: 0.5);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('All Shaders Config unit tests', () {
    test('HalftoneDotsShaderConfig has valid defaults, presets, and uniforms', () {
      const config = HalftoneDotsShaderConfig.presetDefault;
      expect(config.radius, 1.25);
      expect(config.contrast, 0.4);
      expect(config.size, 0.5);
      expect(config.uniforms.isNotEmpty, isTrue);

      expect(HalftoneDotsShaderConfig.presetLedScreen.grid, HalftoneDotsGrid.square);
      expect(HalftoneDotsShaderConfig.presetMosaic.originalColors, isTrue);
      expect(HalftoneDotsShaderConfig.presetRoundSquare.inverted, isTrue);
    });

    test('HalftoneCmykShaderConfig has valid defaults, presets, and uniforms', () {
      const config = HalftoneCmykShaderConfig.presetDefault;
      expect(config.size, 0.2);
      expect(config.contrast, 1.0);
      expect(config.uniforms.isNotEmpty, isTrue);

      expect(HalftoneCmykShaderConfig.presetSharpDots.type, HalftoneCmykType.dots);
      expect(HalftoneCmykShaderConfig.presetVintagePrint.type, HalftoneCmykType.ink);
    });

    test('ImageDitheringShaderConfig has valid defaults, presets, and uniforms', () {
      const config = ImageDitheringShaderConfig.presetDefault;
      expect(config.type, ImageDitheringType.bayer8x8);
      expect(config.size, 2.0);
      expect(config.uniforms.isNotEmpty, isTrue);

      expect(ImageDitheringShaderConfig.presetNoise.type, ImageDitheringType.random);
      expect(ImageDitheringShaderConfig.presetRetroBayer.type, ImageDitheringType.bayer2x2);
      expect(ImageDitheringShaderConfig.presetOriginalColors.originalColors, isTrue);
    });

    test('PaperTextureShaderConfig has valid defaults, presets, and uniforms', () {
      const config = PaperTextureShaderConfig.presetDefault;
      expect(config.contrast, 0.3);
      expect(config.roughness, 0.4);
      expect(config.folds, 0.65);
      expect(config.uniforms.isNotEmpty, isTrue);

      expect(PaperTextureShaderConfig.presetCardboard.roughness, 0.6);
      expect(PaperTextureShaderConfig.presetFoldedNote.foldCount, 4.0);
    });

    test('HeatmapShaderConfig has valid defaults, presets, and uniforms', () {
      const config = HeatmapShaderConfig.presetDefault;
      expect(config.innerGlow, 0.5);
      expect(config.contour, 0.5);
      expect(config.uniforms.isNotEmpty, isTrue);

      expect(HeatmapShaderConfig.presetSepia.noise, 0.75);
      expect(HeatmapShaderConfig.presetCyberThermal.contour, 0.8);
    });

    test('WaterShaderConfig has valid defaults, presets, and uniforms', () {
      const config = WaterShaderConfig.presetDefault;
      expect(config.highlights, 0.07);
      expect(config.layering, 0.5);
      expect(config.waves, 0.3);
      expect(config.uniforms.isNotEmpty, isTrue);

      expect(WaterShaderConfig.presetSlowMo.caustic, 0.2);
      expect(WaterShaderConfig.presetAbstract.edges, 1.0);
    });

    test('LiquidMetalShaderConfig has valid defaults, presets, and uniforms', () {
      const config = LiquidMetalShaderConfig.presetDefault;
      expect(config.softness, 0.1);
      expect(config.distortion, 0.07);
      expect(config.uniforms.isNotEmpty, isTrue);

      expect(LiquidMetalShaderConfig.presetChrome.shape, LiquidMetalShape.none);
      expect(LiquidMetalShaderConfig.presetMoltenRipples.shape, LiquidMetalShape.circle);
    });

    test('GemSmokeShaderConfig has valid defaults, presets, and uniforms', () {
      const config = GemSmokeShaderConfig.presetDefault;
      expect(config.innerDistortion, 0.8);
      expect(config.outerDistortion, 0.6);
      expect(config.uniforms.isNotEmpty, isTrue);

      expect(GemSmokeShaderConfig.presetFire.innerDistortion, 0.6);
      expect(GemSmokeShaderConfig.presetFluorescent.innerDistortion, 1.0);
    });
  });

  group('ShareShaderSettings unit tests', () {
    test('default settings has type none and is disabled', () {
      const settings = ShareShaderSettings();
      expect(settings.type, ShareShaderType.none);
      expect(settings.isEnabled, isFalse);
    });

    test('enabling fluted glass marks isEnabled true', () {
      const settings = ShareShaderSettings(type: ShareShaderType.flutedGlass);
      expect(settings.isEnabled, isTrue);
      expect(settings.type, ShareShaderType.flutedGlass);
    });
  });

  group('ShareCanvasShaderPainter unit tests', () {
    test('shouldRepaint returns true when settings or program changes', () async {
      final painter1 = ShareCanvasShaderPainter(
        settings: const ShareShaderSettings(),
      );
      final painter2 = ShareCanvasShaderPainter(
        settings: const ShareShaderSettings(type: ShareShaderType.flutedGlass),
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
      expect(painter1.shouldRepaint(painter1), isFalse);
    });
  });

  group('ShareStudioPage Shaders widget tests', () {
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
      repo.populateForTesting(
        boards: [board],
        stickers: [sticker1],
        activeBoardId: 'board-main',
      );
    });

    testWidgets('Shaders section chip exists and opens shader controls panel',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShareStudioPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Shaders filter chip in bottom toolbar
      final shadersChip = find.text('Shaders');
      expect(shadersChip, findsOneWidget);

      // Tap Shaders chip
      await tester.tap(shadersChip);
      await tester.pumpAndSettle();

      // Verify Shaders controls panel opened
      expect(find.text('Shaders (Active)'), findsOneWidget);
      expect(find.text('Shaders'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Fluted Glass'), findsOneWidget);
    });

    testWidgets('Toggling Fluted Glass displays customization controls and presets',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShareStudioPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Shaders chip
      await tester.tap(find.text('Shaders'));
      await tester.pumpAndSettle();

      // Tap "Fluted Glass" in segmented button
      await tester.tap(find.text('Fluted Glass'));
      await tester.pumpAndSettle();

      // Verify preset chips appear
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Waves'), findsOneWidget);
      expect(find.text('Abstract'), findsOneWidget);
      expect(find.text('Folds'), findsOneWidget);

      // Verify screenshot parameters are present
      expect(find.text('shadows'), findsOneWidget);
      expect(find.text('highlights'), findsOneWidget);
      expect(find.text('size'), findsOneWidget);
      expect(find.text('shape'), findsOneWidget);
      expect(find.text('angle'), findsOneWidget);

      // Drag ListView to reveal lower controls
      await tester.drag(find.byType(ListView).last, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(find.text('distortion'), findsOneWidget);

      // Tap a preset chip
      await tester.tap(find.text('Waves'));
      await tester.pumpAndSettle();

      // Tap Reset to default button
      final resetButton = find.byTooltip('Reset to default');
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Turn Off shader
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();

      // Controls are hidden when Off
      expect(find.text('shadows'), findsNothing);
    });

    testWidgets('ShareShaderControlsSheet lays out without overflow at 360px and 320px widths',
        (tester) async {
      final settings = const ShareShaderSettings(
        type: ShareShaderType.flutedGlass,
      );

      for (final width in [360.0, 320.0]) {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        FlutterErrorDetails? caughtDetails;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtDetails = details;
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShareShaderControlsSheet(
                settings: settings,
                onSettingsChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = oldOnError;

        expect(caughtDetails, isNull);
        expect(find.text('Shaders: Fluted Glass'), findsOneWidget);
        expect(find.text('Fluted Glass'), findsOneWidget);
      }
    });

    testWidgets('Switching shader types shows respective controls and presets',
        (tester) async {
      var currentSettings = const ShareShaderSettings(
        type: ShareShaderType.halftoneDots,
      );

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: ShareShaderControlsSheet(
                  settings: currentSettings,
                  onSettingsChanged: (s) {
                    setState(() {
                      currentSettings = s;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Halftone dots controls
      expect(find.text('radius'), findsOneWidget);
      expect(find.text('contrast'), findsOneWidget);
      expect(find.text('LED screen'), findsOneWidget);

      final typeSelectorScrollable = find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      );

      // Switch to Water
      await tester.scrollUntilVisible(
        find.text('Water'),
        150.0,
        scrollable: typeSelectorScrollable,
      );
      await tester.ensureVisible(find.text('Water'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();

      expect(find.text('highlights'), findsOneWidget);
      expect(find.text('waves'), findsOneWidget);
      expect(find.text('Slow-mo'), findsOneWidget);

      // Switch to Dithering
      await tester.scrollUntilVisible(
        find.text('Dithering'),
        150.0,
        scrollable: typeSelectorScrollable,
      );
      await tester.ensureVisible(find.text('Dithering'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dithering'));
      await tester.pumpAndSettle();

      expect(find.text('pixelSize'), findsOneWidget);
      expect(find.text('colorSteps'), findsOneWidget);
      expect(find.text('Noise (1-bit)'), findsOneWidget);

      // Switch to Paper Texture
      await tester.scrollUntilVisible(
        find.text('Paper Texture'),
        150.0,
        scrollable: typeSelectorScrollable,
      );
      await tester.ensureVisible(find.text('Paper Texture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paper Texture'));
      await tester.pumpAndSettle();

      expect(find.text('roughness'), findsOneWidget);
      expect(find.text('crumples'), findsOneWidget);
      expect(find.text('Cardboard'), findsOneWidget);
    });
  });
}
