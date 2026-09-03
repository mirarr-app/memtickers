import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:memtickers/capture/dithered_image_view.dart';

Future<ui.Image> _createTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 100, 100),
    Paint()..color = Colors.blue,
  );
  final picture = recorder.endRecording();
  return picture.toImage(100, 100);
}

void main() {
  testWidgets('DitheredImageView renders with test image and child overlay', (
    tester,
  ) async {
    final image = await _createTestImage();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: DitheredImageView(
              image: image,
              child: const Center(
                child: M3ELoadingIndicator(
                  semanticsLabel: 'Cutting out subject',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(DitheredImageView), findsOneWidget);
    expect(find.byType(M3ELoadingIndicator), findsOneWidget);
  });

  testWidgets('AnimatedDitherView scans from clean image to dithered effect', (
    tester,
  ) async {
    final image = await _createTestImage();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: AnimatedDitherView(
              image: image,
              scanDuration: const Duration(milliseconds: 300),
              child: const Center(
                child: M3ELoadingIndicator(
                  semanticsLabel: 'Scanning subject',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Initial frame: clean image is rendered, scan starting
    expect(find.byType(AnimatedDitherView), findsOneWidget);
    expect(find.byType(M3ELoadingIndicator), findsOneWidget);
    expect(find.byType(RawImage), findsOneWidget);

    // Mid-animation: laser scan is active, revealing dither
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(CustomPaint), findsWidgets);

    // Complete animation: scan complete, dither fully revealed, pulsing started
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(DitheredImageView), findsOneWidget);

    // Pump further to verify ambient breathing animation does not error
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AnimatedDitherView), findsOneWidget);
  });
}
