import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'share_shader_config.dart';

/// A [SnapshotPainter] that renders shader effects
/// directly on top of the live captured canvas image.
class ShareCanvasShaderPainter extends SnapshotPainter {
  ShareCanvasShaderPainter({
    required this.settings,
    this.programs = const {},
    this.noiseTexture,
    ui.FragmentProgram? flutedGlassProgram,
  }) : flutedGlassProgram =
            flutedGlassProgram ?? programs[ShareShaderType.flutedGlass];

  final ShareShaderSettings settings;
  final Map<ShareShaderType, ui.FragmentProgram?> programs;
  final ui.FragmentProgram? flutedGlassProgram;
  final ui.Image? noiseTexture;

  @override
  void paint(
    PaintingContext context,
    Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) {
    painter(context, offset);
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) {
    if (size.isEmpty) return;

    final program = programs[settings.type] ??
        (settings.type == ShareShaderType.flutedGlass
            ? flutedGlassProgram
            : null);

    if (settings.isEnabled && program != null) {
      final shader = program.fragmentShader();
      var index = 0;

      final sizing = settings.currentSizing;
      final imageAspectRatio =
          size.height > 0 ? size.width / size.height : 1.0;

      // 14 common sizing uniforms used by Paper Shaders sizing.glsl
      shader.setFloat(index++, size.width);
      shader.setFloat(index++, size.height);
      shader.setFloat(index++, 1.0); // u_pixelRatio
      shader.setFloat(index++, 0.0); // u_time (static snapshot effect)
      shader.setFloat(index++, sizing.fit.uniformValue);
      shader.setFloat(index++, sizing.scale);
      shader.setFloat(index++, sizing.rotation);
      shader.setFloat(index++, sizing.originX);
      shader.setFloat(index++, sizing.originY);
      shader.setFloat(index++, sizing.offsetX);
      shader.setFloat(index++, sizing.offsetY);
      shader.setFloat(
        index++,
        sizing.worldWidth.isFinite && sizing.worldWidth > 0
            ? sizing.worldWidth
            : size.width,
      );
      shader.setFloat(
        index++,
        sizing.worldHeight.isFinite && sizing.worldHeight > 0
            ? sizing.worldHeight
            : size.height,
      );
      shader.setFloat(index++, imageAspectRatio);

      // Active shader-specific uniforms
      for (final uniform in settings.currentUniforms) {
        index = uniform.write(shader, index);
      }

      // Pass the rendered child canvas snapshot as sampler 0
      shader.setImageSampler(0, image);

      // Pass noise texture as sampler 1 if needed
      if (settings.needsNoiseTexture && noiseTexture != null) {
        shader.setImageSampler(1, noiseTexture!);
      }

      context.canvas.save();
      context.canvas.translate(offset.dx, offset.dy);
      context.canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = shader,
      );
      context.canvas.restore();
      return;
    }

    // Default fallback: draw snapshot image as-is
    final Rect src =
        Rect.fromLTWH(0, 0, sourceSize.width, sourceSize.height);
    final Rect dst =
        Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
    final Paint paint = Paint()..filterQuality = FilterQuality.medium;
    context.canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant ShareCanvasShaderPainter oldPainter) {
    return oldPainter.settings != settings ||
        oldPainter.programs != programs ||
        oldPainter.flutedGlassProgram != flutedGlassProgram ||
        oldPainter.noiseTexture != noiseTexture;
  }
}
