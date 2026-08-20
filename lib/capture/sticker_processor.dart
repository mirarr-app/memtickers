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

    final maxDist = borderRadius + 0.5;
    final maxDist2 = (maxDist + 1.0) * (maxDist + 1.0);
    final borderLimit = borderRadius + 1;

    // Buffer to track sub-pixel anti-aliased alpha for vinyl backing
    final backingAlpha = Uint8List(out.width * out.height);

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        if (pixel.a < 32) continue;
        final srcA = pixel.a / 255.0;
        for (var dy = -borderLimit; dy <= borderLimit; dy++) {
          for (var dx = -borderLimit; dx <= borderLimit; dx++) {
            final d2 = (dx * dx + dy * dy).toDouble();
            if (d2 > maxDist2) continue;
            final dist = math.sqrt(d2);
            final coverage = (maxDist - dist).clamp(0.0, 1.0);
            if (coverage <= 0) continue;

            final ox = x + pad + dx;
            final oy = y + pad + dy;
            if (ox < 0 || oy < 0 || ox >= out.width || oy >= out.height) {
              continue;
            }
            final a = (coverage * srcA * 255).round().clamp(0, 255);
            final idx = oy * out.width + ox;
            if (a > backingAlpha[idx]) {
              backingAlpha[idx] = a;
            }
          }
        }
      }
    }

    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final a = backingAlpha[y * out.width + x];
        if (a > 0) {
          out.setPixelRgba(x, y, creamR, creamG, creamB, a);
        }
      }
    }

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        final srcA = pixel.a.toInt();
        if (srcA == 0) continue;
        final ox = x + pad;
        final oy = y + pad;
        if (srcA >= 250) {
          out.setPixelRgba(
            ox,
            oy,
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
            255,
          );
        } else {
          final fgA = srcA / 255.0;
          final bgA = (backingAlpha[oy * out.width + ox] / 255.0) * (1.0 - fgA);
          final finalA = fgA + bgA;
          if (finalA > 0) {
            final r = ((pixel.r * fgA + creamR * bgA) / finalA).round().clamp(0, 255);
            final g = ((pixel.g * fgA + creamG * bgA) / finalA).round().clamp(0, 255);
            final b = ((pixel.b * fgA + creamB * bgA) / finalA).round().clamp(0, 255);
            out.setPixelRgba(
              ox,
              oy,
              r,
              g,
              b,
              (finalA * 255).round().clamp(0, 255),
            );
          }
        }
      }
    }

    return Uint8List.fromList(img.encodePng(out));
  }

  /// Applies saturation and brightness adjustments to a PNG sticker image.
  Future<Uint8List> applyColorAdjustments(
    Uint8List sourceBytes, {
    required double saturation,
    required double brightness,
  }) {
    if ((saturation - 1.0).abs() < 0.001 && (brightness - 1.0).abs() < 0.001) {
      return Future.value(sourceBytes);
    }
    return compute(StickerProcessor.applyColorAdjustmentsSync, (
      bytes: sourceBytes,
      saturation: saturation,
      brightness: brightness,
    ));
  }

  static Uint8List applyColorAdjustmentsSync(
    ({Uint8List bytes, double saturation, double brightness}) args,
  ) {
    final decoded = img.decodeImage(args.bytes);
    if (decoded == null) {
      return args.bytes;
    }
    final adjusted = img.adjustColor(
      decoded,
      saturation: args.saturation,
      brightness: args.brightness,
    );
    return Uint8List.fromList(img.encodePng(adjusted));
  }

  Future<File> writePng(Uint8List bytes, String path) async {
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
