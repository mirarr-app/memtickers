import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../data/sticker.dart';
import '../data/sticker_repository.dart';
import '../tags/tag_selection_sheet.dart';
import '../theme/app_haptics.dart';
import '../theme/spacing.dart';
import 'auto_tag_service.dart';
import 'dithered_image_view.dart';
import 'memory_metadata.dart';
import 'metadata_service.dart';
import 'segmentation_service.dart';
import 'stamp_overlay.dart';
import 'sticker_processor.dart';

class CaptureResult {
  const CaptureResult({required this.sticker, required this.pngBytes});

  final Sticker sticker;
  final Uint8List pngBytes;
}

class CapturePage extends StatefulWidget {
  const CapturePage({
    super.key,
    required this.repository,
    required this.dropX,
    required this.dropY,
    this.openGalleryImmediately = false,
  });

  final StickerRepository repository;
  final double dropX;
  final double dropY;
  final bool openGalleryImmediately;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final _picker = ImagePicker();
  final _segmenter = SegmentationService();
  final _processor = StickerProcessor();
  final _metadata = MetadataService();

  CameraController? _camera;
  bool _cameraReady = false;
  bool _takingPicture = false;
  bool _busy = false;
  bool _modelReady = false;
  bool _modelFailed = false;
  String? _status;
  MemoryMetadata? _pendingMeta;
  Uint8List? _previewPng;
  final Set<String> _selectedTags = <String>{};
  bool _hasGps = false;
  bool _isFromGallery = false;
  int _processGeneration = 0;
  ui.Image? _sourceUiImage;
  Uint8List? _sourceImageBytes;

  // Stamp Controls
  final TextEditingController _stampController = TextEditingController();
  String _stampText = '';
  Color _stampColor = StampPainter.inkColors.first;
  StampPosition _stampPosition = StampPosition.bottomRight;
  Offset? _stampCustomOffset;
  int _stickerPixelWidth = 0;
  int _stickerPixelHeight = 0;
  Rect? _lastStickerRenderedRect;
  Offset? _lastStampCenterInPreview;
  Size? _lastStampSizeInPreview;

