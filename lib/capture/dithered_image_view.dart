import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:paper_shaders/paper_shaders.dart';

import '../theme/app_haptics.dart';

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
      size: 7,
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

/// Renders an image transitioning from its original clean appearance into the
/// stylized dithered memory effect using a sleek laser scanline reveal,
/// followed by an ambient breathing glow.
class AnimatedDitherView extends StatefulWidget {
  const AnimatedDitherView({
    super.key,
    this.image,
    this.imageBytes,
    this.params = const ImageDitheringParams(
      colorFront: '#eeeeee',
      colorBack: '#5452ff',
      colorHighlight: '#eeeeee',
      type: ImageDitheringType.bayer2x2,
      size: 7,
      originalColors: true,
      colorSteps: 1,
    ),
    this.targetDitherOpacity = 0.55,
    this.scanDuration = const Duration(milliseconds: 700),
    this.child,
  });

  final ui.Image? image;
  final Uint8List? imageBytes;
  final ImageDitheringParams params;
  final double targetDitherOpacity;
  final Duration scanDuration;
  final Widget? child;

  @override
  State<AnimatedDitherView> createState() => _AnimatedDitherViewState();
}

class _AnimatedDitherViewState extends State<AnimatedDitherView>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final AnimationController _pulseController;
  late final Animation<double> _scanAnimation;
  late final Animation<double> _pulseAnimation;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: widget.scanDuration,
    );
    _scanAnimation = CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: -0.05, end: 0.07).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    _scanController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_hapticFired) {
          _hapticFired = true;
          AppHaptics.selection();
        }
        if (mounted) {
          _pulseController.repeat(reverse: true);
        }
      }
    });

    // Start scan
    _scanController.forward();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_scanController, _pulseController]),
      builder: (context, _) {
        final scanProgress = _scanAnimation.value;
        final isScanning = scanProgress < 1.0;
        final pulseDelta =
            _scanController.isCompleted ? _pulseAnimation.value : 0.0;
        final ditherOpacity =
            (widget.targetDitherOpacity + pulseDelta).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final availW = constraints.maxWidth;
            final availH = constraints.maxHeight;

            double imgAspect = 1.0;
            if (widget.image != null && widget.image!.height > 0) {
              imgAspect = widget.image!.width / widget.image!.height;
            }

            double renderedW;
            double renderedH;
            final boxAspect = availW / availH;
            if (boxAspect > imgAspect) {
              renderedH = availH;
              renderedW = availH * imgAspect;
            } else {
              renderedW = availW;
              renderedH = availW / imgAspect;
            }

            return Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                Center(
                  child: SizedBox(
                    width: renderedW,
                    height: renderedH,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Layer 1: Base clean original image
                        if (widget.image != null)
                          RawImage(
                            image: widget.image!,
                            fit: BoxFit.contain,
                          )
                        else if (widget.imageBytes != null)
                          Image.memory(
                            widget.imageBytes!,
                            fit: BoxFit.contain,
                          ),

                        // Layer 2: Dithered image revealed by scan progress
                        if (widget.image != null && scanProgress > 0.0)
                          ClipRect(
                            clipper: _ScanRevealClipper(scanProgress),
                            child: DitheredImageView(
                              image: widget.image!,
                              params: widget.params,
                              opacity: ditherOpacity,
                            ),
                          )
                        else if (widget.imageBytes != null && scanProgress > 0.0)
                          ClipRect(
                            clipper: _ScanRevealClipper(scanProgress),
                            child: Opacity(
                              opacity: ditherOpacity,
                              child: Image.memory(
                                widget.imageBytes!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                        // Layer 3: Laser scan beam moving downwards across image
                        if (isScanning &&
                            scanProgress > 0.005 &&
                            scanProgress < 0.995)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LaserScanPainter(
                                progress: scanProgress,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Layer 4: Child overlay (e.g. loading spinner and status)
                if (widget.child != null) widget.child!,
              ],
            );
          },
        );
      },
    );
  }
}

class _ScanRevealClipper extends CustomClipper<Rect> {
  const _ScanRevealClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height * progress.clamp(0.0, 1.0),
    );
  }

  @override
  bool shouldReclip(covariant _ScanRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _LaserScanPainter extends CustomPainter {
  const _LaserScanPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0.0 || progress >= 1.0) return;

    final y = size.height * progress;

    // 1. Soft atmospheric glow above and below the beam
    const glowHeight = 36.0;
    final glowRect =
        Rect.fromLTWH(0, y - glowHeight / 2, size.width, glowHeight);
    final glowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y - glowHeight / 2),
        Offset(0, y + glowHeight / 2),
        [
          Colors.transparent,
          color.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(glowRect, glowPaint);

    // 2. Outer beam line with vibrant primary color
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    // 3. Bright core line in the center
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), corePaint);
  }

  @override
  bool shouldRepaint(covariant _LaserScanPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

