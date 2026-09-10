import 'package:flutter/material.dart';
import 'package:paper_shaders/paper_shaders.dart';

/// Available shader effects that can be applied to the canvas before sharing.
enum ShareShaderType {
  none(
    label: 'None',
    description: 'No shader applied',
    icon: Icons.block_rounded,
  ),
  flutedGlass(
    label: 'Fluted Glass',
    description: 'Architectural fluted glass with refraction and tactile grain',
    icon: Icons.waves_rounded,
  );

  const ShareShaderType({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;
}

/// Extension methods for friendly labels on Paper Shaders enums.
extension FlutedGlassShapeLabel on FlutedGlassShape {
  String get displayName {
    switch (this) {
      case FlutedGlassShape.lines:
        return 'lines';
      case FlutedGlassShape.linesIrregular:
        return 'linesIrregular';
      case FlutedGlassShape.wave:
        return 'wave';
      case FlutedGlassShape.zigzag:
        return 'zigzag';
      case FlutedGlassShape.pattern:
        return 'pattern';
    }
  }
}

extension FlutedGlassDistortionShapeLabel on FlutedGlassDistortionShape {
  String get displayName {
    switch (this) {
      case FlutedGlassDistortionShape.prism:
        return 'prism';
      case FlutedGlassDistortionShape.lens:
        return 'lens';
      case FlutedGlassDistortionShape.contour:
        return 'contour';
      case FlutedGlassDistortionShape.cascade:
        return 'cascade';
      case FlutedGlassDistortionShape.flat:
        return 'flat';
    }
  }
}

/// Configuration parameters for the Fluted Glass shader.
class FlutedGlassShaderConfig {
  const FlutedGlassShaderConfig({
    this.shadows = 0.25,
    this.highlights = 0.10,
    this.size = 0.52,
    this.shape = FlutedGlassShape.lines,
    this.angle = 12.0,
    this.distortionShape = FlutedGlassDistortionShape.prism,
    this.distortion = 0.15,
    this.shift = 0.00,
    this.stretch = 0.00,
    this.blur = 0.00,
    this.edges = 0.25,
    this.margin = 0.00,
    this.grainMixer = 0.49,
    this.grainOverlay = 0.00,
    this.scale = 0.96,
    this.colorBack = const Color(0x00000000),
    this.colorShadow = const Color(0xFF000000),
    this.colorHighlight = const Color(0xFFFFFFFF),
  });

  final double shadows;
  final double highlights;
  final double size;
  final FlutedGlassShape shape;
  final double angle;
  final FlutedGlassDistortionShape distortionShape;
  final double distortion;
  final double shift;
  final double stretch;
  final double blur;
  final double edges;
  final double margin;
  final double grainMixer;
  final double grainOverlay;
  final double scale;
  final Color colorBack;
  final Color colorShadow;
  final Color colorHighlight;

  /// Default preset matching the author's shader showcase settings.
  static const FlutedGlassShaderConfig presetDefault = FlutedGlassShaderConfig();

  /// Abstract preset with irregular lines and flat distortion.
  static const FlutedGlassShaderConfig presetAbstract = FlutedGlassShaderConfig(
    size: 0.70,
    shadows: 0.00,
    angle: 30.0,
    stretch: 1.00,
    shape: FlutedGlassShape.linesIrregular,
    distortion: 1.00,
    highlights: 0.00,
    distortionShape: FlutedGlassDistortionShape.flat,
    blur: 0.35,
    edges: 0.50,
    grainMixer: 0.20,
    grainOverlay: 0.10,
    scale: 1.20,
  );

  /// Waves preset with fluid contour refraction.
  static const FlutedGlassShaderConfig presetWaves = FlutedGlassShaderConfig(
    size: 0.85,
    shadows: 0.05,
    stretch: 0.90,
    shape: FlutedGlassShape.wave,
    highlights: 0.00,
    distortionShape: FlutedGlassDistortionShape.contour,
    distortion: 0.55,
    blur: 0.10,
    edges: 0.45,
    grainOverlay: 0.05,
    scale: 1.15,
  );

  /// Folds preset with zigzag cascading rhythm and subtle margins.
  static const FlutedGlassShaderConfig presetFolds = FlutedGlassShaderConfig(
    size: 0.40,
    shadows: 0.40,
    distortion: 0.75,
    highlights: 0.00,
    shape: FlutedGlassShape.zigzag,
    distortionShape: FlutedGlassDistortionShape.cascade,
    blur: 0.25,
    edges: 0.45,
    margin: 0.04,
    grainMixer: 0.35,
    scale: 1.00,
  );

  /// Convert Color to #RRGGBBAA hex string for paper_shaders Float4Uniform.
  static String _colorToHex(Color color) {
    final a = (color.a * 255.0).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255.0).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255.0).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255.0).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b$a';
  }

  /// Pack uniforms in the exact order declared by paper_shaders fluted_glass.frag.
  List<ShaderUniform> get uniforms => <ShaderUniform>[
    Float4Uniform.color(_colorToHex(colorBack)),
    Float4Uniform.color(_colorToHex(colorShadow)),
    Float4Uniform.color(_colorToHex(colorHighlight)),
    FloatUniform(size),
    FloatUniform(shadows),
    FloatUniform(angle),
    FloatUniform(stretch),
    FloatUniform(shape.uniformValue),
    FloatUniform(distortion),
    FloatUniform(highlights),
    FloatUniform(distortionShape.uniformValue),
    FloatUniform(shift),
    FloatUniform(blur),
    FloatUniform(edges),
    FloatUniform(margin), // marginLeft
    FloatUniform(margin), // marginRight
    FloatUniform(margin), // marginTop
    FloatUniform(margin), // marginBottom
    FloatUniform(grainMixer),
    FloatUniform(grainOverlay),
  ];

  FlutedGlassShaderConfig copyWith({
    double? shadows,
    double? highlights,
    double? size,
    FlutedGlassShape? shape,
    double? angle,
    FlutedGlassDistortionShape? distortionShape,
    double? distortion,
    double? shift,
    double? stretch,
    double? blur,
    double? edges,
    double? margin,
    double? grainMixer,
    double? grainOverlay,
    double? scale,
    Color? colorBack,
    Color? colorShadow,
    Color? colorHighlight,
  }) {
    return FlutedGlassShaderConfig(
      shadows: shadows ?? this.shadows,
      highlights: highlights ?? this.highlights,
      size: size ?? this.size,
      shape: shape ?? this.shape,
      angle: angle ?? this.angle,
      distortionShape: distortionShape ?? this.distortionShape,
      distortion: distortion ?? this.distortion,
      shift: shift ?? this.shift,
      stretch: stretch ?? this.stretch,
      blur: blur ?? this.blur,
      edges: edges ?? this.edges,
      margin: margin ?? this.margin,
      grainMixer: grainMixer ?? this.grainMixer,
      grainOverlay: grainOverlay ?? this.grainOverlay,
      scale: scale ?? this.scale,
      colorBack: colorBack ?? this.colorBack,
      colorShadow: colorShadow ?? this.colorShadow,
      colorHighlight: colorHighlight ?? this.colorHighlight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlutedGlassShaderConfig &&
        other.shadows == shadows &&
        other.highlights == highlights &&
        other.size == size &&
        other.shape == shape &&
        other.angle == angle &&
        other.distortionShape == distortionShape &&
        other.distortion == distortion &&
        other.shift == shift &&
        other.stretch == stretch &&
        other.blur == blur &&
        other.edges == edges &&
        other.margin == margin &&
        other.grainMixer == grainMixer &&
        other.grainOverlay == grainOverlay &&
        other.scale == scale &&
        other.colorBack == colorBack &&
        other.colorShadow == colorShadow &&
        other.colorHighlight == colorHighlight;
  }

  @override
  int get hashCode => Object.hashAll([
    shadows,
    highlights,
    size,
    shape,
    angle,
    distortionShape,
    distortion,
    shift,
    stretch,
    blur,
    edges,
    margin,
    grainMixer,
    grainOverlay,
    scale,
    colorBack,
    colorShadow,
    colorHighlight,
  ]);
}

/// Overall shader configuration for the share studio canvas.
class ShareShaderSettings {
  const ShareShaderSettings({
    this.type = ShareShaderType.none,
    this.flutedGlass = const FlutedGlassShaderConfig(),
  });

  final ShareShaderType type;
  final FlutedGlassShaderConfig flutedGlass;

  bool get isEnabled => type != ShareShaderType.none;

  ShareShaderSettings copyWith({
    ShareShaderType? type,
    FlutedGlassShaderConfig? flutedGlass,
  }) {
    return ShareShaderSettings(
      type: type ?? this.type,
      flutedGlass: flutedGlass ?? this.flutedGlass,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShareShaderSettings &&
        other.type == type &&
        other.flutedGlass == flutedGlass;
  }

  @override
  int get hashCode => Object.hash(type, flutedGlass);
}
