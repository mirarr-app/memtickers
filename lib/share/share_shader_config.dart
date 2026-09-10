import 'package:flutter/material.dart';
import 'package:paper_shaders/paper_shaders.dart';

/// Available shader effects that can be applied to the canvas before sharing.
enum ShareShaderType {
  none(
    label: 'None',
    description: 'No shader applied',
    icon: Icons.block_rounded,
    assetKey: '',
  ),
  flutedGlass(
    label: 'Fluted Glass',
    description: 'Architectural fluted glass with refraction and tactile grain',
    icon: Icons.waves_rounded,
    assetKey: FlutedGlassShader.assetKey,
  ),
  halftoneDots(
    label: 'Halftone Dots',
    description: 'Vintage comic and screen-printed halftone dot raster',
    icon: Icons.grain_rounded,
    assetKey: HalftoneDotsShader.assetKey,
  ),
  halftoneCmyk(
    label: 'Halftone CMYK',
    description: 'Full 4-color CMYK process print screen with ink bleeding',
    icon: Icons.color_lens_rounded,
    assetKey: HalftoneCmykShader.assetKey,
  ),
  imageDithering(
    label: 'Dithering',
    description: 'Retro 1-bit and ordered Bayer matrix pixel dithering',
    icon: Icons.view_comfy_alt_rounded,
    assetKey: ImageDitheringShader.assetKey,
  ),
  paperTexture(
    label: 'Paper Texture',
    description: 'Authentic parchment, crumpled note, and fibrous paper texture',
    icon: Icons.newspaper_rounded,
    assetKey: PaperTextureShader.assetKey,
  ),
  heatmap(
    label: 'Heatmap',
    description: 'Thermal vision and false-color gradient contouring',
    icon: Icons.local_fire_department_rounded,
    assetKey: HeatmapShader.assetKey,
  ),
  water(
    label: 'Water',
    description: 'Liquid pool ripples, caustic reflections, and fluid surface distortion',
    icon: Icons.water_drop_rounded,
    assetKey: WaterShader.assetKey,
  ),
  liquidMetal(
    label: 'Liquid Metal',
    description: 'Molten chrome and iridescent mercury reflections',
    icon: Icons.lens_blur_rounded,
    assetKey: LiquidMetalShader.assetKey,
  ),
  gemSmoke(
    label: 'Gem Smoke',
    description: 'Ethereal crystal smoke and jewel prism refractions',
    icon: Icons.air_rounded,
    assetKey: GemSmokeShader.assetKey,
  );

  const ShareShaderType({
    required this.label,
    required this.description,
    required this.icon,
    required this.assetKey,
  });

  final String label;
  final String description;
  final IconData icon;
  final String assetKey;
}

/// Extension methods for friendly labels on Paper Shaders enums.
extension FlutedGlassShapeLabel on FlutedGlassShape {
  String get displayName => name;
}

extension FlutedGlassDistortionShapeLabel on FlutedGlassDistortionShape {
  String get displayName => name;
}

extension HalftoneDotsGridLabel on HalftoneDotsGrid {
  String get displayName => name;
}

extension HalftoneDotsTypeLabel on HalftoneDotsType {
  String get displayName => name;
}

extension HalftoneCmykTypeLabel on HalftoneCmykType {
  String get displayName => name;
}

extension ImageDitheringTypeLabel on ImageDitheringType {
  String get displayName => name;
}

extension LiquidMetalShapeLabel on LiquidMetalShape {
  String get displayName => name;
}

extension GemSmokeShapeLabel on GemSmokeShape {
  String get displayName => name;
}

