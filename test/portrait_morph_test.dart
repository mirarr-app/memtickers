import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memtickers/capture/portrait_morph_view.dart';

Uint8List _createPngBytes() {
  final image = img.Image(width: 20, height: 20);
  img.fill(image, color: img.ColorRgba8(0, 100, 200, 255));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  testWidgets('PortraitMorphView renders and completes animation', (
    tester,
  ) async {
    final imageABytes = _createPngBytes();
    final imageBBytes = _createPngBytes();

    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: PortraitMorphView(
              imageABytes: imageABytes,
              imageBBytes: imageBBytes,
              autoAnimate: true,
              duration: const Duration(milliseconds: 300),
              onCompleted: () {
                completed = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(PortraitMorphView), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(completed, isTrue);
  });
}
