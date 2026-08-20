/// Configuration adjustments applied to newly generated stickers when saved.
class StickerSettings {
  const StickerSettings({
    this.saturation = 1.0,
    this.brightness = 1.0,
  });

  /// Saturation multiplier:
  /// - 1.0: Original/natural saturation
  /// - < 1.0: Reduced saturation (0.0 is grayscale)
  /// - > 1.0: Boosted saturation (e.g. 1.5 = +50%)
  final double saturation;

  /// Brightness multiplier:
  /// - 1.0: Original/natural brightness
  /// - < 1.0: Reduced brightness (darker)
  /// - > 1.0: Boosted brightness (lighter)
  final double brightness;

  bool get isDefault =>
      (saturation - 1.0).abs() < 0.001 && (brightness - 1.0).abs() < 0.001;

  StickerSettings copyWith({
    double? saturation,
    double? brightness,
  }) {
    return StickerSettings(
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'saturation': saturation,
      'brightness': brightness,
    };
  }

  factory StickerSettings.fromMap(Map<String, dynamic> map) {
    return StickerSettings(
      saturation: (map['saturation'] as num?)?.toDouble() ?? 1.0,
      brightness: (map['brightness'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
