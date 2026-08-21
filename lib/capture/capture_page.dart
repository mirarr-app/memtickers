import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../data/sticker.dart';
import '../data/sticker_repository.dart';
import '../theme/spacing.dart';
import 'memory_metadata.dart';
import 'metadata_service.dart';
import 'segmentation_service.dart';
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
  bool _hasGps = false;
  int _processGeneration = 0;

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
      setState(() {
        _camera = controller;
        _cameraReady = true;
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
      setState(() => _hasGps = service == ServiceStatus.enabled && status.isGranted);
    } catch (_) {}
  }

  Future<void> _ensureLocationOptional() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    setState(() => _hasGps = status.isGranted);
  }

  Future<void> _shutter() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _busy || _takingPicture) return;
    M3EHapticFeedback.medium.apply();
    setState(() => _takingPicture = true);
    await _ensureLocationOptional();
    try {
      final shot = await camera.takePicture();
      final meta = await _metadata.fromLiveCapture();
      await _processFile(File(shot.path), meta);
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
    await _processFile(File(file.path), meta);
  }

  Future<void> _processFile(File file, MemoryMetadata meta) async {
    final gen = ++_processGeneration;
    try {
      await _camera?.pausePreview();
    } catch (_) {}

    setState(() {
      _busy = true;
      _takingPicture = false;
      _status = _modelReady ? 'Cutting the subject out…' : 'Loading cutout model…';
      _previewPng = null;
    });

    try {
      final cutout = await _segmenter.cutOut(file, onStatus: (status) {
        if (_processGeneration == gen) _onCutoutStatus(status);
      });
      if (!mounted || _processGeneration != gen) return;

      setState(() => _status = 'Adding the vinyl backing…');
      final dieCut = await _processor.dieCut(cutout);
      if (!mounted || _processGeneration != gen) return;

      final settings = widget.repository.settings;
      final finalPng = await _processor.applyColorAdjustments(
        dieCut,
        saturation: settings.saturation,
        brightness: settings.brightness,
      );
      if (!mounted || _processGeneration != gen) return;

      setState(() {
        _previewPng = finalPng;
        _pendingMeta = meta;
        _busy = false;
        _status = null;
        _modelReady = true;
      });
    } on SegmentationException catch (error) {
      if (!mounted || _processGeneration != gen) return;
      try {
        await _camera?.resumePreview();
      } catch (_) {}
      setState(() {
        _busy = false;
        _status = null;
      });
      _snack(error.message);
    } catch (error) {
      if (!mounted || _processGeneration != gen) return;
      try {
        await _camera?.resumePreview();
      } catch (_) {}
      setState(() {
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
    setState(() {
      _busy = false;
      _takingPicture = false;
      _status = null;
      _previewPng = null;
      _pendingMeta = null;
    });
  }

  String _friendlyError(Object error) {
    return 'Could not cut out this photo. Try another one.';
  }

  Future<void> _keep() async {
    final png = _previewPng;
    final meta = _pendingMeta;
    if (png == null || meta == null) return;
    M3EHapticFeedback.medium.apply();
    final id = const Uuid().v4();
    final path = widget.repository.imagePathFor(id);
    await _processor.writePng(png, path);
    final jitter = (math.Random().nextDouble() - 0.5) * 0.18;
    final sticker = Sticker(
      id: id,
      imagePath: path,
      createdAt: meta.capturedAt,
      latitude: meta.latitude,
      longitude: meta.longitude,
      placeLabel: meta.placeLabel,
      x: widget.dropX,
      y: widget.dropY,
      rotation: jitter,
      scale: 1,
      zIndex: widget.repository.nextZIndex(),
    );
    await widget.repository.save(sticker);
    if (!mounted) return;
    Navigator.of(context).pop(CaptureResult(sticker: sticker, pngBytes: png));
  }

  void _retake() {
    try {
      _camera?.resumePreview();
    } catch (_) {}
    setState(() {
      _previewPng = null;
      _pendingMeta = null;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
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

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(preview != null ? 'Memory Preview' : 'Capture Memory'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (preview == null)
            Padding(
              padding: const EdgeInsets.only(right: MdSpacing.xs),
              child: ActionChip(
                avatar: Icon(
                  _hasGps ? Icons.location_on_rounded : Icons.location_off_rounded,
                  size: 16,
                  color: _hasGps ? scheme.primary : scheme.onSurfaceVariant,
                ),
                label: Text(_hasGps ? 'GPS on' : 'GPS off'),
                onPressed: () {
                  M3EHapticFeedback.light.apply();
                  _ensureLocationOptional();
                },
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _busy
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MdSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const M3ELoadingIndicator(semanticsLabel: 'Cutting out subject'),
                      const SizedBox(height: MdSpacing.lg),
                      Text(
                        _status ?? 'Cutting the subject out…',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MdSpacing.xs),
                      Text(
                        'Isolating subject and creating vinyl border…',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MdSpacing.lg),
                      M3ETextButton(
                        size: M3EButtonSize.sm,
                        onPressed: _cancelCutout,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
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
                            ? Stack(
                                children: [
                                  Positioned.fill(
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(MdSpacing.md),
                                        child: Image.memory(
                                          preview,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_pendingMeta?.placeLabel != null)
                                    Positioned(
                                      bottom: MdSpacing.sm,
                                      left: MdSpacing.sm,
                                      right: MdSpacing.sm,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: MdSpacing.sm,
                                            vertical: MdSpacing.xxs,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.surfaceContainerHighest
                                                .withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(
                                              MdSpacing.radiusFull,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
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
                                                  style: textTheme.labelSmall?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : _cameraReady && _camera != null
                            ? Stack(
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
                                          color: Colors.white.withValues(alpha: 0.15),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
                  if (!_modelReady && _status != null && _modelFailed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: MdSpacing.sm),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: MdSpacing.xs),
                        padding: const EdgeInsets.all(MdSpacing.xs),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
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
                                  icon: const Icon(Icons.replay_rounded, size: 18),
                                  label: const Text('Retake'),
                                ),
                              ),
                              const SizedBox(width: MdSpacing.xs),
                              Expanded(
                                child: M3EFilledButton.icon(
                                  size: M3EButtonSize.sm,
                                  onPressed: _keep,
                                  icon: const Icon(Icons.check_rounded, size: 18),
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
                                onPressed: !_takingPicture ? _pickGallery : null,
                                icon: const Icon(
                                  Icons.photo_library_rounded,
                                  size: 24,
                                ),
                              ),

                              // Expressive Hero Shutter Button
                              GestureDetector(
                                onTap: (_cameraReady && !_takingPicture) ? _shutter : null,
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
                                          : scheme.primary.withValues(alpha: 0.3),
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
                                onPressed: !_takingPicture ? _pickGallery : null,
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
