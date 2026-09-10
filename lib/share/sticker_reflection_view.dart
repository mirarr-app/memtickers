import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_haptics.dart';
import 'share_light_source.dart';
import 'share_sticker_item.dart';

/// Renders a vinyl sticker on the share canvas with dynamic specular reflection
/// and directional cast shadow responding to the [ShareLightSource].
///
/// When selected, displays an outer bounding box with corner resize handles.
/// When [ShareLightSource.isEnabled] is false, renders the sticker completely flat.
class StickerReflectionView extends StatelessWidget {
  const StickerReflectionView({
    super.key,
    required this.item,
    this.light = const ShareLightSource(position: Offset.zero, isEnabled: false),
    required this.isSelected,
    required this.onTap,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.onScaleChanged,
    this.onRotateUpdate,
    this.onRotationChanged,
  });

  final ShareStickerItem item;
  final ShareLightSource light;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final VoidCallback onPanEnd;
  final ValueChanged<double>? onScaleChanged;
  final ValueChanged<DragUpdateDetails>? onRotateUpdate;
  final ValueChanged<double>? onRotationChanged;

  /// Padding around sticker to allow outer box resize and rotation handles to reside within hit-test bounds.
  static const double kHandlePadding = 36.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final file = File(item.sticker.imagePath);

    // Compute lighting reaction or flat presentation
    final isLightingActive = light.isEnabled;
    final shadowOffset = isLightingActive
        ? light.shadowOffsetFor(item.position)
        : const Offset(0, 3);
    final shadowBlur = isLightingActive
        ? light.shadowBlurFor(item.position)
        : 10.0;
    final shadowAlpha = isLightingActive
        ? (0.35 * (light.intensity / 0.85) * (1.0 - (shadowBlur / 40.0)))
            .clamp(0.08, 0.55)
        : 0.18;

    final specularOffset = isLightingActive
        ? light.specularOffset(item.position, item.rotation)
        : Alignment.center;
    final specularIntensity =
        isLightingActive ? light.specularIntensityFor(item.position) : 0.0;
    final relAngle = isLightingActive
        ? light.relativeAngleFor(item.position, item.rotation)
        : 0.0;

    final width = item.effectiveWidth;
    final height = item.effectiveHeight;
    final totalWidth = width + (kHandlePadding * 2);
    final totalHeight = height + (kHandlePadding * 2);

    // Build the reflective or flat sticker artwork
    final Widget stickerArtwork = _ReflectiveStickerArt(
      file: file,
      width: width,
      height: height,
      specularOffset: specularOffset,
      specularIntensity: specularIntensity,
      relAngle: relAngle,
      lightTone: light.tone,
      isFlipped: item.isFlipped,
      isLightingEnabled: isLightingActive,
    );

