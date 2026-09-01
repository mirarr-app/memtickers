import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Renders a morph animation between [imageABytes] (the initial image)
/// and [imageBBytes] (the target sticker) using the portrait_morph fragment shader.
class PortraitMorphView extends StatefulWidget {
  const PortraitMorphView({
    super.key,
    required this.imageABytes,
    required this.imageBBytes,
    this.initialProgress = 0.0,
    this.autoAnimate = true,
    this.duration = const Duration(milliseconds: 900),
    this.onCompleted,
    this.interactive = true,
    this.fallbackFit = BoxFit.contain,
  });

  /// The source image (e.g. original photo).
  final Uint8List imageABytes;

  /// The morphed target image (e.g. cut-out sticker).
  final Uint8List imageBBytes;

  /// Starting progress (0.0 = imageA, 1.0 = imageB).
  final double initialProgress;

  /// Whether to automatically morph from progress 0.0 to 1.0 when ready.
  final bool autoAnimate;

  /// Duration of the automatic morph animation.
  final Duration duration;

  /// Callback fired when the morph animation finishes.
  final VoidCallback? onCompleted;

  /// Whether to allow interactive touch/drag comparisons after morphing.
  final bool interactive;

  /// Fallback image fit.
  final BoxFit fallbackFit;

  @override
  State<PortraitMorphView> createState() => _PortraitMorphViewState();
}

class _PortraitMorphViewState extends State<PortraitMorphView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static ui.FragmentProgram? _cachedProgram;
  static Future<ui.FragmentProgram>? _programFuture;

  static const String _shaderAssetKey =
      'packages/portrait_morph/shaders/portrait_morph.frag';

  ui.FragmentShader? _shader;
  ui.Image? _imageA;
  ui.Image? _imageB;
  bool _failed = false;

  late AnimationController _animController;
  late Animation<double> _animation;

  double _interactiveProgress = 1.0;
  bool _isInteracting = false;
  double _time = 0.0;
  Timer? _timeTimer;

  Offset _origin = const Offset(0.1, 0.1);
  Offset _direction = const Offset(1.0, 0.8);
  Offset? _lastPointerUv;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animController = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.autoAnimate ? 0.0 : widget.initialProgress,
    );

    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    )..addListener(() {
        if (!_isInteracting) {
          setState(() {});
        }
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onCompleted?.call();
        }
      });

    if (widget.autoAnimate) {
      _animController.forward();
    }

    _interactiveProgress = widget.initialProgress;
    _load();
  }

  static Future<ui.FragmentProgram> _getOrLoadProgram() {
    if (_cachedProgram != null) {
      return Future.value(_cachedProgram!);
    }
    return _programFuture ??=
        ui.FragmentProgram.fromAsset(_shaderAssetKey).then((p) {
      _cachedProgram = p;
      return p;
    });
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _getOrLoadProgram(),
        _decodeImage(widget.imageABytes),
        _decodeImage(widget.imageBBytes),
      ]);

      if (!mounted) {
        (results[1] as ui.Image).dispose();
        (results[2] as ui.Image).dispose();
        return;
      }

      final program = results[0] as ui.FragmentProgram;
      setState(() {
        _shader = program.fragmentShader();
        _imageA = results[1] as ui.Image;
        _imageB = results[2] as ui.Image;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Offset _edgeDirection(double x, double y) {
    final double dxLeft = x;
    final double dxRight = 1.0 - x;
    final double dyBottom = y;
    final double dyTop = 1.0 - y;
    final double minDist = math.min(
      math.min(dxLeft, dxRight),
      math.min(dyBottom, dyTop),
    );
    if (minDist == dxLeft) return const Offset(1, 0);
    if (minDist == dxRight) return const Offset(-1, 0);
    if (minDist == dyBottom) return const Offset(0, 1);
    return const Offset(0, -1);
  }

  Offset _toUv(Offset local, Size size) {
    final double x = (local.dx / size.width).clamp(0.0, 1.0);
    final double y = (local.dy / size.height).clamp(0.0, 1.0);
    return Offset(x, y);
  }

  void _onPointerDown(Offset local, Size size) {
    if (!widget.interactive) return;
    final Offset uv = _toUv(local, size);
    setState(() {
      _origin = uv;
      _direction = _edgeDirection(uv.dx, uv.dy);
      _lastPointerUv = uv;
      _isInteracting = true;
      _interactiveProgress = 0.0; // reveal image A on press
    });
  }

  void _onPointerMove(Offset local, Size size) {
    if (!widget.interactive || !_isInteracting) return;
    final Offset uv = _toUv(local, size);
    final Offset? last = _lastPointerUv;
    if (last != null) {
      final Offset v = uv - last;
      final double mag = v.distance;
      if (mag > 0.01) {
        setState(() {
          _direction = v / mag;
        });
      }
    }
    _lastPointerUv = uv;
  }

  void _onPointerUp(Offset local, Size size) {
    if (!widget.interactive) return;
    final Offset uv = _toUv(local, size);
    final Offset edge = _edgeDirection(uv.dx, uv.dy);
    setState(() {
      _origin = uv;
      _direction = Offset(-edge.dx, -edge.dy);
      _isInteracting = false;
      _interactiveProgress = 1.0; // return to sticker image B
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeTimer?.cancel();
    _animController.dispose();
    _imageA?.dispose();
    _imageB?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool ready =
        !_failed && _shader != null && _imageA != null && _imageB != null;

    if (!ready) {
      return Image.memory(
        widget.imageBBytes,
        fit: widget.fallbackFit,
      );
    }

    final imageA = _imageA!;
    final imageB = _imageB!;
    final double naturalWidth = imageA.width.toDouble();
    final double naturalHeight = imageA.height.toDouble();
    final double progress = _isInteracting ? _interactiveProgress : _animation.value;

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: naturalWidth,
        height: naturalHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size size = constraints.biggest;

            final painter = CustomPaint(
              size: size,
              painter: _MorphShaderPainter(
                shader: _shader!,
                imageA: imageA,
                imageB: imageB,
                progress: progress,
                time: _time,
                origin: _origin,
                direction: _direction,
              ),
            );

            if (!widget.interactive) {
              return painter;
            }

            return Listener(
              onPointerDown: (e) => _onPointerDown(e.localPosition, size),
              onPointerMove: (e) => _onPointerMove(e.localPosition, size),
              onPointerUp: (e) => _onPointerUp(e.localPosition, size),
              onPointerCancel: (e) => _onPointerUp(e.localPosition, size),
              child: painter,
            );
          },
        ),
      ),
    );
  }
}

class _MorphShaderPainter extends CustomPainter {
  const _MorphShaderPainter({
    required this.shader,
    required this.imageA,
    required this.imageB,
    required this.progress,
    required this.time,
    required this.origin,
    required this.direction,
  });

  final ui.FragmentShader shader;
  final ui.Image imageA;
  final ui.Image imageB;
  final double progress;
  final double time;
  final Offset origin;
  final Offset direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, imageA.width.toDouble())
      ..setFloat(3, imageA.height.toDouble())
      ..setFloat(4, progress)
      ..setFloat(5, time)
      ..setFloat(6, origin.dx)
      ..setFloat(7, origin.dy)
      ..setFloat(8, direction.dx)
      ..setFloat(9, direction.dy)
      ..setImageSampler(0, imageA)
      ..setImageSampler(1, imageB);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _MorphShaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.time != time ||
        oldDelegate.origin != origin ||
        oldDelegate.direction != direction ||
        oldDelegate.imageA != imageA ||
        oldDelegate.imageB != imageB;
  }
}
