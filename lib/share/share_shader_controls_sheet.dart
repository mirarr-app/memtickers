import 'package:flutter/material.dart';
import 'package:paper_shaders/paper_shaders.dart';

import '../theme/app_haptics.dart';
import '../theme/spacing.dart';
import 'share_shader_config.dart';

/// Best-in-class customization control panel for Share Studio shaders,
/// matching the exact parameter controls from the Paper Shaders source.
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
      constraints: const BoxConstraints(maxHeight: 340),
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
          // Header: Shader selector and quick presets
          _buildHeader(context, scheme, textTheme),

          if (settings.isEnabled) ...[
            // Presets bar
            _buildPresetsBar(scheme),

            // Divider
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),

            // Scrollable list of controls matching screenshot
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MdSpacing.sm,
                  vertical: MdSpacing.xs,
                ),
                children: [
                  _buildSliderRow(
                    label: 'shadows',
                    value: settings.flutedGlass.shadows,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(shadows: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'highlights',
                    value: settings.flutedGlass.highlights,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(highlights: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'size',
                    value: settings.flutedGlass.size,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(size: v),
                    ),
                  ),
                  _buildDropdownRow<FlutedGlassShape>(
                    label: 'shape',
                    value: settings.flutedGlass.shape,
                    items: FlutedGlassShape.values,
                    itemLabel: (s) => s.displayName,
                    onChanged: (v) {
                      if (v != null) {
                        AppHaptics.selection();
                        _updateConfig(settings.flutedGlass.copyWith(shape: v));
                      }
                    },
                  ),
                  _buildSliderRow(
                    label: 'angle',
                    value: settings.flutedGlass.angle,
                    min: -180.0,
                    max: 180.0,
                    divisions: 360,
                    isInteger: true,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(angle: v),
                    ),
                  ),
                  _buildDropdownRow<FlutedGlassDistortionShape>(
                    label: 'distortionShape',
                    value: settings.flutedGlass.distortionShape,
                    items: FlutedGlassDistortionShape.values,
                    itemLabel: (s) => s.displayName,
                    onChanged: (v) {
                      if (v != null) {
                        AppHaptics.selection();
                        _updateConfig(
                          settings.flutedGlass.copyWith(distortionShape: v),
                        );
                      }
                    },
                  ),
                  _buildSliderRow(
                    label: 'distortion',
                    value: settings.flutedGlass.distortion,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(distortion: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'shift',
                    value: settings.flutedGlass.shift,
                    min: -1.0,
                    max: 1.0,
                    divisions: 200,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(shift: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'stretch',
                    value: settings.flutedGlass.stretch,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(stretch: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'blur',
                    value: settings.flutedGlass.blur,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(blur: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'edges',
                    value: settings.flutedGlass.edges,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(edges: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'margin',
                    value: settings.flutedGlass.margin,
                    min: 0.0,
                    max: 0.5,
                    divisions: 50,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(margin: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'grainMixer',
                    value: settings.flutedGlass.grainMixer,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(grainMixer: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'grainOverlay',
                    value: settings.flutedGlass.grainOverlay,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(grainOverlay: v),
                    ),
                  ),
                  _buildSliderRow(
                    label: 'scale',
                    value: settings.flutedGlass.scale,
                    min: 0.2,
                    max: 3.0,
                    divisions: 140,
                    onChanged: (v) => _updateConfig(
                      settings.flutedGlass.copyWith(scale: v),
                    ),
                  ),
                ],
              ),
            ),
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
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Shaders',
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Custom Sleek Segmented Switch
          Container(
            height: 30,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSegmentButton(
                  label: 'Off',
                  isSelected: !settings.isEnabled,
                  scheme: scheme,
                  onTap: () {
                    AppHaptics.selection();
                    onSettingsChanged(
                      settings.copyWith(type: ShareShaderType.none),
                    );
                  },
                ),
                _buildSegmentButton(
                  label: 'Fluted Glass',
                  isSelected: settings.type == ShareShaderType.flutedGlass,
                  scheme: scheme,
                  onTap: () {
                    AppHaptics.selection();
                    onSettingsChanged(
                      settings.copyWith(type: ShareShaderType.flutedGlass),
                    );
                  },
                ),
              ],
            ),
          ),
          if (settings.isEnabled) ...[
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Reset to default',
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Colors.white70,
              ),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              padding: EdgeInsets.zero,
              onPressed: () {
                AppHaptics.mediumImpact();
                _updateConfig(FlutedGlassShaderConfig.presetDefault);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? scheme.onPrimaryContainer : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildPresetsBar(ColorScheme scheme) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MdSpacing.sm),
        children: [
          _buildPresetChip(
            label: 'Default',
            config: FlutedGlassShaderConfig.presetDefault,
          ),
          _buildPresetChip(
            label: 'Waves',
            config: FlutedGlassShaderConfig.presetWaves,
          ),
          _buildPresetChip(
            label: 'Abstract',
            config: FlutedGlassShaderConfig.presetAbstract,
          ),
          _buildPresetChip(
            label: 'Folds',
            config: FlutedGlassShaderConfig.presetFolds,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required FlutedGlassShaderConfig config,
  }) {
    final isSelected = settings.flutedGlass == config;
    return Padding(
      padding: const EdgeInsets.only(right: MdSpacing.xs),
      child: FilterChip(
        selected: isSelected,
        label: Text(label, style: const TextStyle(fontSize: 12)),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: const Color(0xFF282828),
        selectedColor: const Color(0xFF424242),
        checkmarkColor: Colors.white,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onSelected: (_) {
          AppHaptics.selection();
          _updateConfig(config);
        },
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    bool isInteger = false,
  }) {
    final formattedValue = isInteger
        ? value.round().toString().padLeft(2, ' ')
        : value.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          // Monospace property label
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFC0C0C0),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Compact slider
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2.5,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Color(0xFF909090),
                inactiveTrackColor: Color(0xFF383838),
                thumbColor: Color(0xFFD0D0D0),
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
          const SizedBox(width: 8),
          // Monospace numeric value readout container
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              formattedValue,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFEDEDED),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Monospace property label
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFC0C0C0),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Dropdown button matching screenshot styling
          Expanded(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF282828),
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Color(0xFFC0C0C0),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFEDEDED),
                  ),
                  items: items.map((item) {
                    return DropdownMenuItem<T>(
                      value: item,
                      child: Text(itemLabel(item)),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateConfig(FlutedGlassShaderConfig config) {
    onSettingsChanged(
      settings.copyWith(
        type: ShareShaderType.flutedGlass,
        flutedGlass: config,
      ),
    );
  }
}