// ---------------------------------------------------------------------------
// 1. Fluted Glass Configuration
// ---------------------------------------------------------------------------

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
    this.sizing = const ShaderSizing.object(fit: ShaderFit.cover),
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
  final ShaderSizing sizing;

  static const presetDefault = FlutedGlassShaderConfig(
    shadows: 0.25,
    highlights: 0.10,
    size: 0.52,
    shape: FlutedGlassShape.lines,
    angle: 12.0,
    distortionShape: FlutedGlassDistortionShape.prism,
    distortion: 0.15,
    shift: 0.00,
    stretch: 0.00,
    blur: 0.00,
    edges: 0.25,
    margin: 0.00,
    grainMixer: 0.49,
    grainOverlay: 0.00,
    scale: 0.96,
  );

  static const presetWaves = FlutedGlassShaderConfig(
    shadows: 0.35,
    highlights: 0.18,
    size: 0.65,
    shape: FlutedGlassShape.wave,
    angle: 25.0,
    distortionShape: FlutedGlassDistortionShape.lens,
    distortion: 0.40,
    shift: 0.10,
    stretch: 0.20,
    blur: 0.15,
    edges: 0.40,
    margin: 0.00,
    grainMixer: 0.30,
    grainOverlay: 0.05,
    scale: 1.0,
  );

  static const presetAbstract = FlutedGlassShaderConfig(
    shadows: 0.15,
    highlights: 0.30,
    size: 0.70,
    shape: FlutedGlassShape.linesIrregular,
    angle: 45.0,
    distortionShape: FlutedGlassDistortionShape.cascade,
    distortion: 0.60,
    shift: 0.25,
    stretch: 0.50,
    blur: 0.30,
    edges: 0.50,
    margin: 0.00,
    grainMixer: 0.20,
    grainOverlay: 0.10,
    scale: 1.0,
  );

  static const presetFolds = FlutedGlassShaderConfig(
    shadows: 0.40,
    highlights: 0.05,
    size: 0.40,
    shape: FlutedGlassShape.zigzag,
    angle: 0.0,
    distortionShape: FlutedGlassDistortionShape.flat,
    distortion: 0.20,
    shift: 0.00,
    stretch: 0.00,
    blur: 0.00,
    edges: 0.60,
    margin: 0.00,
    grainMixer: 0.60,
    grainOverlay: 0.15,
    scale: 0.92,
  );

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
    ShaderSizing? sizing,
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
      sizing: sizing ?? this.sizing,
    );
  }

  FlutedGlassParams toParams() => FlutedGlassParams(
    shadows: shadows,
    highlights: highlights,
    size: size,
    shape: shape,
    angle: angle,
    distortionShape: distortionShape,
    distortion: distortion,
    shift: shift,
    stretch: stretch,
    blur: blur,
    edges: edges,
    marginLeft: margin,
    marginRight: margin,
    marginTop: margin,
    marginBottom: margin,
    grainMixer: grainMixer,
    grainOverlay: grainOverlay,
    sizing: sizing,
  );

  List<ShaderUniform> get uniforms => toParams().uniforms;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlutedGlassShaderConfig &&
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
          other.scale == scale;

  @override
  int get hashCode => Object.hash(
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
      );
}

// ---------------------------------------------------------------------------
// 2. Halftone Dots Configuration
// ---------------------------------------------------------------------------

class HalftoneDotsShaderConfig {
  const HalftoneDotsShaderConfig({
    this.radius = 1.25,
    this.contrast = 0.4,
    this.size = 0.5,
    this.grainMixer = 0.2,
    this.grainOverlay = 0.2,
    this.grainSize = 0.5,
    this.grid = HalftoneDotsGrid.hex,
    this.originalColors = false,
    this.inverted = false,
    this.type = HalftoneDotsType.gooey,
    this.colorFront = '#2b2b2b',
    this.colorBack = '#f2f1e8',
    this.sizing = const ShaderSizing.object(fit: ShaderFit.cover),
  });

  final double radius;
  final double contrast;
  final double size;
  final double grainMixer;
  final double grainOverlay;
  final double grainSize;
  final HalftoneDotsGrid grid;
  final bool originalColors;
  final bool inverted;
  final HalftoneDotsType type;
  final String colorFront;
  final String colorBack;
  final ShaderSizing sizing;

  static const presetDefault = HalftoneDotsShaderConfig();
  static const presetLedScreen = HalftoneDotsShaderConfig(
    colorFront: '#29ff7b',
    colorBack: '#000000',
    radius: 1.5,
    contrast: 0.3,
    grainMixer: 0,
    grainOverlay: 0,
    grid: HalftoneDotsGrid.square,
    type: HalftoneDotsType.soft,
  );
  static const presetMosaic = HalftoneDotsShaderConfig(
    colorFront: '#b2aeae',
    colorBack: '#000000',
    radius: 2,
    contrast: 0.01,
    size: 0.6,
    grainMixer: 0,
    grainOverlay: 0,
    originalColors: true,
    type: HalftoneDotsType.classic,
  );
  static const presetRoundSquare = HalftoneDotsShaderConfig(
    colorFront: '#ff8000',
    colorBack: '#141414',
    radius: 1,
    contrast: 1,
    size: 0.8,
    grainMixer: 0.05,
    grainOverlay: 0.3,
    grid: HalftoneDotsGrid.square,
    inverted: true,
    type: HalftoneDotsType.holes,
  );

