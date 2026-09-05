import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

enum StampPosition {
  bottomRight,
  bottomLeft,
  topRight,
  topLeft,
  custom,
}

class StampConfig {
  const StampConfig({
    required this.text,
    this.color = const Color(0xFFC62828), // Authentic Rubber Stamp Carmine Red
    this.angle = -0.23, // ~-13.2 degrees hand-stamp angle
    this.position = StampPosition.bottomRight,
    this.customOffset,
    this.date,
  });

  final String text;
  final Color color;
  final double angle;
  final StampPosition position;
  final Offset? customOffset;
  final DateTime? date;

  StampConfig copyWith({
    String? text,
    Color? color,
    double? angle,
    StampPosition? position,
    Offset? customOffset,
    DateTime? date,
  }) {
    return StampConfig(
      text: text ?? this.text,
      color: color ?? this.color,
      angle: angle ?? this.angle,
      position: position ?? this.position,
      customOffset: customOffset ?? this.customOffset,
      date: date ?? this.date,
    );
  }
}

class StampPainter extends CustomPainter {
  const StampPainter({required this.config});

  final StampConfig config;

  static const List<Color> inkColors = [
    Color(0xFFC62828), // Stamp Carmine Red
    Color(0xFF1565C0), // Postal Navy Blue
    Color(0xFF6A1B9A), // Customs Purple
    Color(0xFF2E7D32), // Official Forest Green
    Color(0xFF263238), // Archival Ink Black
    Color(0xFFFFFFFF), // Crisp Chalk White
  ];

  static double _computeFontSize(int textLength) {
    if (textLength <= 6) {
      return 18.5;
    } else if (textLength <= 10) {
      return 17.0;
    } else {
      return 15.5;
    }
  }

