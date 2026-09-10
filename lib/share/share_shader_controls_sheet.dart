import 'package:flutter/material.dart';
import 'package:paper_shaders/paper_shaders.dart';

import '../theme/app_haptics.dart';
import '../theme/spacing.dart';
import 'share_shader_config.dart';

/// A dark-themed control sheet allowing the user to switch between paper shaders,
/// select presets, and adjust granular shader parameters in real-time.
class ShareShaderControlsSheet extends StatelessWidget {
  const ShareShaderControlsSheet({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.onClose,
  });

  final ShareShaderSettings settings;
  final ValueChanged<ShareShaderSettings> onSettingsChanged;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 350),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Title & Reset action
          _buildHeader(context, scheme, textTheme),

          // Horizontal Shader Type Selector
          _buildTypeSelector(scheme),

          if (settings.isEnabled) ...[
            const SizedBox(height: 6),

            // Presets bar for the active shader
            _buildPresetsBar(scheme),

            // Subtle divider
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),

            // Scrollable list of shader-specific controls
            Expanded(
              child: _buildActiveShaderControls(scheme, textTheme),
            ),
          ] else ...[
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MdSpacing.xs,
        vertical: MdSpacing.xxs,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_motion_rounded,
            size: 18,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              settings.isEnabled
                  ? 'Shaders: ${settings.type.label}'
                  : 'Shaders',
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (settings.isEnabled) ...[
            IconButton(
              tooltip: 'Reset to default',
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Colors.white70,
              ),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
              onPressed: () {
                AppHaptics.mediumImpact();
                _resetActiveShaderToDefault();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme scheme) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
        itemCount: ShareShaderType.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final type = ShareShaderType.values[index];
          final isSelected = settings.type == type;
          final label = type == ShareShaderType.none ? 'Off' : type.label;

          return GestureDetector(
            onTap: () {
              AppHaptics.selection();
              onSettingsChanged(settings.copyWith(type: type));
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primaryContainer
                    : const Color(0xFF282828),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? scheme.primary
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type.icon,
                    size: 14,
                    color: isSelected
                        ? scheme.onPrimaryContainer
                        : Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? scheme.onPrimaryContainer
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _resetActiveShaderToDefault() {
    switch (settings.type) {
      case ShareShaderType.none:
        break;
      case ShareShaderType.flutedGlass:
        onSettingsChanged(
          settings.copyWith(
            flutedGlass: FlutedGlassShaderConfig.presetDefault,
          ),
        );
        break;
      case ShareShaderType.halftoneDots:
        onSettingsChanged(
          settings.copyWith(
            halftoneDots: HalftoneDotsShaderConfig.presetDefault,
          ),
        );
        break;
      case ShareShaderType.halftoneCmyk:
        onSettingsChanged(
          settings.copyWith(
            halftoneCmyk: HalftoneCmykShaderConfig.presetDefault,
          ),
        );
        break;
      case ShareShaderType.imageDithering:
        onSettingsChanged(
          settings.copyWith(
            imageDithering: ImageDitheringShaderConfig.presetDefault,
          ),
        );
        break;
      case ShareShaderType.paperTexture:
        onSettingsChanged(
          settings.copyWith(
            paperTexture: PaperTextureShaderConfig.presetDefault,
          ),
        );
        break;
      case ShareShaderType.heatmap:
        onSettingsChanged(
          settings.copyWith(
            heatmap: HeatmapShaderConfig.presetDefault,
          ),
        );
        break;
      case ShareShaderType.water:
        onSettingsChanged(
          settings.copyWith(
            water: WaterShaderConfig.presetDefault,
          ),
        );
        break;
      case ShareShaderType.liquidMetal:
        onSettingsChanged(
          settings.copyWith(
            liquidMetal: LiquidMetalShaderConfig.presetDefault,
          ),
        );
        break;
      case ShareShaderType.gemSmoke:
        onSettingsChanged(
          settings.copyWith(
            gemSmoke: GemSmokeShaderConfig.presetDefault,
          ),
        );
        break;
    }
  }

  Widget _buildPresetsBar(ColorScheme scheme) {
    final presets = _getPresetsForActiveShader();
    if (presets.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: MdSpacing.xs,
          vertical: 3,
        ),
        itemCount: presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final preset = presets[index];
          return ActionChip(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            backgroundColor: const Color(0xFF282828),
            label: Text(
              preset.name,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white,
              ),
            ),
            onPressed: () {
              AppHaptics.selection();
              preset.apply();
            },
          );
        },
      ),
    );
  }

  List<_ShaderPresetAction> _getPresetsForActiveShader() {
    switch (settings.type) {
      case ShareShaderType.none:
        return [];
      case ShareShaderType.flutedGlass:
        return [
          _ShaderPresetAction(
            'Default',
            () => onSettingsChanged(
              settings.copyWith(
                flutedGlass: FlutedGlassShaderConfig.presetDefault,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Waves',
            () => onSettingsChanged(
              settings.copyWith(
                flutedGlass: FlutedGlassShaderConfig.presetWaves,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Abstract',
            () => onSettingsChanged(
              settings.copyWith(
                flutedGlass: FlutedGlassShaderConfig.presetAbstract,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Folds',
            () => onSettingsChanged(
              settings.copyWith(
                flutedGlass: FlutedGlassShaderConfig.presetFolds,
              ),
            ),
          ),
        ];
      case ShareShaderType.halftoneDots:
        return [
          _ShaderPresetAction(
            'Default',
            () => onSettingsChanged(
              settings.copyWith(
                halftoneDots: HalftoneDotsShaderConfig.presetDefault,
              ),
            ),
          ),
          _ShaderPresetAction(
            'LED screen',
            () => onSettingsChanged(
              settings.copyWith(
                halftoneDots: HalftoneDotsShaderConfig.presetLedScreen,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Mosaic',
            () => onSettingsChanged(
              settings.copyWith(
                halftoneDots: HalftoneDotsShaderConfig.presetMosaic,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Round and square',
            () => onSettingsChanged(
              settings.copyWith(
                halftoneDots: HalftoneDotsShaderConfig.presetRoundSquare,
              ),
            ),
          ),
        ];
      case ShareShaderType.halftoneCmyk:
        return [
          _ShaderPresetAction(
            'Default',
            () => onSettingsChanged(
              settings.copyWith(
                halftoneCmyk: HalftoneCmykShaderConfig.presetDefault,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Sharp Dots',
            () => onSettingsChanged(
              settings.copyWith(
                halftoneCmyk: HalftoneCmykShaderConfig.presetSharpDots,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Vintage Print',
            () => onSettingsChanged(
              settings.copyWith(
                halftoneCmyk: HalftoneCmykShaderConfig.presetVintagePrint,
              ),
            ),
          ),
        ];
      case ShareShaderType.imageDithering:
        return [
          _ShaderPresetAction(
            'Default',
            () => onSettingsChanged(
              settings.copyWith(
                imageDithering: ImageDitheringShaderConfig.presetDefault,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Noise (1-bit)',
            () => onSettingsChanged(
              settings.copyWith(
                imageDithering: ImageDitheringShaderConfig.presetNoise,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Retro 2x2',
            () => onSettingsChanged(
              settings.copyWith(
                imageDithering: ImageDitheringShaderConfig.presetRetroBayer,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Original Colors',
            () => onSettingsChanged(
              settings.copyWith(
                imageDithering: ImageDitheringShaderConfig.presetOriginalColors,
              ),
            ),
          ),
        ];
      case ShareShaderType.paperTexture:
        return [
          _ShaderPresetAction(
            'Default',
            () => onSettingsChanged(
              settings.copyWith(
                paperTexture: PaperTextureShaderConfig.presetDefault,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Cardboard',
            () => onSettingsChanged(
              settings.copyWith(
                paperTexture: PaperTextureShaderConfig.presetCardboard,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Parchment',
            () => onSettingsChanged(
              settings.copyWith(
                paperTexture: PaperTextureShaderConfig.presetParchment,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Folded Note',
            () => onSettingsChanged(
              settings.copyWith(
                paperTexture: PaperTextureShaderConfig.presetFoldedNote,
              ),
            ),
          ),
        ];
      case ShareShaderType.heatmap:
        return [
          _ShaderPresetAction(
            'Default',
            () => onSettingsChanged(
              settings.copyWith(
                heatmap: HeatmapShaderConfig.presetDefault,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Sepia',
            () => onSettingsChanged(
              settings.copyWith(
                heatmap: HeatmapShaderConfig.presetSepia,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Cyber Thermal',
            () => onSettingsChanged(
              settings.copyWith(
                heatmap: HeatmapShaderConfig.presetCyberThermal,
              ),
            ),
          ),
        ];
      case ShareShaderType.water:
        return [
          _ShaderPresetAction(
            'Default',
            () => onSettingsChanged(
              settings.copyWith(
                water: WaterShaderConfig.presetDefault,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Slow-mo',
            () => onSettingsChanged(
              settings.copyWith(
                water: WaterShaderConfig.presetSlowMo,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Abstract',
            () => onSettingsChanged(
              settings.copyWith(
                water: WaterShaderConfig.presetAbstract,
              ),
            ),
          ),
        ];
      case ShareShaderType.liquidMetal:
        return [
          _ShaderPresetAction(
            'Default',
            () => onSettingsChanged(
              settings.copyWith(
                liquidMetal: LiquidMetalShaderConfig.presetDefault,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Chrome',
            () => onSettingsChanged(
              settings.copyWith(
                liquidMetal: LiquidMetalShaderConfig.presetChrome,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Molten Ripples',
            () => onSettingsChanged(
              settings.copyWith(
                liquidMetal: LiquidMetalShaderConfig.presetMoltenRipples,
              ),
            ),
          ),
        ];
      case ShareShaderType.gemSmoke:
        return [
          _ShaderPresetAction(
            'Default',
            () => onSettingsChanged(
              settings.copyWith(
                gemSmoke: GemSmokeShaderConfig.presetDefault,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Fire',
            () => onSettingsChanged(
              settings.copyWith(
                gemSmoke: GemSmokeShaderConfig.presetFire,
              ),
            ),
          ),
          _ShaderPresetAction(
            'Fluorescent',
            () => onSettingsChanged(
              settings.copyWith(
                gemSmoke: GemSmokeShaderConfig.presetFluorescent,
              ),
            ),
          ),
        ];
    }
  }

  Widget _buildActiveShaderControls(ColorScheme scheme, TextTheme textTheme) {
    switch (settings.type) {
      case ShareShaderType.none:
        return const SizedBox.shrink();
      case ShareShaderType.flutedGlass:
        return _buildFlutedGlassControls(scheme, textTheme);
      case ShareShaderType.halftoneDots:
        return _buildHalftoneDotsControls(scheme, textTheme);
      case ShareShaderType.halftoneCmyk:
        return _buildHalftoneCmykControls(scheme, textTheme);
      case ShareShaderType.imageDithering:
        return _buildImageDitheringControls(scheme, textTheme);
      case ShareShaderType.paperTexture:
        return _buildPaperTextureControls(scheme, textTheme);
      case ShareShaderType.heatmap:
        return _buildHeatmapControls(scheme, textTheme);
      case ShareShaderType.water:
        return _buildWaterControls(scheme, textTheme);
      case ShareShaderType.liquidMetal:
        return _buildLiquidMetalControls(scheme, textTheme);
      case ShareShaderType.gemSmoke:
        return _buildGemSmokeControls(scheme, textTheme);
    }
  }

  // -------------------------------------------------------------------------
  // Shader-specific control lists
  // -------------------------------------------------------------------------

  Widget _buildFlutedGlassControls(ColorScheme scheme, TextTheme textTheme) {
    final cfg = settings.flutedGlass;
    void update(FlutedGlassShaderConfig next) {
      onSettingsChanged(settings.copyWith(flutedGlass: next));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
      children: [
        _buildSliderRow('shadows', cfg.shadows, 0.0, 1.0, (v) => update(cfg.copyWith(shadows: v)), scheme),
        _buildSliderRow('highlights', cfg.highlights, 0.0, 1.0, (v) => update(cfg.copyWith(highlights: v)), scheme),
        _buildSliderRow('size', cfg.size, 0.1, 1.0, (v) => update(cfg.copyWith(size: v)), scheme),
        _buildDropdownRow<FlutedGlassShape>('shape', cfg.shape, FlutedGlassShape.values, (v) => v.displayName, (v) => update(cfg.copyWith(shape: v)), scheme),
        _buildSliderRow('angle', cfg.angle, 0.0, 360.0, (v) => update(cfg.copyWith(angle: v)), scheme, divisions: 72, formatAsInt: true),
        _buildDropdownRow<FlutedGlassDistortionShape>('distortionShape', cfg.distortionShape, FlutedGlassDistortionShape.values, (v) => v.displayName, (v) => update(cfg.copyWith(distortionShape: v)), scheme),
        _buildSliderRow('distortion', cfg.distortion, 0.0, 1.0, (v) => update(cfg.copyWith(distortion: v)), scheme),
        _buildSliderRow('shift', cfg.shift, 0.0, 1.0, (v) => update(cfg.copyWith(shift: v)), scheme),
        _buildSliderRow('stretch', cfg.stretch, 0.0, 1.0, (v) => update(cfg.copyWith(stretch: v)), scheme),
        _buildSliderRow('blur', cfg.blur, 0.0, 1.0, (v) => update(cfg.copyWith(blur: v)), scheme),
        _buildSliderRow('edges', cfg.edges, 0.0, 1.0, (v) => update(cfg.copyWith(edges: v)), scheme),
        _buildSliderRow('margin', cfg.margin, 0.0, 0.5, (v) => update(cfg.copyWith(margin: v)), scheme),
        _buildSliderRow('grainMixer', cfg.grainMixer, 0.0, 1.0, (v) => update(cfg.copyWith(grainMixer: v)), scheme),
        _buildSliderRow('grainOverlay', cfg.grainOverlay, 0.0, 1.0, (v) => update(cfg.copyWith(grainOverlay: v)), scheme),
        _buildSliderRow('scale', cfg.scale, 0.5, 2.0, (v) => update(cfg.copyWith(scale: v)), scheme),
      ],
    );
  }

  Widget _buildHalftoneDotsControls(ColorScheme scheme, TextTheme textTheme) {
    final cfg = settings.halftoneDots;
    void update(HalftoneDotsShaderConfig next) {
      onSettingsChanged(settings.copyWith(halftoneDots: next));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
      children: [
        _buildSliderRow('radius', cfg.radius, 0.2, 3.0, (v) => update(cfg.copyWith(radius: v)), scheme),
        _buildSliderRow('contrast', cfg.contrast, 0.0, 1.0, (v) => update(cfg.copyWith(contrast: v)), scheme),
        _buildSliderRow('size', cfg.size, 0.1, 1.0, (v) => update(cfg.copyWith(size: v)), scheme),
        _buildSliderRow('grainMixer', cfg.grainMixer, 0.0, 1.0, (v) => update(cfg.copyWith(grainMixer: v)), scheme),
        _buildSliderRow('grainOverlay', cfg.grainOverlay, 0.0, 1.0, (v) => update(cfg.copyWith(grainOverlay: v)), scheme),
        _buildDropdownRow<HalftoneDotsGrid>('grid', cfg.grid, HalftoneDotsGrid.values, (v) => v.displayName, (v) => update(cfg.copyWith(grid: v)), scheme),
        _buildDropdownRow<HalftoneDotsType>('type', cfg.type, HalftoneDotsType.values, (v) => v.displayName, (v) => update(cfg.copyWith(type: v)), scheme),
        _buildSwitchRow('originalColors', cfg.originalColors, (v) => update(cfg.copyWith(originalColors: v)), scheme),
        _buildSwitchRow('inverted', cfg.inverted, (v) => update(cfg.copyWith(inverted: v)), scheme),
      ],
    );
  }

  Widget _buildHalftoneCmykControls(ColorScheme scheme, TextTheme textTheme) {
    final cfg = settings.halftoneCmyk;
    void update(HalftoneCmykShaderConfig next) {
      onSettingsChanged(settings.copyWith(halftoneCmyk: next));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
      children: [
        _buildSliderRow('size', cfg.size, 0.05, 1.0, (v) => update(cfg.copyWith(size: v)), scheme),
        _buildSliderRow('contrast', cfg.contrast, 0.1, 2.0, (v) => update(cfg.copyWith(contrast: v)), scheme),
        _buildSliderRow('grainSize', cfg.grainSize, 0.1, 1.0, (v) => update(cfg.copyWith(grainSize: v)), scheme),
        _buildSliderRow('grainMixer', cfg.grainMixer, 0.0, 1.0, (v) => update(cfg.copyWith(grainMixer: v)), scheme),
        _buildSliderRow('gridNoise', cfg.gridNoise, 0.0, 1.0, (v) => update(cfg.copyWith(gridNoise: v)), scheme),
        _buildSliderRow('softness', cfg.softness, 0.0, 2.0, (v) => update(cfg.copyWith(softness: v)), scheme),
        _buildDropdownRow<HalftoneCmykType>('type', cfg.type, HalftoneCmykType.values, (v) => v.displayName, (v) => update(cfg.copyWith(type: v)), scheme),
      ],
    );
  }

  Widget _buildImageDitheringControls(ColorScheme scheme, TextTheme textTheme) {
    final cfg = settings.imageDithering;
    void update(ImageDitheringShaderConfig next) {
      onSettingsChanged(settings.copyWith(imageDithering: next));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
      children: [
        _buildDropdownRow<ImageDitheringType>('type', cfg.type, ImageDitheringType.values, (v) => v.displayName, (v) => update(cfg.copyWith(type: v)), scheme),
        _buildSliderRow('pixelSize', cfg.size, 1.0, 8.0, (v) => update(cfg.copyWith(size: v)), scheme, divisions: 7, formatAsInt: true),
        _buildSliderRow('colorSteps', cfg.colorSteps, 1.0, 8.0, (v) => update(cfg.copyWith(colorSteps: v)), scheme, divisions: 7, formatAsInt: true),
        _buildSwitchRow('originalColors', cfg.originalColors, (v) => update(cfg.copyWith(originalColors: v)), scheme),
        _buildSwitchRow('inverted', cfg.inverted, (v) => update(cfg.copyWith(inverted: v)), scheme),
      ],
    );
  }

  Widget _buildPaperTextureControls(ColorScheme scheme, TextTheme textTheme) {
    final cfg = settings.paperTexture;
    void update(PaperTextureShaderConfig next) {
      onSettingsChanged(settings.copyWith(paperTexture: next));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
      children: [
        _buildSliderRow('contrast', cfg.contrast, 0.0, 1.0, (v) => update(cfg.copyWith(contrast: v)), scheme),
        _buildSliderRow('roughness', cfg.roughness, 0.0, 1.0, (v) => update(cfg.copyWith(roughness: v)), scheme),
        _buildSliderRow('fiber', cfg.fiber, 0.0, 1.0, (v) => update(cfg.copyWith(fiber: v)), scheme),
        _buildSliderRow('fiberSize', cfg.fiberSize, 0.05, 0.8, (v) => update(cfg.copyWith(fiberSize: v)), scheme),
        _buildSliderRow('crumples', cfg.crumples, 0.0, 1.0, (v) => update(cfg.copyWith(crumples: v)), scheme),
        _buildSliderRow('crumpleSize', cfg.crumpleSize, 0.1, 1.0, (v) => update(cfg.copyWith(crumpleSize: v)), scheme),
        _buildSliderRow('folds', cfg.folds, 0.0, 1.0, (v) => update(cfg.copyWith(folds: v)), scheme),
        _buildSliderRow('foldCount', cfg.foldCount, 1.0, 10.0, (v) => update(cfg.copyWith(foldCount: v)), scheme, divisions: 9, formatAsInt: true),
        _buildSliderRow('drops', cfg.drops, 0.0, 1.0, (v) => update(cfg.copyWith(drops: v)), scheme),
        _buildSliderRow('fade', cfg.fade, 0.0, 1.0, (v) => update(cfg.copyWith(fade: v)), scheme),
      ],
    );
  }

  Widget _buildHeatmapControls(ColorScheme scheme, TextTheme textTheme) {
    final cfg = settings.heatmap;
    void update(HeatmapShaderConfig next) {
      onSettingsChanged(settings.copyWith(heatmap: next));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
      children: [
        _buildSliderRow('angle', cfg.angle, 0.0, 360.0, (v) => update(cfg.copyWith(angle: v)), scheme, divisions: 72, formatAsInt: true),
        _buildSliderRow('noise', cfg.noise, 0.0, 1.0, (v) => update(cfg.copyWith(noise: v)), scheme),
        _buildSliderRow('innerGlow', cfg.innerGlow, 0.0, 1.0, (v) => update(cfg.copyWith(innerGlow: v)), scheme),
        _buildSliderRow('outerGlow', cfg.outerGlow, 0.0, 1.0, (v) => update(cfg.copyWith(outerGlow: v)), scheme),
        _buildSliderRow('contour', cfg.contour, 0.0, 1.0, (v) => update(cfg.copyWith(contour: v)), scheme),
      ],
    );
  }

  Widget _buildWaterControls(ColorScheme scheme, TextTheme textTheme) {
    final cfg = settings.water;
    void update(WaterShaderConfig next) {
      onSettingsChanged(settings.copyWith(water: next));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
      children: [
        _buildSliderRow('highlights', cfg.highlights, 0.0, 1.0, (v) => update(cfg.copyWith(highlights: v)), scheme),
        _buildSliderRow('layering', cfg.layering, 0.0, 1.0, (v) => update(cfg.copyWith(layering: v)), scheme),
        _buildSliderRow('edges', cfg.edges, 0.0, 1.0, (v) => update(cfg.copyWith(edges: v)), scheme),
        _buildSliderRow('caustic', cfg.caustic, 0.0, 1.0, (v) => update(cfg.copyWith(caustic: v)), scheme),
        _buildSliderRow('waves', cfg.waves, 0.0, 1.0, (v) => update(cfg.copyWith(waves: v)), scheme),
        _buildSliderRow('size', cfg.size, 0.1, 2.0, (v) => update(cfg.copyWith(size: v)), scheme),
      ],
    );
  }

  Widget _buildLiquidMetalControls(ColorScheme scheme, TextTheme textTheme) {
    final cfg = settings.liquidMetal;
    void update(LiquidMetalShaderConfig next) {
      onSettingsChanged(settings.copyWith(liquidMetal: next));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
      children: [
        _buildSliderRow('softness', cfg.softness, 0.0, 1.0, (v) => update(cfg.copyWith(softness: v)), scheme),
        _buildSliderRow('repetition', cfg.repetition, 1.0, 6.0, (v) => update(cfg.copyWith(repetition: v)), scheme, divisions: 5, formatAsInt: true),
        _buildSliderRow('shiftRed', cfg.shiftRed, 0.0, 1.0, (v) => update(cfg.copyWith(shiftRed: v)), scheme),
        _buildSliderRow('shiftBlue', cfg.shiftBlue, 0.0, 1.0, (v) => update(cfg.copyWith(shiftBlue: v)), scheme),
        _buildSliderRow('distortion', cfg.distortion, 0.0, 0.3, (v) => update(cfg.copyWith(distortion: v)), scheme),
        _buildSliderRow('contour', cfg.contour, 0.0, 1.0, (v) => update(cfg.copyWith(contour: v)), scheme),
        _buildSliderRow('angle', cfg.angle, 0.0, 360.0, (v) => update(cfg.copyWith(angle: v)), scheme, divisions: 72, formatAsInt: true),
        _buildDropdownRow<LiquidMetalShape>('shape', cfg.shape, LiquidMetalShape.values, (v) => v.displayName, (v) => update(cfg.copyWith(shape: v)), scheme),
      ],
    );
  }

  Widget _buildGemSmokeControls(ColorScheme scheme, TextTheme textTheme) {
    final cfg = settings.gemSmoke;
    void update(GemSmokeShaderConfig next) {
      onSettingsChanged(settings.copyWith(gemSmoke: next));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xs),
      children: [
        _buildSliderRow('innerDistortion', cfg.innerDistortion, 0.0, 1.0, (v) => update(cfg.copyWith(innerDistortion: v)), scheme),
        _buildSliderRow('outerDistortion', cfg.outerDistortion, 0.0, 1.0, (v) => update(cfg.copyWith(outerDistortion: v)), scheme),
        _buildSliderRow('outerGlow', cfg.outerGlow, 0.0, 1.0, (v) => update(cfg.copyWith(outerGlow: v)), scheme),
        _buildSliderRow('innerGlow', cfg.innerGlow, 0.0, 1.0, (v) => update(cfg.copyWith(innerGlow: v)), scheme),
        _buildSliderRow('offset', cfg.offset, 0.0, 1.0, (v) => update(cfg.copyWith(offset: v)), scheme),
        _buildSliderRow('angle', cfg.angle, 0.0, 360.0, (v) => update(cfg.copyWith(angle: v)), scheme, divisions: 72, formatAsInt: true),
        _buildSliderRow('size', cfg.size, 0.1, 2.0, (v) => update(cfg.copyWith(size: v)), scheme),
        _buildDropdownRow<GemSmokeShape>('shape', cfg.shape, GemSmokeShape.values, (v) => v.displayName, (v) => update(cfg.copyWith(shape: v)), scheme),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Reusable Micro Controls
  // -------------------------------------------------------------------------

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    ColorScheme scheme, {
    int? divisions,
    bool formatAsInt = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.5,
                activeTrackColor: scheme.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: scheme.primary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              formatAsInt ? '${value.round()}' : value.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow<T>(
    String label,
    T currentValue,
    List<T> values,
    String Function(T) labelExtractor,
    ValueChanged<T> onChanged,
    ColorScheme scheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: currentValue,
                  dropdownColor: const Color(0xFF282828),
                  isDense: true,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: Colors.white,
                  ),
                  items: values.map((val) {
                    return DropdownMenuItem<T>(
                      value: val,
                      child: Text(
                        labelExtractor(val),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      AppHaptics.selection();
                      onChanged(val);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    ColorScheme scheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: value,
              activeThumbColor: scheme.primary,
              onChanged: (v) {
                AppHaptics.selection();
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShaderPresetAction {
  const _ShaderPresetAction(this.name, this.apply);
  final String name;
  final VoidCallback apply;
}