  HalftoneDotsShaderConfig copyWith({
    double? radius,
    double? contrast,
    double? size,
    double? grainMixer,
    double? grainOverlay,
    double? grainSize,
    HalftoneDotsGrid? grid,
    bool? originalColors,
    bool? inverted,
    HalftoneDotsType? type,
    String? colorFront,
    String? colorBack,
    ShaderSizing? sizing,
  }) {
    return HalftoneDotsShaderConfig(
      radius: radius ?? this.radius,
      contrast: contrast ?? this.contrast,
      size: size ?? this.size,
      grainMixer: grainMixer ?? this.grainMixer,
      grainOverlay: grainOverlay ?? this.grainOverlay,
      grainSize: grainSize ?? this.grainSize,
      grid: grid ?? this.grid,
      originalColors: originalColors ?? this.originalColors,
      inverted: inverted ?? this.inverted,
      type: type ?? this.type,
      colorFront: colorFront ?? this.colorFront,
      colorBack: colorBack ?? this.colorBack,
      sizing: sizing ?? this.sizing,
    );
  }

  HalftoneDotsParams toParams() => HalftoneDotsParams(
    radius: radius,
    contrast: contrast,
    size: size,
    grainMixer: grainMixer,
    grainOverlay: grainOverlay,
    grainSize: grainSize,
    grid: grid,
    originalColors: originalColors,
    inverted: inverted,
    type: type,
    colorFront: colorFront,
    colorBack: colorBack,
    sizing: sizing,
  );

  List<ShaderUniform> get uniforms => toParams().uniforms;
}

// ---------------------------------------------------------------------------
// 3. Halftone CMYK Configuration
// ---------------------------------------------------------------------------

class HalftoneCmykShaderConfig {
  const HalftoneCmykShaderConfig({
    this.size = 0.2,
    this.contrast = 1.0,
    this.grainSize = 0.5,
    this.grainMixer = 0.0,
    this.grainOverlay = 0.0,
    this.gridNoise = 0.2,
    this.softness = 1.0,
    this.type = HalftoneCmykType.ink,
    this.colorBack = '#fbfaf5',
    this.sizing = const ShaderSizing.object(fit: ShaderFit.cover),
  });

  final double size;
  final double contrast;
  final double grainSize;
  final double grainMixer;
  final double grainOverlay;
  final double gridNoise;
  final double softness;
  final HalftoneCmykType type;
  final String colorBack;
  final ShaderSizing sizing;

  static const presetDefault = HalftoneCmykShaderConfig();
  static const presetSharpDots = HalftoneCmykShaderConfig(
    type: HalftoneCmykType.dots,
    size: 0.3,
    contrast: 1.2,
    softness: 0.2,
  );
  static const presetVintagePrint = HalftoneCmykShaderConfig(
    type: HalftoneCmykType.ink,
    size: 0.15,
    contrast: 0.9,
    grainMixer: 0.3,
    gridNoise: 0.4,
  );

  HalftoneCmykShaderConfig copyWith({
    double? size,
    double? contrast,
    double? grainSize,
    double? grainMixer,
    double? grainOverlay,
    double? gridNoise,
    double? softness,
    HalftoneCmykType? type,
    String? colorBack,
    ShaderSizing? sizing,
  }) {
    return HalftoneCmykShaderConfig(
      size: size ?? this.size,
      contrast: contrast ?? this.contrast,
      grainSize: grainSize ?? this.grainSize,
      grainMixer: grainMixer ?? this.grainMixer,
      grainOverlay: grainOverlay ?? this.grainOverlay,
      gridNoise: gridNoise ?? this.gridNoise,
      softness: softness ?? this.softness,
      type: type ?? this.type,
      colorBack: colorBack ?? this.colorBack,
      sizing: sizing ?? this.sizing,
    );
  }

  HalftoneCmykParams toParams() => HalftoneCmykParams(
    size: size,
    contrast: contrast,
    grainSize: grainSize,
    grainMixer: grainMixer,
    grainOverlay: grainOverlay,
    gridNoise: gridNoise,
    softness: softness,
    type: type,
    colorBack: colorBack,
    sizing: sizing,
  );

  List<ShaderUniform> get uniforms => toParams().uniforms;
}

