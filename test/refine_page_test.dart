import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/capture/isnet_cutout.dart';
import 'package:memtickers/capture/sticker_processor.dart';
import 'package:memtickers/capture/sticker_refine_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mirarrapp.memtickers/cutout');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'hasRefineSession':
          return true;
        case 'startRefineSession':
          return {
            'sessionId': 'test-session-123',
            'width': 640,
            'height': 480,
            'workingImagePath': '/tmp/test_working.jpg',
            'overlayPath': '/tmp/test_overlay.png',
            'canUndo': false,
            'canRedo': false,
          };
        case 'applyRefineStroke':
          return {
            'overlayPath': '/tmp/test_overlay.png',
            'canUndo': true,
            'canRedo': false,
          };
        case 'undoRefineStroke':
          return {
            'overlayPath': '/tmp/test_overlay.png',
            'canUndo': false,
            'canRedo': true,
          };
        case 'redoRefineStroke':
          return {
            'overlayPath': '/tmp/test_overlay.png',
            'canUndo': true,
            'canRedo': false,
          };
        case 'resetRefine':
          return {
            'overlayPath': '/tmp/test_overlay.png',
            'canUndo': true,
            'canRedo': false,
          };
        case 'finishRefineSession':
          return {
            'path': '/tmp/test_refined_cropped.png',
            'width': 300,
            'height': 300,
          };
        case 'disposeRefineSession':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('IsnetCutout Refine Session Channel Tests', () {
    test('hasRefineSession returns true', () async {
      final has = await IsnetCutout.hasRefineSession();
      expect(has, isTrue);
    });

    test('startRefineSession parses response correctly', () async {
      final info = await IsnetCutout.startRefineSession();
      expect(info.sessionId, 'test-session-123');
      expect(info.width, 640);
      expect(info.height, 480);
      expect(info.workingImagePath, '/tmp/test_working.jpg');
      expect(info.overlayPath, '/tmp/test_overlay.png');
      expect(info.canUndo, isFalse);
      expect(info.canRedo, isFalse);
    });

    test('applyRefineStroke sends arguments and receives response', () async {
      final stroke = await IsnetCutout.applyRefineStroke(
        sessionId: 'test-session-123',
        points: [100.0, 100.0, 105.0, 105.0],
        radius: 25.0,
        isRestore: true,
        isSmart: true,
      );
      expect(stroke.overlayPath, '/tmp/test_overlay.png');
      expect(stroke.canUndo, isTrue);
      expect(stroke.canRedo, isFalse);
    });

    test('undo, redo, reset, finish work properly', () async {
      final undo = await IsnetCutout.undoRefineStroke('test-session-123');
      expect(undo.canRedo, isTrue);

      final redo = await IsnetCutout.redoRefineStroke('test-session-123');
      expect(redo.canUndo, isTrue);

      final reset = await IsnetCutout.resetRefine('test-session-123');
      expect(reset.canUndo, isTrue);

      final finish = await IsnetCutout.finishRefineSession('test-session-123');
      expect(finish.path, '/tmp/test_refined_cropped.png');
      expect(finish.width, 300);
      expect(finish.height, 300);
    });
  });

  group('StickerRefinePage Widget Tests', () {
    testWidgets('renders top bar buttons and bottom controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StickerRefinePage(
            imagePath: '/tmp/test_working.jpg',
            saturation: 1.0,
            brightness: 1.0,
            processor: StickerProcessor(),
          ),
        ),
      );

      // Initial loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Settle initialization
      await tester.pumpAndSettle();

      // Top bar actions
      expect(find.byTooltip('Cancel'), findsOneWidget);
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Redo'), findsOneWidget);
      expect(find.byTooltip('Reset to AI cutout'), findsOneWidget);
      expect(find.byTooltip('Preview Sticker'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Mode toggles
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Erase'), findsOneWidget);
      expect(find.text('Smart Edge'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Tap Mode toggles
      await tester.tap(find.text('Erase'));
      await tester.pump();
      await tester.tap(find.text('Manual'));
      await tester.pump();

      // Tap Reset Zoom button
      expect(find.byTooltip('Fit to screen'), findsOneWidget);
      await tester.tap(find.byTooltip('Fit to screen'));
      await tester.pump();
    });

    testWidgets('Cancel button dismisses page', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                await Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => StickerRefinePage(
                      saturation: 1.0,
                      brightness: 1.0,
                      processor: StickerProcessor(),
                    ),
                  ),
                );
                popped = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(StickerRefinePage), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(StickerRefinePage), findsNothing);
      expect(popped, isTrue);
    });
  });
}
