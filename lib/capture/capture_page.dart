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
  bool _busy = false;
  String? _status;
  MemoryMetadata? _pendingMeta;
  Uint8List? _previewPng;
  bool _hasGps = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _prepareCamera();
    if (!mounted) return;
    if (widget.openGalleryImmediately) {
      await _pickGallery();
    }
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
    if (camera == null || !camera.value.isInitialized || _busy) return;
    M3EHapticFeedback.medium.apply();
    await _ensureLocationOptional();
    try {
      final shot = await camera.takePicture();
      final meta = await _metadata.fromLiveCapture();
      await _processFile(File(shot.path), meta);
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString());
    }
  }

  Future<void> _pickGallery() async {
    if (_busy) return;
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
    setState(() {
      _busy = true;
      _status = 'Cutting the subject out…';
      _previewPng = null;
    });
    try {
      final cutout = await _segmenter.cutOut(file);
      final dieCut = await _processor.dieCut(cutout);
      if (!mounted) return;
      setState(() {
        _previewPng = dieCut;
        _pendingMeta = meta;
        _busy = false;
        _status = null;
      });
    } on SegmentationException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
      });
      _snack(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
      });
      final message = error.toString();
      if (message.toLowerCase().contains('play') ||
          message.toLowerCase().contains('module') ||
          message.toLowerCase().contains('download')) {
        _snack(
          'Subject cutout needs Google Play services. The model may still be downloading — try again shortly.',
        );
      } else {
        _snack('Could not cut out this photo. Try another one.');
      }
    }
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
    final scheme = Theme.of(context).colorScheme;
    final preview = _previewPng;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Capture'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: MdSpacing.sm),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MdSpacing.extraLarge),
                  child: ColoredBox(
                    color: scheme.surfaceContainerLow,
                    child: preview != null
                        ? Center(
                            child: Image.memory(
                              preview,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          )
                        : _cameraReady && _camera != null
                        ? CameraPreview(_camera!)
                        : Center(
                            child: Text(
                              'Camera unavailable. Import from gallery instead.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MdSpacing.sm,
                MdSpacing.sm,
                MdSpacing.sm,
                MdSpacing.md,
              ),
              child: _busy
                  ? Column(
                      children: [
                        const M3ELoadingIndicator(
                          semanticsLabel: 'Processing photo',
                        ),
                        const SizedBox(height: MdSpacing.xs),
                        Text(
                          _status ?? 'Working…',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    )
                  : preview != null
                  ? Row(
                      children: [
                        Expanded(
                          child: M3EFilledButton.tonal(
                            size: M3EButtonSize.md,
                            onPressed: _retake,
                            child: const Text('Retake'),
                          ),
                        ),
                        const SizedBox(width: MdSpacing.xs),
                        Expanded(
                          child: M3EFilledButton(
                            size: M3EButtonSize.lg,
                            onPressed: _keep,
                            child: const Text('Keep sticker'),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        ActionChip(
                          avatar: Icon(
                            _hasGps ? Icons.location_on : Icons.location_off,
                            size: 18,
                          ),
                          label: Text(_hasGps ? 'Location on' : 'Location off'),
                          onPressed: _ensureLocationOptional,
                        ),
                        const SizedBox(height: MdSpacing.sm),
                        M3EFilledButton(
                          size: M3EButtonSize.xl,
                          onPressed: _cameraReady ? _shutter : null,
                          semanticLabel: 'Shutter',
                          child: const Icon(Icons.camera_alt),
                        ),
                        const SizedBox(height: MdSpacing.xs),
                        M3EFilledButton.tonal(
                          size: M3EButtonSize.md,
                          onPressed: _pickGallery,
                          child: const Text('Gallery'),
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