// ---------------------------------------------------------------------------
// 4. Image Dithering Configuration
// ---------------------------------------------------------------------------

class ImageDitheringShaderConfig {
  const ImageDitheringShaderConfig({
    this.type = ImageDitheringType.bayer8x8,
    this.size = 2.0,
    this.originalColors = false,
    this.inverted = false,
    this.colorSteps = 2.0,
    this.colorFront = '#94ffaf',
    this.colorBack = '#000c38',
    this.colorHighlight = '#eaff94',
    this.sizing = const ShaderSizing.object(fit: ShaderFit.cover),
  });

  final ImageDitheringType type;
  final double size;
  final bool originalColors;
  final bool inverted;
  final double colorSteps;
  final String colorFront;
  final String colorBack;
  final String colorHighlight;
  final ShaderSizing sizing;

  static const presetDefault = ImageDitheringShaderConfig();
  static const presetNoise = ImageDitheringShaderConfig(
    type: ImageDitheringType.random,
    size: 1.0,
    colorSteps: 1.0,
    colorFront: '#a2997c',
    colorBack: '#000000',
    colorHighlight: '#ededed',
  );
  static const presetRetroBayer = ImageDitheringShaderConfig(
    type: ImageDitheringType.bayer2x2,
    size: 2.0,
    colorSteps: 2.0,
    colorFront: '#eeeeee',
    colorBack: '#5452ff',
    colorHighlight: '#eeeeee',
  );
  static const presetOriginalColors = ImageDitheringShaderConfig(
    type: ImageDitheringType.bayer4x4,
    size: 2.0,
    originalColors: true,
    colorSteps: 4.0,
  );

  ImageDitheringShaderConfig copyWith({
    ImageDitheringType? type,
    double? size,
    bool? originalColors,
    bool? inverted,
    double? colorSteps,
    String? colorFront,
    String? colorBack,
    String? colorHighlight,
    ShaderSizing? sizing,
  }) {
    return ImageDitheringShaderConfig(
      type: type ?? this.type,
      size: size ?? this.size,
      originalColors: originalColors ?? this.originalColors,
      inverted: inverted ?? this.inverted,
      colorSteps: colorSteps ?? this.colorSteps,
      colorFront: colorFront ?? this.colorFront,
      colorBack: colorBack ?? this.colorBack,
      colorHighlight: colorHighlight ?? this.colorHighlight,
      sizing: sizing ?? this.sizing,
    );
  }

  ImageDitheringParams toParams() => ImageDitheringParams(
    type: type,
    size: size,
    originalColors: originalColors,
    inverted: inverted,
    colorSteps: colorSteps,
    colorFront: colorFront,
    colorBack: colorBack,
    colorHighlight: colorHighlight,
    sizing: sizing,
  );

  List<ShaderUniform> get uniforms => toParams().uniforms;
}

// ---------------------------------------------------------------------------
// 5. Paper Texture Configuration
// ---------------------------------------------------------------------------

class PaperTextureShaderConfig {
  const PaperTextureShaderConfig({
    this.contrast = 0.3,
    this.roughness = 0.4,
    this.fiber = 0.3,
    this.fiberSize = 0.2,
    this.crumples = 0.3,
    this.crumpleSize = 0.35,
    this.folds = 0.65,
    this.foldCount = 5.0,
    this.drops = 0.2,
    this.seed = 5.8,
    this.fade = 0.0,
    this.colorFront = '#9fadbc',
    this.colorBack = '#ffffff',
    this.sizing = const ShaderSizing.object(fit: ShaderFit.cover),
  });

  final double contrast;
  final double roughness;
  final double fiber;
  final double fiberSize;
  final double crumples;
  final double crumpleSize;
  final double folds;
  final double foldCount;
  final double drops;
  final double seed;
  final double fade;
  final String colorFront;
  final String colorBack;
  final ShaderSizing sizing;

  static const presetDefault = PaperTextureShaderConfig();
  static const presetCardboard = PaperTextureShaderConfig(
    colorFront: '#c7b89e',
    colorBack: '#999180',
    roughness: 0.6,
    fiber: 0.5,
    crumples: 0.4,
  );
  static const presetParchment = PaperTextureShaderConfig(
    colorFront: '#e4d3b2',
    colorBack: '#faf4e6',
    roughness: 0.3,
    folds: 0.2,
    drops: 0.4,
  );
  static const presetFoldedNote = PaperTextureShaderConfig(
    folds: 0.9,
    foldCount: 4.0,
    crumples: 0.5,
    roughness: 0.5,
  );

