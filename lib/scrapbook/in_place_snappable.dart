import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// In-place Thanos snap particle disintegration effect.
///
/// Unlike standard overlay-portal snappable widgets, [InPlaceSnappable] renders
/// the disintegration shader in-place within the widget tree. This preserves
/// ancestor transformations such as [Transform.scale], [Transform.rotate],
/// and [InteractiveViewer] pan/zoom matrices without sudden jumps or shrinking.
///
/// It also provides generous outer bounds via [outerPadding] so that ascending
/// particles dissolve naturally without hitting abrupt rectangular boundaries.
class InPlaceSnappable extends StatefulWidget {
  const InPlaceSnappable({
    super.key,
    required this.child,
    required this.animation,
    this.outerPadding = const EdgeInsets.fromLTRB(200, 320, 200, 100),
    this.particleLifetime = 0.65,
    this.fadeOutDuration = 0.35,
    this.particleSpeed = 1.1,
    this.relativeParticleSize = 0.015,
  });

  final Widget child;
  final Animation<double> animation;
  final EdgeInsets outerPadding;
  final double particleLifetime;
  final double fadeOutDuration;
  final double particleSpeed;
  final double relativeParticleSize;

  static const String shaderAsset =
      'packages/thanos_snap_effect/shader/thanos_snap_effect.glsl';

  @override
  State<InPlaceSnappable> createState() => _InPlaceSnappableState();
}

class _InPlaceSnappableState extends State<InPlaceSnappable> {
  static ui.FragmentProgram? _cachedProgram;
  static Future<ui.FragmentProgram?>? _programFuture;

  final GlobalKey _boundaryKey = GlobalKey();
  ui.FragmentShader? _shader;
  ui.Image? _snapshotImage;
  Size? _snapshotSize;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initShader();
    widget.animation.addListener(_onAnimationChanged);
    if (widget.animation.value > 0.0) {
      _startCapture();
    }
  }

  @override
  void didUpdateWidget(covariant InPlaceSnappable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      oldWidget.animation.removeListener(_onAnimationChanged);
      widget.animation.addListener(_onAnimationChanged);
      if (widget.animation.value > 0.0 && _snapshotImage == null) {
        _startCapture();
      }
    }
  }

  Future<void> _initShader() async {
    if (_cachedProgram != null) {
      if (mounted) {
        setState(() {
          _shader = _cachedProgram!.fragmentShader();
        });
      }
      return;
    }

    _programFuture ??= () async {
      try {
        final program =
            await ui.FragmentProgram.fromAsset(InPlaceSnappable.shaderAsset);
        _cachedProgram = program;
        return program;
      } catch (e) {
        debugPrint('Note: Fragment shader not available in current runtime ($e)');
        _programFuture = null;
        return null;
      }
    }();

    final program = await _programFuture;
    if (mounted && program != null) {
      setState(() {
        _shader = program.fragmentShader();
      });
    }
  }

  void _onAnimationChanged() {
    if (widget.animation.value == 0.0) {
      _snapshotImage?.dispose();
      _snapshotImage = null;
      _snapshotSize = null;
      _isCapturing = false;
      if (mounted) setState(() {});
      return;
    }

    if (_snapshotImage == null && !_isCapturing) {
      _startCapture();
    } else {
      if (mounted) setState(() {});
    }
  }

  void _startCapture() {
    if (_isCapturing) return;
    _isCapturing = true;
    _capture();
  }

  Future<void> _capture() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null || boundary.debugNeedsPaint) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && _snapshotImage == null) {
            _capture();
          }
        });
        return;
      }

      final size = boundary.size;
      final image = await boundary.toImage(pixelRatio: 1.0);
      if (!mounted) {
        image.dispose();
        return;
      }

      setState(() {
        _snapshotImage = image;
        _snapshotSize = size;
        _isCapturing = false;
      });
    } catch (e) {
      _isCapturing = false;
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_onAnimationChanged);
    _snapshotImage?.dispose();
    _snapshotImage = null;
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSnapping = widget.animation.value > 0.0;
    final shader = _shader;
    final image = _snapshotImage;
    final size = _snapshotSize;

    if (isSnapping && shader != null && image != null && size != null) {
      return SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(
          painter: _InPlaceThanosShaderPainter(
            shader: shader,
            image: image,
            originalSize: size,
            animationValue: widget.animation.value,
            outerPadding: widget.outerPadding,
            particleLifetime: widget.particleLifetime,
            fadeOutDuration: widget.fadeOutDuration,
            particleSpeed: widget.particleSpeed,
            relativeParticleSize: widget.relativeParticleSize,
          ),
        ),
      );
    }

    return RepaintBoundary(
      key: _boundaryKey,
      child: widget.child,
    );
  }
}

class _InPlaceThanosShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image image;
  final Size originalSize;
  final double animationValue;
  final EdgeInsets outerPadding;
  final double particleLifetime;
  final double fadeOutDuration;
  final double particleSpeed;
  final double relativeParticleSize;

  _InPlaceThanosShaderPainter({
    required this.shader,
    required this.image,
    required this.originalSize,
    required this.animationValue,
    required this.outerPadding,
    required this.particleLifetime,
    required this.fadeOutDuration,
    required this.particleSpeed,
    required this.relativeParticleSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = originalSize.width;
    final height = originalSize.height;
    if (width <= 0 || height <= 0) return;

    final particlesInRow = (1.0 / relativeParticleSize).ceil().clamp(2, 200);
    final relativeHeight = (width * relativeParticleSize) / height;
    final particlesInColumn = (1.0 / relativeHeight).ceil().clamp(2, 200);

    shader.setFloat(0, animationValue.clamp(0.0, 1.0));
    shader.setFloat(1, particleLifetime);
    shader.setFloat(2, fadeOutDuration);
    shader.setFloat(3, particlesInRow.toDouble());
    shader.setFloat(4, particlesInColumn.toDouble());
    shader.setFloat(5, particleSpeed);
    shader.setFloat(6, width);
    shader.setFloat(7, height);
    shader.setImageSampler(0, image);

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(
        -outerPadding.left,
        -outerPadding.top,
        width + outerPadding.horizontal,
        height + outerPadding.vertical,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _InPlaceThanosShaderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.image != image ||
        oldDelegate.originalSize != originalSize;
  }
}
