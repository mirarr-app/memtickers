import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Background color and artistic surface styles available for sticker boards.
enum BoardBackgroundStyle {
  minimalSurface(
    id: 'minimalSurface',
    label: 'Minimal M3',
    description: 'Clean adaptive Material 3 surface elevation',
    icon: Icons.layers_rounded,
    primaryColor: Color(0xFFF1F5F9),
  ),
  craftPaper(
    id: 'craftPaper',
    label: 'Craft Paper',
    description: 'Warm natural parchment tone with subtle grain',
    icon: Icons.note_rounded,
    primaryColor: Color(0xFFF3E9D9),
  ),
  studioNoir(
    id: 'studioNoir',
    label: 'Studio Noir',
    description: 'Moody charcoal backdrop with atmospheric radial spotlight',
    icon: Icons.dark_mode_rounded,
    primaryColor: Color(0xFF191D24),
  ),
  sunsetPeach(
    id: 'sunsetPeach',
    label: 'Sunset Glow',
    description: 'Warm peach to vivid sunset gradient',
    icon: Icons.wb_twilight_rounded,
    primaryColor: Color(0xFFFF8B7D),
  ),
  midnightNeon(
    id: 'midnightNeon',
    label: 'Midnight Neon',
    description: 'Deep purple-blue gradient with cyberpunk aura',
    icon: Icons.nights_stay_rounded,
    primaryColor: Color(0xFF2E1C4E),
  ),
  cleanWhite(
    id: 'cleanWhite',
    label: 'Pure White',
    description: 'Clean pristine white photo studio ground',
    icon: Icons.crop_square_rounded,
    primaryColor: Color(0xFFFFFFFF),
  );

  const BoardBackgroundStyle({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.primaryColor,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color primaryColor;

  /// Whether this background style has a dark luminance.
  bool get isDark =>
      this == BoardBackgroundStyle.studioNoir ||
      this == BoardBackgroundStyle.midnightNeon;

  static BoardBackgroundStyle fromString(String? raw) {
    if (raw == null) return BoardBackgroundStyle.minimalSurface;
    for (final style in BoardBackgroundStyle.values) {
      if (style.id == raw || style.name == raw) {
        return style;
      }
    }
    return BoardBackgroundStyle.minimalSurface;
  }

  /// Builds the background decoration or widget for an infinite canvas or preview card.
  Widget buildWidget(BuildContext context, {double? width, double? height}) {
    final scheme = Theme.of(context).colorScheme;
    Widget content;
    switch (this) {
      case BoardBackgroundStyle.minimalSurface:
        content = Container(
          color: scheme.surface,
        );
        break;
      case BoardBackgroundStyle.craftPaper:
        content = Container(
          color: const Color(0xFFF3E9D9),
          child: const CustomPaint(
            painter: BoardPaperTexturePainter(),
          ),
        );
        break;
      case BoardBackgroundStyle.studioNoir:
        content = Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.3),
              radius: 1.1,
              colors: [
                Color(0xFF2C3440),
                Color(0xFF191D24),
                Color(0xFF0E1116),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        );
        break;
      case BoardBackgroundStyle.sunsetPeach:
        content = Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFB39A),
                Color(0xFFFF8B7D),
                Color(0xFFEA5455),
              ],
            ),
          ),
        );
        break;
      case BoardBackgroundStyle.midnightNeon:
        content = Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A102F),
                Color(0xFF2E1C4E),
                Color(0xFF4A1E6D),
              ],
            ),
          ),
        );
        break;
      case BoardBackgroundStyle.cleanWhite:
        content = Container(
          color: Colors.white,
        );
        break;
    }

    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: content);
    }
    return content;
  }
}

/// Paper grain texture painter for craft paper board background
class BoardPaperTexturePainter extends CustomPainter {
  const BoardPaperTexturePainter({this.seed = 101});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.brown.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;

    final random = math.Random(seed);
    final count = math.min(1200, (size.width * size.height / 12000).round().clamp(100, 1200));
    for (int i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.6 + random.nextDouble() * 1.6;
      canvas.drawCircle(Offset(x, y), radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPaperTexturePainter oldDelegate) =>
      oldDelegate.seed != seed;
}