  PaperTextureShaderConfig copyWith({
    double? contrast,
    double? roughness,
    double? fiber,
    double? fiberSize,
    double? crumples,
    double? crumpleSize,
    double? folds,
    double? foldCount,
    double? drops,
    double? seed,
    double? fade,
    String? colorFront,
    String? colorBack,
    ShaderSizing? sizing,
  }) {
    return PaperTextureShaderConfig(
      contrast: contrast ?? this.contrast,
      roughness: roughness ?? this.roughness,
      fiber: fiber ?? this.fiber,
      fiberSize: fiberSize ?? this.fiberSize,
      crumples: crumples ?? this.crumples,
      crumpleSize: crumpleSize ?? this.crumpleSize,
      folds: folds ?? this.folds,
      foldCount: foldCount ?? this.foldCount,
      drops: drops ?? this.drops,
      seed: seed ?? this.seed,
      fade: fade ?? this.fade,
      colorFront: colorFront ?? this.colorFront,
      colorBack: colorBack ?? this.colorBack,
      sizing: sizing ?? this.sizing,
    );
  }

  PaperTextureParams toParams() => PaperTextureParams(
    contrast: contrast,
    roughness: roughness,
    fiber: fiber,
    fiberSize: fiberSize,
    crumples: crumples,
    crumpleSize: crumpleSize,
    folds: folds,
    foldCount: foldCount,
    drops: drops,
    seed: seed,
    fade: fade,
    colorFront: colorFront,
    colorBack: colorBack,
    sizing: sizing,
  );

  List<ShaderUniform> get uniforms => toParams().uniforms;
}

// ---------------------------------------------------------------------------
// 6. Heatmap Configuration
// ---------------------------------------------------------------------------

class HeatmapShaderConfig {
  const HeatmapShaderConfig({
    this.angle = 0.0,
    this.noise = 0.0,
    this.innerGlow = 0.5,
    this.outerGlow = 0.5,
    this.contour = 0.5,
    this.colorBack = '#000000',
    this.colors = const <String>[
      '#11206a',
      '#1f3ba2',
      '#2f63e7',
      '#6bd7ff',
      '#ffe679',
      '#ff991e',
      '#ff4c00',
    ],
    this.sizing = const ShaderSizing.object(fit: ShaderFit.cover),
  });

  final double angle;
  final double noise;
  final double innerGlow;
  final double outerGlow;
  final double contour;
  final String colorBack;
  final List<String> colors;
  final ShaderSizing sizing;

  static const presetDefault = HeatmapShaderConfig();
  static const presetSepia = HeatmapShaderConfig(
    colors: ['#997F45', '#ffffff'],
    noise: 0.75,
  );
  static const presetCyberThermal = HeatmapShaderConfig(
    colors: ['#000022', '#00d4ff', '#ff007f', '#ffffff'],
    contour: 0.8,
  );

  HeatmapShaderConfig copyWith({
    double? angle,
    double? noise,
    double? innerGlow,
    double? outerGlow,
    double? contour,
    String? colorBack,
    List<String>? colors,
    ShaderSizing? sizing,
  }) {
    return HeatmapShaderConfig(
      angle: angle ?? this.angle,
      noise: noise ?? this.noise,
      innerGlow: innerGlow ?? this.innerGlow,
      outerGlow: outerGlow ?? this.outerGlow,
      contour: contour ?? this.contour,
      colorBack: colorBack ?? this.colorBack,
      colors: colors ?? this.colors,
      sizing: sizing ?? this.sizing,
    );
  }

  HeatmapParams toParams() => HeatmapParams(
    angle: angle,
    noise: noise,
    innerGlow: innerGlow,
    outerGlow: outerGlow,
    contour: contour,
    colorBack: colorBack,
    colors: colors,
    sizing: sizing,
  );

  List<ShaderUniform> get uniforms => toParams().uniforms;
}

// ---------------------------------------------------------------------------
// 7. Water Configuration
// ---------------------------------------------------------------------------

class WaterShaderConfig {
  const WaterShaderConfig({
    this.highlights = 0.07,
    this.layering = 0.5,
    this.edges = 0.8,
    this.caustic = 0.1,
    this.waves = 0.3,
    this.size = 1.0,
    this.colorBack = '#909090',
    this.colorHighlight = '#ffffff',
    this.sizing = const ShaderSizing.object(fit: ShaderFit.cover),
  });

