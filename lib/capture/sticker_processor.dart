import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Inflates the subject alpha into a cream vinyl backing, then composites
/// the original cutout on top.
class StickerProcessor {
  static const int borderRadius = 10;
  static const int maxEdge = 1280;

  // Precomputed 23x23 distance/coverage kernel table for border radius (borderRadius + 1 = 11 radius limit)
  static final Float64List _coverageKernel = _buildCoverageKernel();

  static Float64List _buildCoverageKernel() {
    const borderLimit = borderRadius + 1; // 11
    const kernelSize = borderLimit * 2 + 1; // 23
    const maxDist = borderRadius + 0.5; // 10.5
    const maxDist2 = (maxDist + 1.0) * (maxDist + 1.0);
    final table = Float64List(kernelSize * kernelSize);

    for (var dy = -borderLimit; dy <= borderLimit; dy++) {
      final ky = dy + borderLimit;
      for (var dx = -borderLimit; dx <= borderLimit; dx++) {
        final kx = dx + borderLimit;
        final d2 = (dx * dx + dy * dy).toDouble();
        if (d2 <= maxDist2) {
          final dist = math.sqrt(d2);
          final coverage = (maxDist - dist).clamp(0.0, 1.0);
          if (coverage > 0) {
            table[ky * kernelSize + kx] = coverage;
          }
        }
      }
    }
    return table;
  }

  Future<Uint8List> dieCut(
    Uint8List sourceBytes, {
    double saturation = 1.0,
    double brightness = 1.0,
  }) {
    if ((saturation - 1.0).abs() < 0.001 && (brightness - 1.0).abs() < 0.001) {
      return compute(StickerProcessor.dieCutSync, sourceBytes);
    }
    return compute(StickerProcessor.dieCutSync, (
      bytes: sourceBytes,
      saturation: saturation,
      brightness: brightness,
    ));
  }

  static Uint8List dieCutSync(dynamic input) {
    final Uint8List sourceBytes;
    final double saturation;
    final double brightness;

    if (input is Uint8List) {
      sourceBytes = input;
      saturation = 1.0;
      brightness = 1.0;
    } else if (input is ({Uint8List bytes, double saturation, double brightness})) {
      sourceBytes = input.bytes;
      saturation = input.saturation;
      brightness = input.brightness;
    } else {
      throw ArgumentError('Unsupported input type: ${input.runtimeType}');
    }

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

    const borderLimit = borderRadius + 1;
    const kernelSize = 23;
    final coverageKernel = _coverageKernel;

    // Buffer to track sub-pixel anti-aliased alpha for vinyl backing
    final backingAlpha = Uint8List(out.width * out.height);

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        if (pixel.a < 32) continue;
        final srcA = pixel.a / 255.0;

        for (var dy = -borderLimit; dy <= borderLimit; dy++) {
          final oy = y + pad + dy;
          if (oy < 0 || oy >= out.height) continue;
          final outRow = oy * out.width;
          final kRow = (dy + borderLimit) * kernelSize;

          for (var dx = -borderLimit; dx <= borderLimit; dx++) {
            final coverage = coverageKernel[kRow + (dx + borderLimit)];
            if (coverage <= 0) continue;

            final ox = x + pad + dx;
            if (ox < 0 || ox >= out.width) continue;

            final a = (coverage * srcA * 255).round().clamp(0, 255);
            final idx = outRow + ox;
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

    var finalImage = out;
    if ((saturation - 1.0).abs() >= 0.001 || (brightness - 1.0).abs() >= 0.001) {
      finalImage = applyColorAdjustmentsToImage(
        out,
        saturation: saturation,
        brightness: brightness,
      );
    }

    return Uint8List.fromList(img.encodePng(finalImage));
  }

  /// Applies saturation and brightness adjustments directly to an [img.Image] in memory.
  static img.Image applyColorAdjustmentsToImage(
    img.Image image, {
    required double saturation,
    required double brightness,
  }) {
    if ((saturation - 1.0).abs() < 0.001 && (brightness - 1.0).abs() < 0.001) {
      return image;
    }
    return img.adjustColor(
      image,
      saturation: saturation,
      brightness: brightness,
    );
  }

  /// Applies saturation and brightness adjustments to a PNG sticker image or decoded image.
  Future<Uint8List> applyColorAdjustments(
    dynamic source, {
    required double saturation,
    required double brightness,
  }) {
    if (source is img.Image) {
      final adjusted = applyColorAdjustmentsToImage(
        source,
        saturation: saturation,
        brightness: brightness,
      );
      return Future.value(Uint8List.fromList(img.encodePng(adjusted)));
    }
    final sourceBytes = source as Uint8List;
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
    final adjusted = applyColorAdjustmentsToImage(
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