    return Positioned(
      left: item.position.dx - (totalWidth / 2),
      top: item.position.dy - (totalHeight / 2),
      width: totalWidth,
      height: totalHeight,
      child: Transform.rotate(
        angle: item.rotation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center Sticker Body with Pan & Tap Gestures
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.selection();
                  onTap();
                },
                onPanUpdate: onPanUpdate,
                onPanEnd: (_) => onPanEnd(),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Cast Shadow
                      Transform.translate(
                        offset: shadowOffset,
                        child: Image.file(
                          file,
                          width: width,
                          height: height,
                          fit: BoxFit.contain,
                          color: Colors.black.withValues(alpha: shadowAlpha),
                          colorBlendMode: BlendMode.srcIn,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),

                      // Main Sticker Art (Reflective or Flat)
                      stickerArtwork,
                    ],
                  ),
                ),
              ),
            ),

            // Selection Bounding Box Outline (Outer box indicating selection)
            if (isSelected)
              Positioned(
                left: kHandlePadding - 2,
                top: kHandlePadding - 2,
                width: width + 4,
                height: height + 4,
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: scheme.primary,
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // Outer Box Corner Resize Grips (Allows interactive scaling)
            if (isSelected) ...[
              // Top-left resize handle
              Positioned(
                top: kHandlePadding - 16,
                left: kHandlePadding - 16,
                child: _ResizeHandle(
                  colorScheme: scheme,
                  tooltip: 'Drag to resize sticker',
                  onPanUpdate: (details) {
                    final delta =
                        (-details.delta.dx - details.delta.dy) / (item.baseSize * 1.0);
                    onScaleChanged?.call((item.scale + delta).clamp(0.4, 2.5));
                  },
                  onPanEnd: () => AppHaptics.selection(),
                ),
              ),

              // Top-right resize handle
              Positioned(
                top: kHandlePadding - 16,
                right: kHandlePadding - 16,
                child: _ResizeHandle(
                  colorScheme: scheme,
                  tooltip: 'Drag to resize sticker',
                  onPanUpdate: (details) {
                    final delta =
                        (details.delta.dx - details.delta.dy) / (item.baseSize * 1.0);
                    onScaleChanged?.call((item.scale + delta).clamp(0.4, 2.5));
                  },
                  onPanEnd: () => AppHaptics.selection(),
                ),
              ),

              // Bottom-left resize handle
              Positioned(
                bottom: kHandlePadding - 16,
                left: kHandlePadding - 16,
                child: _ResizeHandle(
                  colorScheme: scheme,
                  tooltip: 'Drag to resize sticker',
                  onPanUpdate: (details) {
                    final delta =
                        (-details.delta.dx + details.delta.dy) / (item.baseSize * 1.0);
                    onScaleChanged?.call((item.scale + delta).clamp(0.4, 2.5));
                  },
                  onPanEnd: () => AppHaptics.selection(),
                ),
              ),

              // Bottom-right resize handle
              Positioned(
                bottom: kHandlePadding - 16,
                right: kHandlePadding - 16,
                child: _ResizeHandle(
                  colorScheme: scheme,
                  tooltip: 'Drag to resize sticker',
                  onPanUpdate: (details) {
                    final delta =
                        (details.delta.dx + details.delta.dy) / (item.baseSize * 1.0);
                    onScaleChanged?.call((item.scale + delta).clamp(0.4, 2.5));
                  },
                  onPanEnd: () => AppHaptics.selection(),
                ),
              ),

              // Rotation Handle Connector Stem (from top of box to rotation handle)
              Positioned(
                top: kHandlePadding - 18,
                left: (totalWidth / 2) - 1,
                width: 2,
                height: 18,
                child: Container(
                  color: scheme.primary,
                ),
              ),

              // Top Rotation Handle Knob (Allows interactive rotation)
              Positioned(
                top: kHandlePadding - 34,
                left: (totalWidth / 2) - 16,
                child: _RotateHandle(
                  colorScheme: scheme,
                  tooltip: 'Drag to rotate sticker',
                  onPanUpdate: (details) {
                    onRotateUpdate?.call(details);
                  },
                  onPanEnd: () => AppHaptics.selection(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReflectiveStickerArt extends StatelessWidget {
  const _ReflectiveStickerArt({
    required this.file,
    required this.width,
    required this.height,
    required this.specularOffset,
    required this.specularIntensity,
    required this.relAngle,
    required this.lightTone,
    required this.isFlipped,
    required this.isLightingEnabled,
  });

  final File file;
  final double width;
  final double height;
  final Alignment specularOffset;
  final double specularIntensity;
  final double relAngle;
  final ShareLightTone lightTone;
  final bool isFlipped;
  final bool isLightingEnabled;

  @override
  Widget build(BuildContext context) {
    Widget imageCore = Image.file(
      file,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stack) => SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.broken_image_rounded,
            color: Theme.of(context).colorScheme.outline,
            size: 32,
          ),
        ),
      ),
    );

    if (isFlipped) {
      imageCore = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: imageCore,
      );
    }

    // Flat mode: return clean unmodified image without specular lighting
    if (!isLightingEnabled) {
      return imageCore;
    }

    // Specular shine layer:
    // Uses BlendMode.srcATop so reflection adheres strictly to the sticker outline.
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        // Compute directional sweep coordinates based on angle of incoming light
        final cosA = math.cos(relAngle);
        final sinA = math.sin(relAngle);
        final sweepBegin = Alignment(cosA * 0.9, sinA * 0.9);
        final sweepEnd = Alignment(-cosA * 0.9, -sinA * 0.9);

        // Linear gloss sheen band
        return LinearGradient(
          begin: sweepBegin,
          end: sweepEnd,
          colors: [
            lightTone.color.withValues(alpha: 0.65 * specularIntensity),
            lightTone.color.withValues(alpha: 0.28 * specularIntensity),
            Colors.white.withValues(alpha: 0.0),
            lightTone.color.withValues(alpha: 0.15 * specularIntensity),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.22, 0.45, 0.70, 1.0],
        ).createShader(bounds);
      },
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          // Radial specular highlight hotspot centered toward the light source
          return RadialGradient(
            center: specularOffset,
            radius: 0.82,
            colors: [
              Colors.white.withValues(alpha: 0.85 * specularIntensity),
              lightTone.color.withValues(alpha: 0.40 * specularIntensity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.38, 1.0],
          ).createShader(bounds);
        },
        child: imageCore,
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.colorScheme,
    required this.tooltip,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final ColorScheme colorScheme;
  final String tooltip;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final VoidCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      onPanEnd: (_) => onPanEnd(),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Tooltip(
            message: tooltip,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RotateHandle extends StatelessWidget {
  const _RotateHandle({
    required this.colorScheme,
    required this.tooltip,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final ColorScheme colorScheme;
  final String tooltip;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final VoidCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      onPanEnd: (_) => onPanEnd(),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Tooltip(
            message: tooltip,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary,
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.rotate_right_rounded,
                size: 14,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

