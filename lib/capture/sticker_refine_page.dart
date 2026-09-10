import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

import '../theme/app_haptics.dart';
import '../theme/spacing.dart';
import 'isnet_cutout.dart';
import 'sticker_processor.dart';

class StickerRefinePage extends StatefulWidget {
  const StickerRefinePage({
    super.key,
    this.imagePath,
    this.cutoutPath,
    required this.saturation,
    required this.brightness,
    required this.processor,
  });

  final String? imagePath;
  final String? cutoutPath;
  final double saturation;
  final double brightness;
  final StickerProcessor processor;

  @override
  State<StickerRefinePage> createState() => _StickerRefinePageState();
}

class _StickerRefinePageState extends State<StickerRefinePage> {
  bool _loading = true;
  String? _errorMessage;

  String? _sessionId;
  int _imageW = 0;
  int _imageH = 0;
  String? _workingImagePath;
  String? _overlayPath;

  bool _canUndo = false;
  bool _canRedo = false;
  bool _applyingStroke = false;

  // Tools
  bool _isRestore = true; // true = restore (+), false = erase (-)
  bool _isSmart = true; // true = smart edge snapping, false = manual
  double _brushRadius = 26.0;
  double _bgOpacity = 0.25;
  bool _previewVinyl = false;
  Uint8List? _vinylPreviewBytes;
  bool _generatingVinyl = false;

  // Zoom / Pan transformation
  final TransformationController _transformController =
      TransformationController();
  // Gesture & Drawing Tracking
  final Map<int, Offset> _activePointers = {};
  final List<Offset> _currentStrokePoints = [];
  final List<Offset> _committingStrokePoints = [];
  Offset? _cursorCanvasPos;