  // Flash and Zoom Controls
  FlashMode _flashMode = FlashMode.off;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    unawaited(_prepareModel());
    await _prepareCamera();
    if (!mounted) return;
    if (widget.openGalleryImmediately) {
      await _pickGallery();
    }
  }

  Future<void> _prepareModel() async {
    unawaited(AutoTagService.ensureModel());
    try {
      await _segmenter.ensureModel(onStatus: _onCutoutStatus);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _modelFailed = true;
        _status = error is SegmentationException
            ? error.message
            : 'Could not load the on-device cutout model.';
      });
    }
  }

  void _onCutoutStatus(CutoutStatus status) {
    if (!mounted) return;
    setState(() {
      _modelReady = status.ready;
      _modelFailed = status.failed;
      if (status.ready) {
        _status = _busy ? 'Cutting the subject out…' : null;
      } else {
        _status = status.message;
      }
    });
  }

  Future<void> _prepareCamera() async {
    final cam = await Permission.camera.request();
    if (!cam.isGranted) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      double minZoom = 1.0;
      double maxZoom = 1.0;
      try {
        minZoom = await controller.getMinZoomLevel();
        maxZoom = await controller.getMaxZoomLevel();
        if (maxZoom < minZoom) maxZoom = minZoom;
      } catch (_) {}

      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {
        _flashMode = FlashMode.off;
      }

      setState(() {
        _camera = controller;
        _cameraReady = true;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _currentZoom = minZoom.clamp(1.0, maxZoom);
        _baseZoom = _currentZoom;
      });
      unawaited(_refreshGpsChip());
    } catch (_) {
      // Camera is optional; gallery still works.
    }
  }

  Future<void> _refreshGpsChip() async {
    try {
      final service = await Permission.locationWhenInUse.serviceStatus;
      final status = await Permission.locationWhenInUse.status;
      if (!mounted) return;
      setState(
        () => _hasGps = service == ServiceStatus.enabled && status.isGranted,
      );
    } catch (_) {}
  }

  Future<void> _ensureLocationOptional() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    setState(() => _hasGps = status.isGranted);
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    M3EHapticFeedback.light.apply();
    final targetMode = _flashMode == FlashMode.off
        ? FlashMode.always
        : FlashMode.off;
    try {
      await camera.setFlashMode(targetMode);
      if (!mounted) return;
      setState(() {
        _flashMode = targetMode;
      });
    } catch (_) {
      try {
        final fallback = _flashMode == FlashMode.off
            ? FlashMode.torch
            : FlashMode.off;
        await camera.setFlashMode(fallback);
        if (!mounted) return;
        setState(() {
          _flashMode = fallback;
        });
      } catch (_) {
        if (!mounted) return;
        _snack('Flash is not supported on this camera.');
      }
    }
  }

  Future<void> _setZoom(double zoom) async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    if ((clamped - _currentZoom).abs() < 0.005) return;
    setState(() {
      _currentZoom = clamped;
    });
    try {
      await camera.setZoomLevel(clamped);
    } catch (_) {}
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_minZoom >= _maxZoom) return;
    final targetZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if ((targetZoom - _currentZoom).abs() >= 0.01) {
      setState(() {
        _currentZoom = targetZoom;
      });
      _camera?.setZoomLevel(targetZoom);
    }
  }

  Future<void> _shutter() async {
    final camera = _camera;
    if (camera == null ||
        !camera.value.isInitialized ||
        _busy ||
        _takingPicture) {
      return;
    }
    AppHaptics.mediumImpact();
    setState(() => _takingPicture = true);
    await _ensureLocationOptional();
    try {
      final shot = await camera.takePicture();
      final meta = await _metadata.fromLiveCapture();
      await _processFile(File(shot.path), meta, isFromGallery: false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _takingPicture = false);
      _snack(error.toString());
    }
  }

  Future<void> _pickGallery() async {
    if (_busy || _takingPicture) return;
    final photos = await Permission.photos.request();
    if (!photos.isGranted && !photos.isLimited) {
      final storage = await Permission.storage.request();
      if (!storage.isGranted) {
        if (mounted) _snack('Photo access is needed to import a memory.');
        return;
      }
    }
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final meta = await _metadata.fromGalleryFile(file.path);
    await _processFile(File(file.path), meta, isFromGallery: true);
  }

  Future<void> _processFile(
    File file,
    MemoryMetadata meta, {
    required bool isFromGallery,
  }) async {
    final gen = ++_processGeneration;
    try {
      await _camera?.pausePreview();
    } catch (_) {}

    ui.Image? sourceUiImage;
    Uint8List? rawBytes;
    try {
      rawBytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      sourceUiImage = frame.image;
    } catch (_) {}

    if (!mounted || _processGeneration != gen) {
      sourceUiImage?.dispose();
      return;
    }

    _sourceUiImage?.dispose();
    setState(() {
      _busy = true;
      _takingPicture = false;
      _sourceUiImage = sourceUiImage;
      _sourceImageBytes = rawBytes;
      _status = null;
      _previewPng = null;
      _selectedTags.clear();
      _isFromGallery = isFromGallery;
    });

    try {
      final cutout = await _segmenter.cutOut(
        file,
        onStatus: (status) {
          if (_processGeneration == gen) _onCutoutStatus(status);
        },
      );
      if (!mounted || _processGeneration != gen) return;

      final dieCut = await _processor.dieCut(cutout);
      if (!mounted || _processGeneration != gen) return;

      final settings = widget.repository.settings;
      final finalPng = await _processor.applyColorAdjustments(
        dieCut,
        saturation: settings.saturation,
        brightness: settings.brightness,
      );
      if (!mounted || _processGeneration != gen) return;

      int pixelW = 0;
      int pixelH = 0;
      try {
        final codec = await ui.instantiateImageCodec(finalPng);
        final frame = await codec.getNextFrame();
        pixelW = frame.image.width;
        pixelH = frame.image.height;
        frame.image.dispose();
      } catch (_) {}

      setState(() {
        _previewPng = finalPng;
        _stickerPixelWidth = pixelW;
        _stickerPixelHeight = pixelH;
        _stampController.clear();
        _stampText = '';
        _stampCustomOffset = null;
        _stampPosition = StampPosition.bottomRight;
        _pendingMeta = meta;
        _busy = false;
        _status = null;
        _modelReady = true;
        _sourceUiImage?.dispose();
        _sourceUiImage = null;
      });
    } on SegmentationException catch (error) {
      if (!mounted || _processGeneration != gen) return;
      try {
        await _camera?.resumePreview();
      } catch (_) {}
      _sourceUiImage?.dispose();
      setState(() {
        _sourceUiImage = null;
        _sourceImageBytes = null;
        _busy = false;
        _status = null;
      });
      _snack(error.message);
    } catch (error) {
      if (!mounted || _processGeneration != gen) return;
      try {
        await _camera?.resumePreview();
      } catch (_) {}
      _sourceUiImage?.dispose();
      setState(() {
        _sourceUiImage = null;
        _sourceImageBytes = null;
        _busy = false;
        _status = null;
      });
      _snack(_friendlyError(error));
    }
  }

  void _cancelCutout() {
    _processGeneration++;
    try {
      _camera?.resumePreview();
    } catch (_) {}
    _sourceUiImage?.dispose();
    _stampController.clear();
    setState(() {
      _busy = false;
      _takingPicture = false;
      _status = null;
      _previewPng = null;
      _pendingMeta = null;
      _selectedTags.clear();
      _sourceUiImage = null;
      _sourceImageBytes = null;
      _stampText = '';
      _stampCustomOffset = null;
      _stampPosition = StampPosition.bottomRight;
    });
  }

  String _friendlyError(Object error) {
    return 'Could not cut out this photo. Try another one.';
  }

  Future<void> _openTagSelection() async {
    AppHaptics.lightImpact();
    final updated = await showTagSelectionSheet(
      context: context,
      repository: widget.repository,
      initialSelectedTags: _selectedTags,
    );
    if (updated != null && mounted) {
      setState(() {
        _selectedTags
          ..clear()
          ..addAll(updated);
      });
    }
  }

  Future<void> _keep() async {
    final png = _previewPng;
    final meta = _pendingMeta;
    if (png == null || meta == null) return;
    AppHaptics.success();

    var finalBytes = png;
    if (_stampText.trim().isNotEmpty &&
        _lastStickerRenderedRect != null &&
        _lastStampCenterInPreview != null &&
        _lastStampSizeInPreview != null) {
      final stampConfig = StampConfig(
        text: _stampText,
        color: _stampColor,
        date: meta.capturedAt,
        position: _stampPosition,
        customOffset: _stampCustomOffset,
      );
      try {
        finalBytes = await compositeStampOnImage(
          sourcePngBytes: png,
          config: stampConfig,
          stickerRenderedRect: _lastStickerRenderedRect!,
          stampCenterInPreview: _lastStampCenterInPreview!,
          stampSizeInPreview: _lastStampSizeInPreview!,
        );
      } catch (_) {
        finalBytes = png;
      }
    }

    final id = const Uuid().v4();
    final path = widget.repository.imagePathFor(id);
    await _processor.writePng(finalBytes, path);
    final jitter = (math.Random().nextDouble() - 0.5) * 0.18;
    final sticker = Sticker(
      id: id,
      boardId: widget.repository.activeBoardId,
      imagePath: path,
      createdAt: meta.capturedAt,
      latitude: meta.latitude,
      longitude: meta.longitude,
      placeLabel: meta.placeLabel,
      tags: _selectedTags.toList(),
      modelTags: const [],
      x: widget.dropX,
      y: widget.dropY,
      rotation: jitter,
      scale: 1,
      zIndex: widget.repository.nextZIndex(),
    );
    await widget.repository.save(sticker);
    // Asynchronously generate AI model tags in the background now that the sticker is placed & saved
    unawaited(widget.repository.generateModelTags(id));
    if (!mounted) return;
    Navigator.of(context).pop(CaptureResult(sticker: sticker, pngBytes: finalBytes));
  }

  Future<void> _retake() async {
    final wasFromGallery = _isFromGallery;
    try {
      await _camera?.resumePreview();
    } catch (_) {}
    _stampController.clear();
    setState(() {
      _previewPng = null;
      _pendingMeta = null;
      _selectedTags.clear();
      _sourceImageBytes = null;
      _stampText = '';
      _stampCustomOffset = null;
      _stampPosition = StampPosition.bottomRight;
    });
    if (wasFromGallery) {
      await _pickGallery();
    }
  }

  void _cycleStampPosition() {
    AppHaptics.selection();
    setState(() {
      _stampCustomOffset = null;
      switch (_stampPosition) {
        case StampPosition.bottomRight:
          _stampPosition = StampPosition.bottomLeft;
          break;
        case StampPosition.bottomLeft:
          _stampPosition = StampPosition.topLeft;
          break;
        case StampPosition.topLeft:
          _stampPosition = StampPosition.topRight;
          break;
        case StampPosition.topRight:
        case StampPosition.custom:
          _stampPosition = StampPosition.bottomRight;
          break;
      }
    });
  }

  IconData _positionIcon(StampPosition pos) {
    switch (pos) {
      case StampPosition.bottomRight:
        return Icons.south_east_rounded;
      case StampPosition.bottomLeft:
        return Icons.south_west_rounded;
      case StampPosition.topRight:
        return Icons.north_east_rounded;
      case StampPosition.topLeft:
        return Icons.north_west_rounded;
      case StampPosition.custom:
        return Icons.open_with_rounded;
    }
  }

  String _positionLabel(StampPosition pos) {
    switch (pos) {
      case StampPosition.bottomRight:
        return 'Bottom-Right';
      case StampPosition.bottomLeft:
        return 'Bottom-Left';
      case StampPosition.topRight:
        return 'Top-Right';
      case StampPosition.topLeft:
        return 'Top-Left';
      case StampPosition.custom:
        return 'Custom';
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _stampController.dispose();
    _sourceUiImage?.dispose();
    _sourceUiImage = null;
    _camera?.dispose();
    unawaited(_segmenter.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final preview = _previewPng;
    final isFlashOn = _flashMode != FlashMode.off;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(preview != null ? 'Memory Preview' : (_busy ? 'Creating Sticker' : 'Capture Memory')),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (preview == null && !_busy) ...[
            if (_cameraReady && _camera != null)
              IconButton(
                tooltip: isFlashOn ? 'Flash on' : 'Flash off',
                icon: Icon(
                  isFlashOn
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  color: isFlashOn ? scheme.primary : scheme.onSurfaceVariant,
                ),
                onPressed: _toggleFlash,
              ),
            IconButton(
              tooltip: _hasGps ? 'GPS on' : 'GPS off',
              icon: Icon(
                _hasGps
                    ? Icons.location_on_rounded
                    : Icons.location_off_rounded,
                color: _hasGps ? scheme.primary : scheme.onSurfaceVariant,
              ),
              onPressed: () {
                M3EHapticFeedback.light.apply();
                _ensureLocationOptional();
              },
            ),
            const SizedBox(width: MdSpacing.xs),
          ],
        ],
      ),
      body: SafeArea(
        child: _busy
            ? Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MdSpacing.sm,
                        vertical: MdSpacing.xs,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            MdSpacing.radiusXlIncreased,
                          ),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            if (_sourceUiImage != null)
                              Positioned.fill(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      MdSpacing.md,
                                    ),
                                    child: DitheredImageView(
                                      image: _sourceUiImage!,
                                      opacity: 0.5,
                                    ),
                                  ),
                                ),
                              )
                            else if (_sourceImageBytes != null)
                              Positioned.fill(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      MdSpacing.md,
                                    ),
                                    child: Opacity(
                                      opacity: 0.5,
                                      child: Image.memory(
                                        _sourceImageBytes!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(MdSpacing.md),
                                decoration: BoxDecoration(
                                  color: scheme.surface.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const M3ELoadingIndicator(
                                  semanticsLabel: 'Cutting out subject',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MdSpacing.sm,
                      MdSpacing.xs,
                      MdSpacing.sm,
                      MdSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: M3ETextButton(
                            size: M3EButtonSize.sm,
                            onPressed: _cancelCutout,
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MdSpacing.sm,
                        vertical: MdSpacing.xs,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            MdSpacing.radiusXlIncreased,
                          ),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: preview != null
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  final availW = math.max(
                                    1.0,
                                    constraints.maxWidth - MdSpacing.md * 2,
                                  );
                                  final availH = math.max(
                                    1.0,
                                    constraints.maxHeight - MdSpacing.md * 2,
                                  );
                                  final imgW = _stickerPixelWidth > 0
                                      ? _stickerPixelWidth.toDouble()
                                      : availW;
                                  final imgH = _stickerPixelHeight > 0
                                      ? _stickerPixelHeight.toDouble()
                                      : availH;
                                  final imgAspect = imgW / imgH;
                                  final boxAspect = availW / availH;

                                  double renderedW;
                                  double renderedH;
                                  if (boxAspect > imgAspect) {
                                    renderedH = availH;
                                    renderedW = availH * imgAspect;
                                  } else {
                                    renderedW = availW;
                                    renderedH = availW / imgAspect;
                                  }

                                  final stickerLeft =
                                      (constraints.maxWidth - renderedW) / 2;
                                  final stickerTop =
                                      (constraints.maxHeight - renderedH) / 2;
                                  final stickerRect = Rect.fromLTWH(
                                    stickerLeft,
                                    stickerTop,
                                    renderedW,
                                    renderedH,
                                  );
                                  _lastStickerRenderedRect = stickerRect;

                                  Widget? stampWidget;
                                  if (_stampText.trim().isNotEmpty) {
                                    final stampConfig = StampConfig(
                                      text: _stampText,
                                      color: _stampColor,
                                      date: _pendingMeta?.capturedAt,
                                      position: _stampPosition,
                                      customOffset: _stampCustomOffset,
                                    );
                                    final stampSize =
                                        StampPainter.computeStampSize(
                                      _stampText,
                                      date: _pendingMeta?.capturedAt,
                                    );
                                    _lastStampSizeInPreview = stampSize;

                                    Offset stampCenter;
                                    if (_stampPosition == StampPosition.custom &&
                                        _stampCustomOffset != null) {
                                      stampCenter = _stampCustomOffset!;
                                    } else {
                                      switch (_stampPosition) {
                                        case StampPosition.bottomRight:
                                          stampCenter = Offset(
                                            stickerRect.right -
                                                stampSize.width * 0.42,
                                            stickerRect.bottom -
                                                stampSize.height * 0.38,
                                          );
                                          break;
                                        case StampPosition.bottomLeft:
                                          stampCenter = Offset(
                                            stickerRect.left +
                                                stampSize.width * 0.42,
                                            stickerRect.bottom -
                                                stampSize.height * 0.38,
                                          );
                                          break;
                                        case StampPosition.topRight:
                                          stampCenter = Offset(
                                            stickerRect.right -
                                                stampSize.width * 0.42,
                                            stickerRect.top +
                                                stampSize.height * 0.38,
                                          );
                                          break;
                                        case StampPosition.topLeft:
                                          stampCenter = Offset(
                                            stickerRect.left +
                                                stampSize.width * 0.42,
                                            stickerRect.top +
                                                stampSize.height * 0.38,
                                          );
                                          break;
                                        case StampPosition.custom:
                                          stampCenter = _stampCustomOffset ??
                                              Offset(
                                                stickerRect.right -
                                                    stampSize.width * 0.42,
                                                stickerRect.bottom -
                                                    stampSize.height * 0.38,
                                              );
                                          break;
                                      }
                                    }
                                    _lastStampCenterInPreview = stampCenter;

                                    stampWidget = Positioned(
                                      left: stampCenter.dx - stampSize.width / 2,
                                      top: stampCenter.dy - stampSize.height / 2,
                                      child: StampWidget(
                                        config: stampConfig,
                                        onDragUpdate: (delta) {
                                          setState(() {
                                            final cur = _stampCustomOffset ??
                                                stampCenter;
                                            _stampPosition =
                                                StampPosition.custom;
                                            _stampCustomOffset = cur + delta;
                                          });
                                        },
                                      ),
                                    );
                                  }

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(
                                              MdSpacing.md,
                                            ),
                                            child: Image.memory(
                                              preview,
                                              fit: BoxFit.contain,
                                              filterQuality:
                                                  FilterQuality.high,
                                            ),
                                          ),
                                        ),
                                      ),
                                      ?stampWidget,
                                      if (_pendingMeta?.placeLabel != null)
                                        Positioned(
                                          bottom: MdSpacing.sm,
                                          left: MdSpacing.sm,
                                          right: MdSpacing.sm,
                                          child: Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: MdSpacing.sm,
                                                vertical: MdSpacing.xxs,
                                              ),
                                              decoration: BoxDecoration(
                                                color: scheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  MdSpacing.radiusFull,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.place_rounded,
                                                    size: 16,
                                                    color: scheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      _pendingMeta!.placeLabel!,
                                                      style: textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              )
                            : _cameraReady && _camera != null
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onScaleStart: _onScaleStart,
                                onScaleUpdate: _onScaleUpdate,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CameraPreview(_camera!),
                                    // Subtle framing corners
                                    IgnorePointer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            MdSpacing.radiusXlIncreased,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Pinch zoom indicator & quick toggle chip
                                    if (_maxZoom > _minZoom)
                                      Positioned(
                                        bottom: MdSpacing.sm,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: GestureDetector(
                                            onTap: () {
                                              AppHaptics.selection();
                                              if (_currentZoom > 1.05) {
                                                _setZoom(_minZoom);
                                              } else if (_maxZoom >= 2.0) {
                                                _setZoom(2.0);
                                              } else {
                                                _setZoom(_maxZoom);
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: MdSpacing.sm,
                                                    vertical: MdSpacing.xxs,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.6,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      MdSpacing.radiusFull,
                                                    ),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.zoom_in_rounded,
                                                    size: 14,
                                                    color: Colors.white70,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${_currentZoom.toStringAsFixed(1)}×',
                                                    style: textTheme.labelSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.white,
                                                          letterSpacing: 0.5,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(MdSpacing.md),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.no_photography_outlined,
                                        size: 48,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: MdSpacing.xs),
                                      Text(
                                        'Camera unavailable',
                                        style: textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Import an existing memory from your gallery instead.',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (preview != null) ...[
                    // Stamp Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        MdSpacing.sm,
                        0,
                        MdSpacing.sm,
                        MdSpacing.xs,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: MdSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(
                            MdSpacing.radiusLg,
                          ),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _stampColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      MdSpacing.radiusFull,
                                    ),
                                    border: Border.all(
                                      color: _stampColor.withValues(alpha: 0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.approval_rounded,
                                        size: 16,
                                        color: _stampColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Stamp',
                                        style: textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: _stampColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: MdSpacing.xs),
                                Expanded(
                                  child: TextField(
                                    controller: _stampController,
                                    maxLength: 15,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style: textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      fontFamily: 'monospace',
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Type stamp (max 15 chars)…',
                                      hintStyle: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                        fontStyle: FontStyle.italic,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 6,
                                      ),
                                      counterText: '',
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _stampText = val;
                                      });
                                    },
                                  ),
                                ),
                                if (_stampText.isNotEmpty) ...[
                                  Text(
                                    '${_stampText.length}/15',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.65),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 26,
                                      minHeight: 26,
                                    ),
                                    splashRadius: 14,
                                    tooltip: 'Clear stamp',
                                    onPressed: () {
                                      M3EHapticFeedback.light.apply();
                                      _stampController.clear();
                                      setState(() {
                                        _stampText = '';
                                        _stampCustomOffset = null;
                                      });
                                    },
                                  ),
                                ],
                                Tooltip(
                                  message:
                                      'Position: ${_positionLabel(_stampPosition)}',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(
                                      MdSpacing.radiusFull,
                                    ),
                                    onTap: _cycleStampPosition,
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        _positionIcon(_stampPosition),
                                        size: 18,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_stampText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 2,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Ink:',
                                      style: textTheme.labelSmall?.copyWith(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.75),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    for (final color in StampPainter.inkColors)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          AppHaptics.selection();
                                          setState(() {
                                            _stampColor = color;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 4,
                                          ),
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _stampColor == color
                                                    ? (color ==
                                                            const Color(
                                                              0xFFFFFFFF,
                                                            )
                                                        ? scheme.primary
                                                        : scheme.onSurface)
                                                    : (color ==
                                                            const Color(
                                                              0xFFFFFFFF,
                                                            )
                                                        ? scheme.outlineVariant
                                                        : Colors.transparent),
                                                width: _stampColor == color
                                                    ? 2.4
                                                    : 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.15),
                                                  blurRadius: 3,
                                                  offset: const Offset(0, 1),
                                                ),
                                                if (_stampColor == color)
                                                  BoxShadow(
                                                    color: color ==
                                                            const Color(
                                                              0xFFFFFFFF,
                                                            )
                                                        ? scheme.primary
                                                            .withValues(
                                                              alpha: 0.35,
                                                            )
                                                        : color.withValues(
                                                            alpha: 0.45,
                                                          ),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                              ],
                                            ),
                                            child: _stampColor == color
                                                ? Icon(
                                                    Icons.check_rounded,
                                                    size: 15,
                                                    color: color ==
                                                            const Color(
                                                              0xFFFFFFFF,
                                                            )
                                                        ? Colors.black87
                                                        : Colors.white,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    Text(
                                      'Drag to position',
                                      style: textTheme.labelSmall?.copyWith(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // User Custom Tags
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        MdSpacing.sm,
                        0,
                        MdSpacing.sm,
                        MdSpacing.xs,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: MdSpacing.sm,
                          vertical: MdSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(
                            MdSpacing.radiusLg,
                          ),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Expressive Tag Button that triggers search modal
                            M3EFilledButton.tonalIcon(
                              size: M3EButtonSize.sm,
                              onPressed: _openTagSelection,
                              icon: const Icon(Icons.sell_outlined, size: 18),
                              label: Text(
                                _selectedTags.isEmpty
                                    ? 'Tags'
                                    : 'Tags (${_selectedTags.length})',
                              ),
                            ),
                            const SizedBox(width: MdSpacing.xs),
                            // Scrollable list of currently selected tag chips
                            Expanded(
                              child: _selectedTags.isEmpty
                                  ? InkWell(
                                      onTap: _openTagSelection,
                                      borderRadius: BorderRadius.circular(
                                        MdSpacing.radiusSm,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: MdSpacing.xs,
                                          vertical: 6,
                                        ),
                                        child: Text(
                                          'No tags selected',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant
                                                .withValues(alpha: 0.8),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          for (final tagName
                                              in _selectedTags) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 6,
                                              ),
                                              child: InputChip(
                                                label: Text('#$tagName'),
                                                labelStyle: textTheme.labelSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: scheme
                                                          .onSecondaryContainer,
                                                    ),
                                                backgroundColor: scheme
                                                    .secondaryContainer
                                                    .withValues(alpha: 0.7),
                                                deleteIcon: Icon(
                                                  Icons.close_rounded,
                                                  size: 14,
                                                  color: scheme
                                                      .onSecondaryContainer,
                                                ),
                                                onDeleted: () {
                                                  M3EHapticFeedback.light
                                                      .apply();
                                                  setState(() {
                                                    _selectedTags.remove(
                                                      tagName,
                                                    );
                                                  });
                                                },
                                                onPressed: _openTagSelection,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!_modelReady && _status != null && _modelFailed)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MdSpacing.sm,
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: MdSpacing.xs),
                        padding: const EdgeInsets.all(MdSpacing.xs),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(
                            MdSpacing.radiusSm,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: MdSpacing.xs),
                            Expanded(
                              child: Text(
                                _status!,
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MdSpacing.sm,
                      MdSpacing.xs,
                      MdSpacing.sm,
                      MdSpacing.md,
                    ),
                    child: preview != null
                        ? Row(
                            children: [
                              Expanded(
                                child: M3EFilledButton.tonalIcon(
                                  size: M3EButtonSize.sm,
                                  onPressed: _retake,
                                  icon: const Icon(
                                    Icons.replay_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Retake'),
                                ),
                              ),
                              const SizedBox(width: MdSpacing.xs),
                              Expanded(
                                child: M3EFilledButton.icon(
                                  size: M3EButtonSize.sm,
                                  onPressed: _keep,
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Keep sticker'),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Gallery Button
                              IconButton.filledTonal(
                                tooltip: 'Import from Gallery',
                                style: IconButton.styleFrom(
                                  backgroundColor: scheme.surfaceContainerHigh,
                                  padding: const EdgeInsets.all(MdSpacing.sm),
                                ),
                                onPressed: !_takingPicture
                                    ? _pickGallery
                                    : null,
                                icon: const Icon(
                                  Icons.photo_library_rounded,
                                  size: 24,
                                ),
                              ),

                              // Expressive Hero Shutter Button
                              GestureDetector(
                                onTap: (_cameraReady && !_takingPicture)
                                    ? _shutter
                                    : null,
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: scheme.primary,
                                      width: 3.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (_cameraReady && !_takingPicture)
                                          ? scheme.primary
                                          : scheme.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                    child: Center(
                                      child: _takingPicture
                                          ? SizedBox(
                                              width: 26,
                                              height: 26,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: scheme.onPrimary,
                                              ),
                                            )
                                          : Icon(
                                              Icons.camera_alt_rounded,
                                              size: 30,
                                              color: scheme.onPrimary,
                                            ),
                                    ),
                                  ),
                                ),
                              ),

                              // Spacing balance or Quick info
                              IconButton(
                                tooltip: 'Gallery import',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.all(MdSpacing.sm),
                                ),
                                onPressed: !_takingPicture
                                    ? _pickGallery
                                    : null,
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
