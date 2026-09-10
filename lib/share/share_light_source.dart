import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Available ambient and specular color tones for the share light source.
enum ShareLightTone {
  studioWhite(
    label: 'Studio White',
    color: Color(0xFFFFFFFF),
    icon: Icons.light_mode_rounded,
  ),
  warmGold(
    label: 'Warm Sun',
    color: Color(0xFFFFD59E),
    icon: Icons.wb_sunny_rounded,
  ),
  sunsetCoral(
    label: 'Sunset Glow',
    color: Color(0xFFFF9E79),
    icon: Icons.wb_twilight_rounded,
  ),
  neonCyan(
    label: 'Cyber Cyan',
    color: Color(0xFF64FFDA),
    icon: Icons.fluorescent_rounded,
  ),
  lavenderMoon(
    label: 'Moonlit Violet',
    color: Color(0xFFE1BEE7),
    icon: Icons.nightlight_round,
  );

  const ShareLightTone({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

/// Represents the invisible light source placed on the Share Studio canvas.
///
/// Computes specular highlights, directional drop shadows, and reflection vectors
/// for stickers relative to its position on the canvas.
class ShareLightSource {
  const ShareLightSource({
    required this.position,
    this.intensity = 0.85,
    this.height = 140.0,
    this.tone = ShareLightTone.studioWhite,
    this.isReticleVisible = true,
    this.isEnabled = false,
  });

  /// 2D coordinates of the light on the canvas.
  final Offset position;

  /// Brightness/strength of the light (0.2 to 1.0).
  final double intensity;

  /// Virtual Z-height above the canvas (50.0 to 300.0).
  /// Influences shadow elongation, softness, and specular spread.
  final double height;

  /// Ambient and specular color tone.
  final ShareLightTone tone;

  /// Whether the user-interactive reticle/halo is visible while positioning.
  /// When false, the light source is completely invisible while still illuminating stickers.
  final bool isReticleVisible;

  /// Whether lighting is active. If false, stickers appear flat without specular reflections.
  final bool isEnabled;

  ShareLightSource copyWith({
    Offset? position,
    double? intensity,
    double? height,
    ShareLightTone? tone,
    bool? isReticleVisible,
    bool? isEnabled,
  }) {
    return ShareLightSource(
      position: position ?? this.position,
      intensity: intensity ?? this.intensity,
      height: height ?? this.height,
      tone: tone ?? this.tone,
      isReticleVisible: isReticleVisible ?? this.isReticleVisible,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// Calculates the relative normalized specular highlight center on a sticker [-1..1].
  Alignment specularOffset(Offset stickerCenter, double stickerRotation) {
    final dx = position.dx - stickerCenter.dx;
    final dy = position.dy - stickerCenter.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < 1e-4) {
      return Alignment.center;
    }

    final lightAngle = math.atan2(dy, dx);
    final relAngle = lightAngle - stickerRotation;

    // Shift toward light source, clamped within sticker surface bounds.
    final shift = (dist / (dist + height)).clamp(0.0, 0.75);
    final nx = math.cos(relAngle) * shift;
    final ny = math.sin(relAngle) * shift;

    return Alignment(nx.clamp(-0.85, 0.85), ny.clamp(-0.85, 0.85));
  }

  /// Distance and angle falloff for specular shine intensity (0.1 to 1.0).
  double specularIntensityFor(Offset stickerCenter) {
    final dx = position.dx - stickerCenter.dx;
    final dy = position.dy - stickerCenter.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    final maxDistance = 1400.0;
    final distanceFactor = (1.0 - (dist / maxDistance)).clamp(0.1, 1.0);
    return (intensity * distanceFactor).clamp(0.05, 1.0);
  }

  /// Directional shadow offset cast opposite from the light source.
  Offset shadowOffsetFor(Offset stickerCenter) {
    final dx = stickerCenter.dx - position.dx;
    final dy = stickerCenter.dy - position.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < 1e-4) {
      return const Offset(0, 3);
    }

    // Shadow extends further when light is low/close, and tightens when light is high.
    final length = (18.0 * (1.0 + (dist / (height * 2.5)))).clamp(4.0, 32.0);
    final dirX = dx / dist;
    final dirY = dy / dist;

    return Offset(dirX * length, dirY * length);
  }

  /// Shadow blur radius based on distance and light height.
  double shadowBlurFor(Offset stickerCenter) {
    final dx = position.dx - stickerCenter.dx;
    final dy = position.dy - stickerCenter.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    final blur = (8.0 + (dist / 80.0) + (height / 35.0)).clamp(6.0, 28.0);
    return blur;
  }

  /// Angle of light incidence relative to sticker rotation in radians.
  double relativeAngleFor(Offset stickerCenter, double stickerRotation) {
    final dx = position.dx - stickerCenter.dx;
    final dy = position.dy - stickerCenter.dy;
    return math.atan2(dy, dx) - stickerRotation;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareLightSource &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          intensity == other.intensity &&
          height == other.height &&
          tone == other.tone &&
          isReticleVisible == other.isReticleVisible &&
          isEnabled == other.isEnabled;

  @override
  int get hashCode => Object.hash(
        position,
        intensity,
        height,
        tone,
        isReticleVisible,
        isEnabled,
      );
}
