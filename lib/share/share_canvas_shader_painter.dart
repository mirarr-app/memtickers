import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'share_shader_config.dart';

/// A [SnapshotPainter] that renders shader effects (such as Fluted Glass)
/// directly on top of the live captured canvas image.
class ShareCanvasShaderPainter extends SnapshotPainter {
  ShareCanvasShaderPainter({
    required this.settings,
    this.flutedGlassProgram,
  });

  final ShareShaderSettings settings;
  final ui.FragmentProgram? flutedGlassProgram;

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

    if (settings.type == ShareShaderType.flutedGlass &&
        flutedGlassProgram != null) {
      final shader = flutedGlassProgram!.fragmentShader();
      var index = 0;

      // 14 common sizing uniforms used by Paper Shaders sizing.glsl
      shader.setFloat(index++, size.width);
      shader.setFloat(index++, size.height);
      shader.setFloat(index++, 1.0); // u_pixelRatio
      shader.setFloat(index++, 0.0); // u_time (static snapshot effect)
      shader.setFloat(index++, 2.0); // u_fit (ShaderFit.cover)
      shader.setFloat(index++, settings.flutedGlass.scale);
      shader.setFloat(index++, 0.0); // u_rotation
      shader.setFloat(index++, 0.5); // u_originX
      shader.setFloat(index++, 0.5); // u_originY
      shader.setFloat(index++, 0.0); // u_offsetX
      shader.setFloat(index++, 0.0); // u_offsetY
      shader.setFloat(index++, size.width); // u_worldWidth
      shader.setFloat(index++, size.height); // u_worldHeight
      shader.setFloat(
        index++,
        size.height > 0 ? size.width / size.height : 1.0,
      ); // u_imageAspectRatio

      // Fluted glass specific uniforms
      for (final uniform in settings.flutedGlass.uniforms) {
        index = uniform.write(shader, index);
      }

      // Pass the rendered child canvas snapshot as sampler2D
      shader.setImageSampler(0, image);

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
    final Rect src = Rect.fromLTWH(0, 0, sourceSize.width, sourceSize.height);
    final Rect dst = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
    final Paint paint = Paint()..filterQuality = FilterQuality.medium;
    context.canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant ShareCanvasShaderPainter oldPainter) {
    return oldPainter.settings != settings ||
        oldPainter.flutedGlassProgram != flutedGlassProgram;
  }
}