  final double highlights;
  final double layering;
  final double edges;
  final double caustic;
  final double waves;
  final double size;
  final String colorBack;
  final String colorHighlight;
  final ShaderSizing sizing;

  static const presetDefault = WaterShaderConfig();
  static const presetSlowMo = WaterShaderConfig(
    highlights: 0.4,
    layering: 0.0,
    edges: 0.0,
    caustic: 0.2,
    waves: 0.0,
    size: 0.7,
  );
  static const presetAbstract = WaterShaderConfig(
    highlights: 0.0,
    layering: 0.0,
    edges: 1.0,
    caustic: 0.4,
    waves: 1.0,
    size: 0.15,
  );

  WaterShaderConfig copyWith({
    double? highlights,
    double? layering,
    double? edges,
    double? caustic,
    double? waves,
    double? size,
    String? colorBack,
    String? colorHighlight,
    ShaderSizing? sizing,
  }) {
    return WaterShaderConfig(
      highlights: highlights ?? this.highlights,
      layering: layering ?? this.layering,
      edges: edges ?? this.edges,
      caustic: caustic ?? this.caustic,
      waves: waves ?? this.waves,
      size: size ?? this.size,
      colorBack: colorBack ?? this.colorBack,
      colorHighlight: colorHighlight ?? this.colorHighlight,
      sizing: sizing ?? this.sizing,
    );
  }

  WaterParams toParams() => WaterParams(
    highlights: highlights,
    layering: layering,
    edges: edges,
    caustic: caustic,
    waves: waves,
    size: size,
    colorBack: colorBack,
    colorHighlight: colorHighlight,
    sizing: sizing,
  );

  List<ShaderUniform> get uniforms => toParams().uniforms;
}

// ---------------------------------------------------------------------------
// 8. Liquid Metal Configuration
// ---------------------------------------------------------------------------

class LiquidMetalShaderConfig {
  const LiquidMetalShaderConfig({
    this.softness = 0.1,
    this.repetition = 2.0,
    this.shiftRed = 0.3,
    this.shiftBlue = 0.3,
    this.distortion = 0.07,
    this.contour = 0.4,
    this.angle = 70.0,
    this.shape = LiquidMetalShape.diamond,
    this.isImage = true,
    this.colorBack = '#AAAAAC',
    this.colorTint = '#ffffff',
    this.sizing = const ShaderSizing.object(fit: ShaderFit.cover),
  });

  final double softness;
  final double repetition;
  final double shiftRed;
  final double shiftBlue;
  final double distortion;
  final double contour;
  final double angle;
  final LiquidMetalShape shape;
  final bool isImage;
  final String colorBack;
  final String colorTint;
  final ShaderSizing sizing;

  static const presetDefault = LiquidMetalShaderConfig();
  static const presetChrome = LiquidMetalShaderConfig(
    distortion: 0.12,
    contour: 0.6,
    softness: 0.05,
    shape: LiquidMetalShape.none,
  );
  static const presetMoltenRipples = LiquidMetalShaderConfig(
    repetition: 4.0,
    distortion: 0.05,
    contour: 0.2,
    shape: LiquidMetalShape.circle,
  );

  LiquidMetalShaderConfig copyWith({
    double? softness,
    double? repetition,
    double? shiftRed,
    double? shiftBlue,
    double? distortion,
    double? contour,
    double? angle,
    LiquidMetalShape? shape,
    bool? isImage,
    String? colorBack,
    String? colorTint,
    ShaderSizing? sizing,
  }) {
    return LiquidMetalShaderConfig(
      softness: softness ?? this.softness,
      repetition: repetition ?? this.repetition,
      shiftRed: shiftRed ?? this.shiftRed,
      shiftBlue: shiftBlue ?? this.shiftBlue,
      distortion: distortion ?? this.distortion,
      contour: contour ?? this.contour,
      angle: angle ?? this.angle,
      shape: shape ?? this.shape,
      isImage: isImage ?? this.isImage,
      colorBack: colorBack ?? this.colorBack,
      colorTint: colorTint ?? this.colorTint,
      sizing: sizing ?? this.sizing,
    );
  }

