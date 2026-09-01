import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:paper_shaders/paper_shaders.dart';

/// Renders a runtime [ui.Image] using paper_shaders Image Dithering effect.
class DitheredImageView extends StatefulWidget {
  const DitheredImageView({
    super.key,
    required this.image,
    this.params = const ImageDitheringParams(
      colorFront: '#eeeeee',
      colorBack: '#5452ff',
      colorHighlight: '#eeeeee',
      type: ImageDitheringType.bayer2x2,
      size: 3,
      originalColors: true,
      colorSteps: 1,
    ),
    this.opacity = 0.5,
    this.speed = 1.0,
    this.isAnimated = false,
    this.child,
  });

  /// The decoded runtime image to render with dithering shader.
  final ui.Image image;

  /// Dithering shader parameters.
  final ImageDitheringParams params;

  /// Opacity of the dithered image (default: 0.5 for 50% opacity).
  final double opacity;

  /// Speed of animation if animated.
  final double speed;

  /// Whether the shader is animated.
  final bool isAnimated;

  /// Optional child overlay (e.g. loading spinner).
  final Widget? child;

  @override
  State<DitheredImageView> createState() => _DitheredImageViewState();
}

class _DitheredImageViewState extends State<DitheredImageView>
    with SingleTickerProviderStateMixin {
  static ui.FragmentProgram? _cachedProgram;
  static Future<ui.FragmentProgram>? _loadingFuture;

  ui.FragmentProgram? _program;
  late Ticker _ticker;
  Duration? _lastElapsed;
  double _frame = 0;

  @override
  void initState() {
    super.initState();
    _frame = widget.params.frame;
    _ticker = createTicker(_tick);
    _initShader();
    if (widget.isAnimated && widget.speed != 0) {
      _ticker.start();
    }
  }

  void _initShader() {
    if (_cachedProgram != null) {
      _program = _cachedProgram;
      return;
    }

    _loadingFuture ??= ui.FragmentProgram.fromAsset(
      ImageDitheringShader.assetKey,
    );

    _loadingFuture!.then((program) {
      _cachedProgram = program;
      if (mounted) {
        setState(() {
          _program = program;
        });
      }
    }).catchError((error) {
      _loadingFuture = null;
    });
  }

  @override
  void didUpdateWidget(covariant DitheredImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimated != oldWidget.isAnimated ||
        widget.speed != oldWidget.speed) {
      if (widget.isAnimated && widget.speed != 0) {
        if (!_ticker.isActive) {
          _lastElapsed = null;
          _ticker.start();
        }
      } else {
        if (_ticker.isActive) {
          _ticker.stop();
        }
      }
    }
  }

  void _tick(Duration elapsed) {
    final last = _lastElapsed ?? elapsed;
    _lastElapsed = elapsed;
    final deltaMs = (elapsed - last).inMicroseconds / 1000;
    setState(() {
      _frame += deltaMs * widget.speed;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    final aspectRatio = widget.image.width / widget.image.height;
    final sizing = ShaderSizing.object(
      fit: ShaderFit.contain,
      imageAspectRatio: aspectRatio,
      scale: widget.params.sizing.scale,
      rotation: widget.params.sizing.rotation,
      originX: widget.params.sizing.originX,
      originY: widget.params.sizing.originY,
      offsetX: widget.params.sizing.offsetX,
      offsetY: widget.params.sizing.offsetY,
    );

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: widget.image.width.toDouble(),
        height: widget.image.height.toDouble(),
        child: Opacity(
          opacity: widget.opacity.clamp(0.0, 1.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (program != null)
                CustomPaint(
                  painter: _DitheredImagePainter(
                    program: program,
                    image: widget.image,
                    params: widget.params,
                    sizing: sizing,
                    frame: _frame,
                  ),
                  size: Size(
                    widget.image.width.toDouble(),
                    widget.image.height.toDouble(),
                  ),
                )
              else
                RawImage(
                  image: widget.image,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.low,
                ),
              if (widget.child != null) widget.child!,
            ],
          ),
        ),
      ),
    );
  }
}

class _DitheredImagePainter extends CustomPainter {
  const _DitheredImagePainter({
    required this.program,
    required this.image,
    required this.params,
    required this.sizing,
    required this.frame,
  });

  final ui.FragmentProgram program;
  final ui.Image image;
  final ImageDitheringParams params;
  final ShaderSizing sizing;
  final double frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final shader = program.fragmentShader();
    var index = 0;
    shader.setFloat(index++, size.width);
    shader.setFloat(index++, size.height);
    shader.setFloat(index++, 1.0); // u_pixelRatio
    shader.setFloat(index++, frame * 0.001); // u_time
    shader.setFloat(index++, sizing.fit.uniformValue);
    shader.setFloat(index++, sizing.scale);
    shader.setFloat(index++, sizing.rotation);
    shader.setFloat(index++, sizing.originX);
    shader.setFloat(index++, sizing.originY);
    shader.setFloat(index++, sizing.offsetX);
    shader.setFloat(index++, sizing.offsetY);
    shader.setFloat(index++, sizing.worldWidth);
    shader.setFloat(index++, sizing.worldHeight);
    shader.setFloat(index++, sizing.imageAspectRatio);

    for (final uniform in params.uniforms) {
      index = uniform.write(shader, index);
    }
    shader.setImageSampler(0, image);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _DitheredImagePainter oldDelegate) {
    return oldDelegate.program != program ||
        oldDelegate.image != image ||
        oldDelegate.params != params ||
        oldDelegate.sizing != sizing ||
        oldDelegate.frame != frame;
  }
}
