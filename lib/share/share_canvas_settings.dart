import 'package:flutter/material.dart';

/// Available aspect ratio framing presets for sharing.
enum ShareAspectRatio {
  free(
    label: 'Free / Fill',
    ratio: null,
    icon: Icons.aspect_ratio_rounded,
  ),
  story(
    label: '9:16 Story',
    ratio: 9.0 / 16.0,
    icon: Icons.stay_current_portrait_rounded,
  ),
  square(
    label: '1:1 Square',
    ratio: 1.0,
    icon: Icons.crop_square_rounded,
  ),
  portrait(
    label: '4:5 Post',
    ratio: 4.0 / 5.0,
    icon: Icons.crop_portrait_rounded,
  ),
  landscape(
    label: '16:9 Banner',
    ratio: 16.0 / 9.0,
    icon: Icons.crop_16_9_rounded,
  );

  const ShareAspectRatio({
    required this.label,
    required this.ratio,
    required this.icon,
  });

  final String label;
  final double? ratio;
  final IconData icon;
}

/// Artistic studio background styles for the snapshot canvas.
enum ShareBackgroundStyle {
  studioNoir(
    label: 'Studio Noir',
    description: 'Moody charcoal backdrop with atmospheric radial spotlight',
    icon: Icons.dark_mode_rounded,
  ),
  craftPaper(
    label: 'Craft Paper',
    description: 'Warm natural parchment tone with subtle grain',
    icon: Icons.note_rounded,
  ),
  minimalSurface(
    label: 'Minimal M3',
    description: 'Clean adaptive Material 3 surface elevation',
    icon: Icons.layers_rounded,
  ),
  sunsetPeach(
    label: 'Sunset Glow',
    description: 'Warm peach to vivid sunset gradient',
    icon: Icons.wb_twilight_rounded,
  ),
  midnightNeon(
    label: 'Midnight Neon',
    description: 'Deep purple-blue gradient with cyberpunk aura',
    icon: Icons.nights_stay_rounded,
  ),
  cleanWhite(
    label: 'Pure White',
    description: 'Clean pristine white photo studio ground',
    icon: Icons.crop_square_rounded,
  ),
  transparent(
    label: 'Transparent',
    description: 'Alpha cutout background for stickers only',
    icon: Icons.grid_view_rounded,
  );

  const ShareBackgroundStyle({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;
}

/// Configuration settings for the share canvas.
class ShareCanvasSettings {
  const ShareCanvasSettings({
    this.aspectRatio = ShareAspectRatio.story,
    this.backgroundStyle = ShareBackgroundStyle.studioNoir,
    this.showWatermark = true,
  });

  final ShareAspectRatio aspectRatio;
  final ShareBackgroundStyle backgroundStyle;
  final bool showWatermark;

  ShareCanvasSettings copyWith({
    ShareAspectRatio? aspectRatio,
    ShareBackgroundStyle? backgroundStyle,
    bool? showWatermark,
  }) {
    return ShareCanvasSettings(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      showWatermark: showWatermark ?? this.showWatermark,
    );
  }
}