  LiquidMetalParams toParams() => LiquidMetalParams(
    softness: softness,
    repetition: repetition,
    shiftRed: shiftRed,
    shiftBlue: shiftBlue,
    distortion: distortion,
    contour: contour,
    angle: angle,
    shape: shape,
    isImage: isImage,
    colorBack: colorBack,
    colorTint: colorTint,
    sizing: sizing,
  );

  List<ShaderUniform> get uniforms => toParams().uniforms;
}

// ---------------------------------------------------------------------------
// 9. Gem Smoke Configuration
// ---------------------------------------------------------------------------

class GemSmokeShaderConfig {
  const GemSmokeShaderConfig({
    this.innerDistortion = 0.8,
    this.outerDistortion = 0.6,
    this.outerGlow = 0.55,
    this.innerGlow = 1.0,
    this.offset = 0.0,
    this.angle = 0.0,
    this.size = 0.8,
    this.shape = GemSmokeShape.diamond,
    this.isImage = true,
    this.colors = const <String>['#333333', '#e7e6df'],
    this.colorBack = '#f0efea',
    this.colorInner = '#fafaf5',
    this.sizing = const ShaderSizing.object(fit: ShaderFit.cover),
  });

  final double innerDistortion;
  final double outerDistortion;
  final double outerGlow;
  final double innerGlow;
  final double offset;
  final double angle;
  final double size;
  final GemSmokeShape shape;
  final bool isImage;
  final List<String> colors;
  final String colorBack;
  final String colorInner;
  final ShaderSizing sizing;

  static const presetDefault = GemSmokeShaderConfig();
  static const presetFire = GemSmokeShaderConfig(
    colors: ['#fe5b16', '#f7ff61', '#ffffff'],
    colorBack: '#000000',
    colorInner: '#000000',
    innerDistortion: 0.6,
    outerDistortion: 0.8,
    outerGlow: 1.0,
    innerGlow: 0.65,
  );
  static const presetFluorescent = GemSmokeShaderConfig(
    colors: ['#2fb64c', '#cdff61', '#ffffff'],
    colorBack: '#000000',
    colorInner: '#000000',
    innerDistortion: 1.0,
    outerDistortion: 0.8,
    outerGlow: 0.0,
  );

  GemSmokeShaderConfig copyWith({
    double? innerDistortion,
    double? outerDistortion,
    double? outerGlow,
    double? innerGlow,
    double? offset,
    double? angle,
    double? size,
    GemSmokeShape? shape,
    bool? isImage,
    List<String>? colors,
    String? colorBack,
    String? colorInner,
    ShaderSizing? sizing,
  }) {
    return GemSmokeShaderConfig(
      innerDistortion: innerDistortion ?? this.innerDistortion,
      outerDistortion: outerDistortion ?? this.outerDistortion,
      outerGlow: outerGlow ?? this.outerGlow,
      innerGlow: innerGlow ?? this.innerGlow,
      offset: offset ?? this.offset,
      angle: angle ?? this.angle,
      size: size ?? this.size,
      shape: shape ?? this.shape,
      isImage: isImage ?? this.isImage,
      colors: colors ?? this.colors,
      colorBack: colorBack ?? this.colorBack,
      colorInner: colorInner ?? this.colorInner,
      sizing: sizing ?? this.sizing,
    );
  }

  GemSmokeParams toParams() => GemSmokeParams(
    innerDistortion: innerDistortion,
    outerDistortion: outerDistortion,
    outerGlow: outerGlow,
    innerGlow: innerGlow,
    offset: offset,
    angle: angle,
    size: size,
    shape: shape,
    isImage: isImage,
    colors: colors,
    colorBack: colorBack,
    colorInner: colorInner,
    sizing: sizing,
  );

  List<ShaderUniform> get uniforms => toParams().uniforms;
}

// ---------------------------------------------------------------------------
// Unified Shader Settings
// ---------------------------------------------------------------------------

class ShareShaderSettings {
  const ShareShaderSettings({
    this.type = ShareShaderType.none,
    this.flutedGlass = const FlutedGlassShaderConfig(),
    this.halftoneDots = const HalftoneDotsShaderConfig(),
    this.halftoneCmyk = const HalftoneCmykShaderConfig(),
    this.imageDithering = const ImageDitheringShaderConfig(),
    this.paperTexture = const PaperTextureShaderConfig(),
    this.heatmap = const HeatmapShaderConfig(),
    this.water = const WaterShaderConfig(),
    this.liquidMetal = const LiquidMetalShaderConfig(),
    this.gemSmoke = const GemSmokeShaderConfig(),
  });

