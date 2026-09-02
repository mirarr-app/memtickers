/// Configuration adjustments applied to newly generated stickers when saved.
class StickerSettings {
  const StickerSettings({
    this.saturation = 1.0,
    this.brightness = 1.0,
    this.hapticFeedbackEnabled = true,
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

  /// Global toggle for tasteful haptic feedback throughout the application.
  final bool hapticFeedbackEnabled;

  bool get isDefault =>
      (saturation - 1.0).abs() < 0.001 &&
      (brightness - 1.0).abs() < 0.001 &&
      hapticFeedbackEnabled == true;

  StickerSettings copyWith({
    double? saturation,
    double? brightness,
    bool? hapticFeedbackEnabled,
  }) {
    return StickerSettings(
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'saturation': saturation,
      'brightness': brightness,
      'hapticFeedbackEnabled': hapticFeedbackEnabled ? 1 : 0,
    };
  }

  factory StickerSettings.fromMap(Map<String, dynamic> map) {
    final rawHaptic = map['hapticFeedbackEnabled'];
    final bool haptic;
    if (rawHaptic is bool) {
      haptic = rawHaptic;
    } else if (rawHaptic is num) {
      haptic = rawHaptic != 0;
    } else if (rawHaptic is String) {
      haptic = rawHaptic.toLowerCase() == 'true' || rawHaptic == '1';
    } else {
      haptic = true;
    }

    return StickerSettings(
      saturation: (map['saturation'] as num?)?.toDouble() ?? 1.0,
      brightness: (map['brightness'] as num?)?.toDouble() ?? 1.0,
      hapticFeedbackEnabled: haptic,
    );
  }
}
