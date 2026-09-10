import 'package:flutter/material.dart';
import '../data/sticker.dart';

/// Represents a sticker placed and manipulated on the Share Studio canvas.
class ShareStickerItem {
  ShareStickerItem({
    required this.id,
    required this.sticker,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.zIndex = 0,
    this.isFlipped = false,
    this.baseSize = 160.0,
  });

  /// Unique identifier for this instance on the share canvas.
  final String id;

  /// Underlying sticker data model.
  final Sticker sticker;

  /// Center position on the canvas.
  Offset position;

  /// Uniform scale multiplier (typically 0.4 to 2.5).
  double scale;

  /// Orientation in radians (-pi to pi).
  double rotation;

  /// Layering index (higher values render on top).
  int zIndex;

  /// Horizontal mirror flip.
  bool isFlipped;

  /// Base dimension before scale is applied.
  final double baseSize;

  /// Effective display size.
  double get effectiveWidth => baseSize * scale;
  double get effectiveHeight => baseSize * scale;

  /// Bounding rect on canvas.
  Rect get rect => Rect.fromCenter(
        center: position,
        width: effectiveWidth,
        height: effectiveHeight,
      );

  ShareStickerItem copyWith({
    String? id,
    Sticker? sticker,
    Offset? position,
    double? scale,
    double? rotation,
    int? zIndex,
    bool? isFlipped,
    double? baseSize,
  }) {
    return ShareStickerItem(
      id: id ?? this.id,
      sticker: sticker ?? this.sticker,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      isFlipped: isFlipped ?? this.isFlipped,
      baseSize: baseSize ?? this.baseSize,
    );
  }
}