  static Size computeStampSize(String rawText, {DateTime? date}) {
    final text = rawText.trim().toUpperCase();
    final headerText = date != null
        ? DateFormat('dd.MM.yy').format(date)
        : '★ OFFICIAL ★';
    final fontSize = _computeFontSize(text.length);

    final headerPainter = TextPainter(
      text: TextSpan(
        text: headerText,
        style: const TextStyle(
          fontSize: 8.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final mainPainter = TextPainter(
      text: TextSpan(
        text: text.isEmpty ? 'STAMP' : text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final contentWidth = math.max(mainPainter.width, headerPainter.width);
    final boxWidth = math.max(96.0, contentWidth + 28.0);
    final boxHeight = math.max(46.0, mainPainter.height + headerPainter.height + 18.0);
    const wavyWidth = 46.0;
    const wavyGap = 7.0;

    headerPainter.dispose();
    mainPainter.dispose();

    return Size(boxWidth + wavyGap + wavyWidth, boxHeight);
  }

  static void paintStamp(
    Canvas canvas,
    Size size, {
    required StampConfig config,
  }) {
    final text = config.text.trim().toUpperCase();
    if (text.isEmpty) return;

    final color = config.color;
    final isWhite = color.toARGB32() == 0xFFFFFFFF;
    final fontSize = _computeFontSize(text.length);
    final headerText = config.date != null
        ? DateFormat('dd.MM.yy').format(config.date!)
        : '★ OFFICIAL ★';

    final headerPainter = TextPainter(
      text: TextSpan(
        text: headerText,
        style: TextStyle(
          color: isWhite
              ? Colors.white.withValues(alpha: 0.85)
              : color.withValues(alpha: 0.80),
          fontSize: 8.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          fontFamily: 'monospace',
          shadows: [
            Shadow(
              color: isWhite
                  ? Colors.black.withValues(alpha: 0.70)
                  : Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0.6, 0.8),
              blurRadius: 1.5,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final mainPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          fontFamily: 'monospace',
          shadows: [
            Shadow(
              color: isWhite
                  ? Colors.black.withValues(alpha: 0.80)
                  : Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0.8, 1.2),
              blurRadius: 2.5,
            ),
            if (isWhite)
              Shadow(
                color: Colors.black.withValues(alpha: 0.50),
                offset: const Offset(-0.6, -0.6),
                blurRadius: 1.5,
              ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final contentWidth = math.max(mainPainter.width, headerPainter.width);
    final boxWidth = math.max(96.0, contentWidth + 28.0);
    final boxHeight = math.max(46.0, mainPainter.height + headerPainter.height + 18.0);

    final outerRect = Rect.fromLTWH(0, 0, boxWidth, boxHeight);
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(5.0),
    );

    // 0. Contrast Tint Backing Wash for legibility against complex photo backgrounds
    final bgWashPaint = Paint()
      ..color = isWhite
          ? Colors.black.withValues(alpha: 0.28)
          : (color.toARGB32() == 0xFF263238
              ? Colors.white.withValues(alpha: 0.25)
              : color.withValues(alpha: 0.12))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(outerRRect, bgWashPaint);

    // If white: draw a dark drop shadow behind the frame strokes so white pops on light surfaces
    if (isWhite) {
      final shadowRRect = outerRRect.shift(const Offset(0.8, 1.2));
      final strokeShadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6;
      canvas.drawRRect(shadowRRect, strokeShadowPaint);
    }

    // 1. Rubber Stamp Outer Frame
    final outerPaint = Paint()
      ..color = isWhite ? Colors.white : color.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawRRect(outerRRect, outerPaint);

    // 2. Rubber Stamp Inner Frame
    final innerRect = outerRect.deflate(3.5);
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(3.0),
    );
    final innerPaint = Paint()
      ..color = isWhite
          ? Colors.white.withValues(alpha: 0.85)
          : color.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRRect(innerRRect, innerPaint);

    // 3. Subtle Decorative Divider
    final dividerY = 5.0 + headerPainter.height + 2.5;
    final dividerPaint = Paint()
      ..color = isWhite
          ? Colors.white.withValues(alpha: 0.50)
          : color.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(10.0, dividerY),
      Offset(boxWidth - 10.0, dividerY),
      dividerPaint,
    );

    // 4. Header / Postmark Label
    final headerX = (boxWidth - headerPainter.width) / 2;
    headerPainter.paint(canvas, Offset(headerX, 4.5));

    // 5. Main Stamp Text
    final mainX = (boxWidth - mainPainter.width) / 2;
    final mainY = dividerY + 3.0;
    mainPainter.paint(canvas, Offset(mainX, mainY));

    // 6. Postal Cancellation Wavy Lines
    final waveStartX = boxWidth + 6.0;
    final waveEndX = size.width;

    final lineYOffsets = [
      boxHeight * 0.26,
      boxHeight * 0.50,
      boxHeight * 0.74,
    ];

    if (isWhite) {
      final waveShadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      for (final lineY in lineYOffsets) {
        final path = Path();
        path.moveTo(waveStartX + 0.8, lineY + 1.0);
        for (double x = waveStartX; x <= waveEndX; x += 1.5) {
          final waveY = lineY + 1.0 + math.sin((x - waveStartX) * 0.32) * 2.8;
          path.lineTo(x + 0.8, waveY);
        }
        canvas.drawPath(path, waveShadowPaint);
      }
    }

    final wavePaint = Paint()
      ..color = isWhite ? Colors.white : color.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (final lineY in lineYOffsets) {
      final path = Path();
      path.moveTo(waveStartX, lineY);
      for (double x = waveStartX; x <= waveEndX; x += 1.5) {
        final waveY = lineY + math.sin((x - waveStartX) * 0.32) * 2.8;
        path.lineTo(x, waveY);
      }
      canvas.drawPath(path, wavePaint);
    }

    // 7. Micro ink-bleed / distress speckles
    final specklePaint = Paint()
      ..color = isWhite
          ? Colors.white.withValues(alpha: 0.40)
          : color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(boxWidth * 0.15, boxHeight * 0.92), 0.7, specklePaint);
    canvas.drawCircle(Offset(boxWidth * 0.82, boxHeight * 0.12), 0.6, specklePaint);
    canvas.drawCircle(Offset(waveStartX + 12, boxHeight * 0.38), 0.5, specklePaint);

    headerPainter.dispose();
    mainPainter.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintStamp(canvas, size, config: config);
  }

  @override
  bool shouldRepaint(covariant StampPainter oldDelegate) {
    return oldDelegate.config.text != config.text ||
        oldDelegate.config.color != config.color ||
        oldDelegate.config.date != config.date;
  }
}

class StampWidget extends StatelessWidget {
  const StampWidget({
    super.key,
    required this.config,
    this.onDragUpdate,
  });

  final StampConfig config;
  final ValueChanged<Offset>? onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final size = StampPainter.computeStampSize(config.text, date: config.date);

    Widget stamp = CustomPaint(
      size: size,
      painter: StampPainter(config: config),
    );

    if (onDragUpdate != null) {
      stamp = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDragUpdate!(details.delta),
        child: stamp,
      );
    }

    return Transform.rotate(
      angle: config.angle,
      alignment: Alignment.center,
      child: stamp,
    );
  }
}

/// Composites the stamp onto the sticker image PNG, expanding the canvas
/// with transparent padding if the stamp extends outside the original sticker.
Future<Uint8List> compositeStampOnImage({
  required Uint8List sourcePngBytes,
  required StampConfig config,
  required Rect stickerRenderedRect,
  required Offset stampCenterInPreview,
  required Size stampSizeInPreview,
}) async {
  if (config.text.trim().isEmpty) return sourcePngBytes;

  final codec = await ui.instantiateImageCodec(sourcePngBytes);
  final frame = await codec.getNextFrame();
  final srcImage = frame.image;
  final srcW = srcImage.width.toDouble();
  final srcH = srcImage.height.toDouble();

  // Compute position and scale relative to original sticker image
  final relCenterX = (stampCenterInPreview.dx - stickerRenderedRect.left) /
      stickerRenderedRect.width;
  final relCenterY = (stampCenterInPreview.dy - stickerRenderedRect.top) /
      stickerRenderedRect.height;
  final scaleFactor = srcW / stickerRenderedRect.width;

  final highResStampCenter = Offset(relCenterX * srcW, relCenterY * srcH);
  final highResStampSize = Size(
    stampSizeInPreview.width * scaleFactor,
    stampSizeInPreview.height * scaleFactor,
  );

  // Calculate rotated bounds of the stamp
  final cosA = math.cos(config.angle).abs();
  final sinA = math.sin(config.angle).abs();
  final halfW = (highResStampSize.width / 2) * cosA +
      (highResStampSize.height / 2) * sinA;
  final halfH = (highResStampSize.width / 2) * sinA +
      (highResStampSize.height / 2) * cosA;

  final minX = highResStampCenter.dx - halfW;
  final maxX = highResStampCenter.dx + halfW;
  final minY = highResStampCenter.dy - halfH;
  final maxY = highResStampCenter.dy + halfH;

  // Compute required padding to prevent clipping of the stamp
  final padLeft = math.max(0.0, -minX + 8.0).ceilToDouble();
  final padRight = math.max(0.0, maxX - srcW + 8.0).ceilToDouble();
  final padTop = math.max(0.0, -minY + 8.0).ceilToDouble();
  final padBottom = math.max(0.0, maxY - srcH + 8.0).ceilToDouble();

  final outW = (srcW + padLeft + padRight).round();
  final outH = (srcH + padTop + padBottom).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
  );

  // 1. Draw source cutout sticker with die-cut vinyl intact
  canvas.drawImage(srcImage, Offset(padLeft, padTop), Paint());

  // 2. Draw stamp at full high resolution
  canvas.save();
  canvas.translate(
    padLeft + highResStampCenter.dx,
    padTop + highResStampCenter.dy,
  );
  canvas.rotate(config.angle);
  canvas.scale(scaleFactor);
  canvas.translate(-stampSizeInPreview.width / 2, -stampSizeInPreview.height / 2);

  StampPainter.paintStamp(
    canvas,
    stampSizeInPreview,
    config: config,
  );
  canvas.restore();

  final picture = recorder.endRecording();
  final outImage = await picture.toImage(outW, outH);
  picture.dispose();
  final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);

  srcImage.dispose();
  outImage.dispose();

  return byteData!.buffer.asUint8List();
}