  // Two-finger gesture tracking
  int _pointerCount = 0;
  double? _initialDistance;
  Matrix4? _initialTransform;
  Offset? _initialMidpoint;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    try {
      final info = await IsnetCutout.startRefineSession(
        imagePath: widget.imagePath,
        cutoutPath: widget.cutoutPath,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = info.sessionId;
        _imageW = info.width;
        _imageH = info.height;
        _workingImagePath = info.workingImagePath;
        _overlayPath = info.overlayPath;
        _canUndo = info.canUndo;
        _canRedo = info.canRedo;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not start outline editor: $e';
        _loading = false;
      });
    }
  }

  Future<void> _onPointerDown(PointerDownEvent event, BoxConstraints constraints) async {
    _pointerCount++;
    _activePointers[event.pointer] = event.localPosition;

    if (_pointerCount >= 2) {
      // Switch to pan/zoom gesture, discard pending 1-finger stroke
      _currentStrokePoints.clear();
      _cursorCanvasPos = null;
      _initPinchTransform();
      setState(() {});
      return;
    }

    if (_pointerCount == 1 && !_applyingStroke && !_previewVinyl) {
      final imgPt = _canvasToImageCoords(event.localPosition, constraints);
      if (imgPt != null) {
        _currentStrokePoints.clear();
        _currentStrokePoints.add(imgPt);
        _cursorCanvasPos = event.localPosition;
        setState(() {});
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event, BoxConstraints constraints) {
    _activePointers[event.pointer] = event.localPosition;

    if (_pointerCount >= 2) {
      _updatePinchTransform();
      return;
    }

    if (_pointerCount == 1 && !_applyingStroke && !_previewVinyl) {
      final imgPt = _canvasToImageCoords(event.localPosition, constraints);
      if (imgPt != null) {
        _currentStrokePoints.add(imgPt);
        _cursorCanvasPos = event.localPosition;
        setState(() {});
      }
    }
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    _activePointers.remove(event.pointer);
    _pointerCount = math.max(0, _pointerCount - 1);

    if (_pointerCount < 2) {
      _initialDistance = null;
      _initialTransform = null;
      _initialMidpoint = null;
    }

    if (_pointerCount == 0) {
      _cursorCanvasPos = null;
      if (_currentStrokePoints.isNotEmpty && !_previewVinyl) {
        await _commitCurrentStroke();
      } else {
        setState(() {});
      }
    } else {
      setState(() {});
    }
  }

  Future<void> _commitCurrentStroke() async {
    final sId = _sessionId;
    if (sId == null || _currentStrokePoints.isEmpty) return;

    final pointsCopy = List<Offset>.from(_currentStrokePoints);
    _committingStrokePoints.clear();
    _committingStrokePoints.addAll(_currentStrokePoints);
    _currentStrokePoints.clear();
    _cursorCanvasPos = null;
    _applyingStroke = true;
    setState(() {});

    final flatPoints = <double>[];
    for (final p in pointsCopy) {
      flatPoints.add(p.dx);
      flatPoints.add(p.dy);
    }

    try {
      AppHaptics.selection();
      final result = await IsnetCutout.applyRefineStroke(
        sessionId: sId,
        points: flatPoints,
        radius: _brushRadius,
        isRestore: _isRestore,
        isSmart: _isSmart,
      );
      if (!mounted) return;
      if (result.overlayPath != null) {
        try {
          final newProvider = FileImage(File(result.overlayPath!));
          await precacheImage(newProvider, context);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        if (result.overlayPath != null) {
          _overlayPath = result.overlayPath;
        }
        _committingStrokePoints.clear();
        _canUndo = result.canUndo;
        _canRedo = result.canRedo;
        _applyingStroke = false;
      });

      if (_previewVinyl) {
        _updateVinylPreview();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _committingStrokePoints.clear();
        _applyingStroke = false;
      });
      _showSnack('Stroke error: $e');
    }
  }

  void _initPinchTransform() {
    if (_activePointers.length >= 2) {
      final pts = _activePointers.values.toList();
      _initialDistance = (pts[0] - pts[1]).distance;
      _initialMidpoint = (pts[0] + pts[1]) / 2;
      _initialTransform = _transformController.value.clone();
    }
  }

  void _updatePinchTransform() {
    if (_activePointers.length < 2 ||
        _initialDistance == null ||
        _initialTransform == null ||
        _initialMidpoint == null) {
      return;
    }

    final pts = _activePointers.values.toList();
    final currentDist = (pts[0] - pts[1]).distance;
    final currentMidpoint = (pts[0] + pts[1]) / 2;

    if (_initialDistance! > 0) {
      final scaleFactor = (currentDist / _initialDistance!).clamp(0.6, 6.0);
      final panDelta = currentMidpoint - _initialMidpoint!;

      final m = _initialTransform!.clone();
      // Apply translation delta
      m.multiply(Matrix4.translationValues(panDelta.dx, panDelta.dy, 0.0));
      // Scale around midpoint
      m.multiply(Matrix4.translationValues(_initialMidpoint!.dx, _initialMidpoint!.dy, 0.0));
      m.multiply(Matrix4.diagonal3Values(scaleFactor, scaleFactor, 1.0));
      m.multiply(Matrix4.translationValues(-_initialMidpoint!.dx, -_initialMidpoint!.dy, 0.0));

      _transformController.value = m;
    }
  }

  Offset? _canvasToImageCoords(Offset localCanvas, BoxConstraints constraints) {
    if (_imageW <= 0 || _imageH <= 0) return null;

    final fittedRect = _computeFittedImageRect(constraints);
    final Matrix4 inverse = Matrix4.inverted(_transformController.value);
    final Offset transformed = MatrixUtils.transformPoint(inverse, localCanvas);

    if (!fittedRect.contains(transformed)) {
      // Allow dragging slightly outside bounds clamped to edge
      final clampedX = transformed.dx.clamp(fittedRect.left, fittedRect.right);
      final clampedY = transformed.dy.clamp(fittedRect.top, fittedRect.bottom);
      final normX = (clampedX - fittedRect.left) / fittedRect.width;
      final normY = (clampedY - fittedRect.top) / fittedRect.height;
      return Offset(normX * _imageW, normY * _imageH);
    }

    final normX = (transformed.dx - fittedRect.left) / fittedRect.width;
    final normY = (transformed.dy - fittedRect.top) / fittedRect.height;
    return Offset(normX * _imageW, normY * _imageH);
  }

  Rect _computeFittedImageRect(BoxConstraints constraints) {
    if (_imageW <= 0 || _imageH <= 0) {
      return Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight);
    }
    final imgAspect = _imageW / _imageH;
    final boxAspect = constraints.maxWidth / constraints.maxHeight;

    double w, h;
    if (boxAspect > imgAspect) {
      h = constraints.maxHeight;
      w = h * imgAspect;
    } else {
      w = constraints.maxWidth;
      h = w / imgAspect;
    }
    final left = (constraints.maxWidth - w) / 2;
    final top = (constraints.maxHeight - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  Future<void> _undo() async {
    final sId = _sessionId;
    if (sId == null || !_canUndo || _applyingStroke) return;
    AppHaptics.lightImpact();
    try {
      final res = await IsnetCutout.undoRefineStroke(sId);
      if (!mounted) return;
      if (res.overlayPath != null) {
        try {
          await precacheImage(FileImage(File(res.overlayPath!)), context);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        if (res.overlayPath != null) {
          _overlayPath = res.overlayPath;
        }
        _canUndo = res.canUndo;
        _canRedo = res.canRedo;
      });
      if (_previewVinyl) _updateVinylPreview();
    } catch (e) {
      _showSnack('Undo failed: $e');
    }
  }

  Future<void> _redo() async {
    final sId = _sessionId;
    if (sId == null || !_canRedo || _applyingStroke) return;
    AppHaptics.lightImpact();
    try {
      final res = await IsnetCutout.redoRefineStroke(sId);
      if (!mounted) return;
      if (res.overlayPath != null) {
        try {
          await precacheImage(FileImage(File(res.overlayPath!)), context);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        if (res.overlayPath != null) {
          _overlayPath = res.overlayPath;
        }
        _canUndo = res.canUndo;
        _canRedo = res.canRedo;
      });
      if (_previewVinyl) _updateVinylPreview();
    } catch (e) {
      _showSnack('Redo failed: $e');
    }
  }

  Future<void> _resetToAi() async {
    final sId = _sessionId;
    if (sId == null || _applyingStroke) return;
    AppHaptics.mediumImpact();
    try {
      final res = await IsnetCutout.resetRefine(sId);
      if (!mounted) return;
      if (res.overlayPath != null) {
        try {
          await precacheImage(FileImage(File(res.overlayPath!)), context);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        if (res.overlayPath != null) {
          _overlayPath = res.overlayPath;
        }
        _canUndo = res.canUndo;
        _canRedo = res.canRedo;
      });
      if (_previewVinyl) _updateVinylPreview();
      _showSnack('Reset to AI cutout');
    } catch (e) {
      _showSnack('Reset failed: $e');
    }
  }

  Future<void> _toggleVinylPreview() async {
    final next = !_previewVinyl;
    setState(() {
      _previewVinyl = next;
    });
    AppHaptics.selection();
    if (next) {
      await _updateVinylPreview();
    }
  }

  Future<void> _updateVinylPreview() async {
    final path = _overlayPath;
    if (path == null) return;
    setState(() {
      _generatingVinyl = true;
    });
    try {
      final rawBytes = await File(path).readAsBytes();
      final dieCut = await widget.processor.dieCut(
        rawBytes,
        saturation: widget.saturation,
        brightness: widget.brightness,
      );
      if (!mounted) return;
      setState(() {
        _vinylPreviewBytes = dieCut;
        _generatingVinyl = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generatingVinyl = false;
      });
    }
  }

  void _resetZoom() {
    AppHaptics.lightImpact();
    _transformController.value = Matrix4.identity();
  }

  Future<void> _finishAndSave() async {
    final sId = _sessionId;
    if (sId == null) return;
    AppHaptics.mediumImpact();
    setState(() {
      _loading = true;
    });
    try {
      final cropResult = await IsnetCutout.finishRefineSession(sId);
      if (!mounted) return;
      Navigator.of(context).pop(cropResult);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      _showSnack('Could not finalize sticker: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: scheme.primary),
                    const SizedBox(height: MdSpacing.md),
                    Text(
                      'Preparing outline editor…',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(MdSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 48, color: scheme.error),
                          const SizedBox(height: MdSpacing.md),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                          const SizedBox(height: MdSpacing.lg),
                          M3EFilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Go back'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      // Canvas viewport
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildCanvas(constraints, scheme);
                          },
                        ),
                      ),

                      // Top navigation & actions bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildTopBar(scheme),
                      ),

                      // Floating Zoom Reset Button
                      Positioned(
                        right: MdSpacing.md,
                        top: 68,
                        child: _buildFloatingZoomReset(scheme),
                      ),

                      // Bottom Floating Controls Card
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildBottomControls(scheme),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MdSpacing.sm,
        vertical: MdSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Cancel',
          ),
          const Spacer(),

          // Undo
          IconButton(
            onPressed: _canUndo && !_applyingStroke ? _undo : null,
            icon: const Icon(Icons.undo_rounded),
            color: _canUndo ? Colors.white : Colors.white24,
            tooltip: 'Undo',
          ),

          // Redo
          IconButton(
            onPressed: _canRedo && !_applyingStroke ? _redo : null,
            icon: const Icon(Icons.redo_rounded),
            color: _canRedo ? Colors.white : Colors.white24,
            tooltip: 'Redo',
          ),

          // Reset to AI
          IconButton(
            onPressed: !_applyingStroke ? _resetToAi : null,
            icon: const Icon(Icons.restart_alt_rounded),
            color: Colors.white,
            tooltip: 'Reset to AI cutout',
          ),

          // Vinyl Sticker Preview Toggle
          IconButton(
            onPressed: _toggleVinylPreview,
            icon: _generatingVinyl
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : Icon(
                    _previewVinyl
                        ? Icons.verified_rounded
                        : Icons.auto_awesome_rounded,
                    color: _previewVinyl ? scheme.primary : Colors.white,
                  ),
            tooltip: _previewVinyl ? 'Show Cutout' : 'Preview Sticker',
          ),

          const SizedBox(width: MdSpacing.xs),

          // Done Button
          M3EFilledButton(
            size: M3EButtonSize.sm,
            onPressed: !_applyingStroke ? _finishAndSave : null,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingZoomReset(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        iconSize: 20,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        onPressed: _resetZoom,
        icon: const Icon(Icons.fit_screen_rounded, color: Colors.white),
        tooltip: 'Fit to screen',
      ),
    );
  }

  Widget _buildCanvas(BoxConstraints constraints, ColorScheme scheme) {
    final fittedRect = _computeFittedImageRect(constraints);

    return Listener(
      onPointerDown: (e) => _onPointerDown(e, constraints),
      onPointerMove: (e) => _onPointerMove(e, constraints),
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) {
        _pointerCount = 0;
        _activePointers.clear();
        _currentStrokePoints.clear();
        _cursorCanvasPos = null;
        setState(() {});
      },
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _transformController,
          builder: (context, _) {
            final transform = _transformController.value;

            return Transform(
              transform: transform,
              child: Stack(
                children: [
                  // 1. Ghosted Original Background Photo
                  if (_workingImagePath != null)
                    Positioned.fromRect(
                      rect: fittedRect,
                      child: Opacity(
                        opacity: _bgOpacity,
                        child: Image.file(
                          File(_workingImagePath!),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.low,
                        ),
                      ),
                    ),

                  // 2. Active Cutout Overlay (or Vinyl Sticker Preview)
                  if (_previewVinyl && _vinylPreviewBytes != null)
                    Positioned.fromRect(
                      rect: fittedRect,
                      child: Image.memory(
                        _vinylPreviewBytes!,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    )
                  else if (_overlayPath != null)
                    Positioned.fromRect(
                      rect: fittedRect,
                      child: Image.file(
                        File(_overlayPath!),
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),

                  // 3. Live Brush Path Painter
                  if ((_currentStrokePoints.isNotEmpty ||
                          _committingStrokePoints.isNotEmpty) &&
                      !_previewVinyl)
                    Positioned.fromRect(
                      rect: fittedRect,
                      child: CustomPaint(
                        size: Size(fittedRect.width, fittedRect.height),
                        painter: _StrokePathPainter(
                          points: _currentStrokePoints.isNotEmpty
                              ? _currentStrokePoints
                              : _committingStrokePoints,
                          imageW: _imageW,
                          imageH: _imageH,
                          radius: _brushRadius,
                          isRestore: _isRestore,
                        ),
                      ),
                    ),

                  // 4. Live Cursor Indicator
                  if (_cursorCanvasPos != null && !_previewVinyl)
                    CustomPaint(
                      painter: _CursorPainter(
                        canvasPos: MatrixUtils.transformPoint(
                          Matrix4.inverted(transform),
                          _cursorCanvasPos!,
                        ),
                        radius: _brushRadius * (fittedRect.width / _imageW),
                        isRestore: _isRestore,
                        isSmart: _isSmart,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomControls(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.all(MdSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: MdSpacing.md,
        vertical: MdSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(MdSpacing.radiusXl),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Mode Switch (Restore vs Erase) & Snapping Switch (Smart vs Manual)
          Row(
            children: [
              // Restore / Erase Toggle
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!_isRestore) {
                              AppHaptics.selection();
                              setState(() => _isRestore = true);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isRestore
                                  ? scheme.primary
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(MdSpacing.radiusMd),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.brush_rounded,
                                  size: 16,
                                  color: _isRestore
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Restore',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _isRestore
                                        ? scheme.onPrimary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_isRestore) {
                              AppHaptics.selection();
                              setState(() => _isRestore = false);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: !_isRestore
                                  ? scheme.error
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(MdSpacing.radiusMd),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_fix_normal_rounded,
                                  size: 16,
                                  color: !_isRestore
                                      ? scheme.onError
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Erase',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: !_isRestore
                                        ? scheme.onError
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: MdSpacing.sm),

              // Smart Edge vs Manual Toggle
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    _buildChipToggle(
                      label: 'Smart Edge',
                      icon: Icons.auto_awesome_rounded,
                      active: _isSmart,
                      activeColor: scheme.secondary,
                      onTap: () {
                        if (!_isSmart) {
                          AppHaptics.selection();
                          setState(() => _isSmart = true);
                        }
                      },
                    ),
                    _buildChipToggle(
                      label: 'Manual',
                      icon: Icons.tune_rounded,
                      active: !_isSmart,
                      activeColor: scheme.secondary,
                      onTap: () {
                        if (_isSmart) {
                          AppHaptics.selection();
                          setState(() => _isSmart = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: MdSpacing.xs),

          // Row 2: Brush Size Slider & Background Opacity Toggle
          Row(
            children: [
              Icon(
                Icons.circle,
                size: math.max(6, _brushRadius * 0.4),
                color: _isRestore ? scheme.primary : scheme.error,
              ),
              const SizedBox(width: MdSpacing.xs),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: _brushRadius,
                    min: 8.0,
                    max: 75.0,
                    onChanged: (val) {
                      setState(() => _brushRadius = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: MdSpacing.xs),

              // Background Opacity Quick Cycle (0.15 -> 0.35 -> 0.70)
              InkWell(
                borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                onTap: () {
                  AppHaptics.selection();
                  setState(() {
                    if (_bgOpacity <= 0.20) {
                      _bgOpacity = 0.40;
                    } else if (_bgOpacity <= 0.45) {
                      _bgOpacity = 0.75;
                    } else {
                      _bgOpacity = 0.15;
                    }
                  });
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.layers_rounded,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        '${(_bgOpacity * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipToggle({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? scheme.onSecondary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? scheme.onSecondary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrokePathPainter extends CustomPainter {
  _StrokePathPainter({
    required this.points,
    required this.imageW,
    required this.imageH,
    required this.radius,
    required this.isRestore,
  });

  final List<Offset> points;
  final int imageW;
  final int imageH;
  final double radius;
  final bool isRestore;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || imageW <= 0 || imageH <= 0) return;

    final scaleX = size.width / imageW;
    final scaleY = size.height / imageH;
    final strokeW = radius * 2 * ((scaleX + scaleY) / 2);

    final paint = Paint()
      ..color = isRestore
          ? const Color(0x774CAF50) // Translucent green for restore
          : const Color(0x77F44336) // Translucent red for erase
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      final p = Offset(points[0].dx * scaleX, points[0].dy * scaleY);
      canvas.drawCircle(
        p,
        strokeW / 2,
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(points[0].dx * scaleX, points[0].dy * scaleY);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * scaleX, points[i].dy * scaleY);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePathPainter oldDelegate) => true;
}

class _CursorPainter extends CustomPainter {
  _CursorPainter({
    required this.canvasPos,
    required this.radius,
    required this.isRestore,
    required this.isSmart,
  });

  final Offset canvasPos;
  final double radius;
  final bool isRestore;
  final bool isSmart;

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = isRestore ? const Color(0xFF4CAF50) : const Color(0xFFF44336)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(canvasPos, radius, ringPaint);

    if (isSmart) {
      // Small center dot for smart snapping focus
      final dotPaint = Paint()
        ..color = ringPaint.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(canvasPos, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CursorPainter oldDelegate) => true;
}