  final ShareShaderType type;
  final FlutedGlassShaderConfig flutedGlass;
  final HalftoneDotsShaderConfig halftoneDots;
  final HalftoneCmykShaderConfig halftoneCmyk;
  final ImageDitheringShaderConfig imageDithering;
  final PaperTextureShaderConfig paperTexture;
  final HeatmapShaderConfig heatmap;
  final WaterShaderConfig water;
  final LiquidMetalShaderConfig liquidMetal;
  final GemSmokeShaderConfig gemSmoke;

  bool get isEnabled => type != ShareShaderType.none;

  bool get needsNoiseTexture =>
      type == ShareShaderType.paperTexture ||
      type == ShareShaderType.halftoneCmyk;

  ShaderSizing get currentSizing {
    switch (type) {
      case ShareShaderType.none:
        return const ShaderSizing.pattern();
      case ShareShaderType.flutedGlass:
        return flutedGlass.sizing;
      case ShareShaderType.halftoneDots:
        return halftoneDots.sizing;
      case ShareShaderType.halftoneCmyk:
        return halftoneCmyk.sizing;
      case ShareShaderType.imageDithering:
        return imageDithering.sizing;
      case ShareShaderType.paperTexture:
        return paperTexture.sizing;
      case ShareShaderType.heatmap:
        return heatmap.sizing;
      case ShareShaderType.water:
        return water.sizing;
      case ShareShaderType.liquidMetal:
        return liquidMetal.sizing;
      case ShareShaderType.gemSmoke:
        return gemSmoke.sizing;
    }
  }

  List<ShaderUniform> get currentUniforms {
    switch (type) {
      case ShareShaderType.none:
        return const [];
      case ShareShaderType.flutedGlass:
        return flutedGlass.uniforms;
      case ShareShaderType.halftoneDots:
        return halftoneDots.uniforms;
      case ShareShaderType.halftoneCmyk:
        return halftoneCmyk.uniforms;
      case ShareShaderType.imageDithering:
        return imageDithering.uniforms;
      case ShareShaderType.paperTexture:
        return paperTexture.uniforms;
      case ShareShaderType.heatmap:
        return heatmap.uniforms;
      case ShareShaderType.water:
        return water.uniforms;
      case ShareShaderType.liquidMetal:
        return liquidMetal.uniforms;
      case ShareShaderType.gemSmoke:
        return gemSmoke.uniforms;
    }
  }

  ShareShaderSettings copyWith({
    ShareShaderType? type,
    FlutedGlassShaderConfig? flutedGlass,
    HalftoneDotsShaderConfig? halftoneDots,
    HalftoneCmykShaderConfig? halftoneCmyk,
    ImageDitheringShaderConfig? imageDithering,
    PaperTextureShaderConfig? paperTexture,
    HeatmapShaderConfig? heatmap,
    WaterShaderConfig? water,
    LiquidMetalShaderConfig? liquidMetal,
    GemSmokeShaderConfig? gemSmoke,
  }) {
    return ShareShaderSettings(
      type: type ?? this.type,
      flutedGlass: flutedGlass ?? this.flutedGlass,
      halftoneDots: halftoneDots ?? this.halftoneDots,
      halftoneCmyk: halftoneCmyk ?? this.halftoneCmyk,
      imageDithering: imageDithering ?? this.imageDithering,
      paperTexture: paperTexture ?? this.paperTexture,
      heatmap: heatmap ?? this.heatmap,
      water: water ?? this.water,
      liquidMetal: liquidMetal ?? this.liquidMetal,
      gemSmoke: gemSmoke ?? this.gemSmoke,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareShaderSettings &&
          other.type == type &&
          other.flutedGlass == flutedGlass &&
          other.halftoneDots == halftoneDots &&
          other.halftoneCmyk == halftoneCmyk &&
          other.imageDithering == imageDithering &&
          other.paperTexture == paperTexture &&
          other.heatmap == heatmap &&
          other.water == water &&
          other.liquidMetal == liquidMetal &&
          other.gemSmoke == gemSmoke;

  @override
  int get hashCode => Object.hash(
        type,
        flutedGlass,
        halftoneDots,
        halftoneCmyk,
        imageDithering,
        paperTexture,
        heatmap,
        water,
        liquidMetal,
        gemSmoke,
      );
}
