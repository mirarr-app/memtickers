import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Inflates the subject alpha into a cream vinyl backing, then composites
/// the original cutout on top.
class StickerProcessor {
  static const int borderRadius = 10;
  static const int maxEdge = 1280;

  Future<Uint8List> dieCut(Uint8List sourceBytes) {
    return compute(StickerProcessor.dieCutSync, sourceBytes);
  }

  static Uint8List dieCutSync(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('Could not decode segmented image.');
    }

    var src = decoded;
    final longest = math.max(src.width, src.height);
    if (longest > maxEdge) {
      src = img.copyResize(
        src,
        width: src.width >= src.height ? maxEdge : null,
        height: src.height > src.width ? maxEdge : null,
      );
    }

    final pad = borderRadius;
    final out = img.Image(
      width: src.width + pad * 2,
      height: src.height + pad * 2,
      numChannels: 4,
    );

    const creamR = 250;
    const creamG = 245;
    const creamB = 235;
    final r2 = borderRadius * borderRadius;

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        if (pixel.a < 32) continue;
        for (var dy = -borderRadius; dy <= borderRadius; dy++) {
          for (var dx = -borderRadius; dx <= borderRadius; dx++) {
            if (dx * dx + dy * dy > r2) continue;
            final ox = x + pad + dx;
            final oy = y + pad + dy;
            if (ox < 0 || oy < 0 || ox >= out.width || oy >= out.height) {
              continue;
            }
            out.setPixelRgba(ox, oy, creamR, creamG, creamB, 255);
          }
        }
      }
    }

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        if (pixel.a == 0) continue;
        out.setPixelRgba(
          x + pad,
          y + pad,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          pixel.a.toInt(),
        );
      }
    }

    return Uint8List.fromList(img.encodePng(out));
  }

  Future<File> writePng(Uint8List bytes, String path) async {
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
