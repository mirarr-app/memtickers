import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/sticker_repository.dart';
import '../theme/app_haptics.dart';
import '../theme/spacing.dart';
import 'share_canvas_settings.dart';
import 'share_light_source.dart';
import 'share_sticker_item.dart';
import 'share_sticker_picker_sheet.dart';
import 'sticker_reflection_view.dart';

/// The best-in-class Share Studio screen.
///
/// Allows users to compose stickers from their boards on a stage, adjust lighting
/// with an invisible light source that generates real-time specular reflections,
/// and share high-resolution snapshots.
class ShareStudioPage extends StatefulWidget {
  const ShareStudioPage({
    super.key,
    required this.repository,
    this.initialBoardId,
  });

  final StickerRepository repository;
  final String? initialBoardId;

  @override
  State<ShareStudioPage> createState() => _ShareStudioPageState();
}

class _ShareStudioPageState extends State<ShareStudioPage> {
  final GlobalKey _canvasRepaintKey = GlobalKey();
  final List<ShareStickerItem> _items = [];
  String? _selectedItemId;

  late ShareLightSource _lightSource;
  ShareCanvasSettings _settings = const ShareCanvasSettings();

  bool _isLightMode = false;
  bool _isCapturing = false;
  int _nextZIndex = 1;

  @override
  void initState() {
    super.initState();
    // Default initial light position (disabled by default so stickers appear flat)
    _lightSource = const ShareLightSource(
      position: Offset(120, 140),
      intensity: 0.85,
      height: 150.0,
      tone: ShareLightTone.studioWhite,
      isReticleVisible: false,
      isEnabled: false,
    );

    // Populate initial stickers from active or requested board
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialStickers();
    });
  }

  Size _getCanvasSize() {
    final renderBox =
        _canvasRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize && renderBox.size.width > 0) {
      return renderBox.size;
    }
    final screen = MediaQuery.sizeOf(context);
    final ratio = _settings.aspectRatio.ratio;
    final availH = math.max(200.0, screen.height - 180);
    final availW = math.max(200.0, screen.width - 32);
    if (ratio != null) {
      if (availW / availH > ratio) {
        return Size(availH * ratio, availH);
      } else {
        return Size(availW, availW / ratio);
      }
    }
    return Size(availW, availH);
  }

  void _loadInitialStickers() {
    final boardId = widget.initialBoardId ?? widget.repository.activeBoardId;
    final boardStickers = widget.repository.getStickersForBoard(boardId);

    if (boardStickers.isNotEmpty) {
      final size = _getCanvasSize();
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final maxRadius = math.min(size.width, size.height) * 0.18;
      final baseSize = math.min(110.0, size.width * 0.32);
      final minX = (baseSize / 2) + 24.0;
      final maxX = size.width - (baseSize / 2) - 24.0;
      final minY = (baseSize / 2) + 24.0;
      final maxY = size.height - (baseSize / 2) - 24.0;

      // Position default stickers in a tasteful arrangement
      final maxStickers = math.min(boardStickers.length, 6);
      for (int i = 0; i < maxStickers; i++) {
        final sticker = boardStickers[i];
        final angle = (i / maxStickers) * 2 * math.pi;
        final radius = maxStickers > 1 ? maxRadius : 0.0;
        final rawX = centerX + math.cos(angle) * radius;
        final rawY = centerY + math.sin(angle) * radius;

        _items.add(
          ShareStickerItem(
            id: '${sticker.id}_$i',
            sticker: sticker,
            position: Offset(
              rawX.clamp(minX, maxX),
              rawY.clamp(minY, maxY),
            ),
            baseSize: baseSize,
            scale: 1.0,
            rotation: (i % 2 == 0 ? 0.08 : -0.06) * (i + 1),
            zIndex: _nextZIndex++,
          ),
        );
      }
      _lightSource = _lightSource.copyWith(
        position: Offset(centerX * 0.7, centerY * 0.5),
      );
      setState(() {});
    }
  }

  void _selectItem(String? id) {
    setState(() {
      _selectedItemId = id;
      if (id != null) {
        // Bring selected item visually to front
        final item = _items.firstWhere((it) => it.id == id);
        item.zIndex = _nextZIndex++;
        _items.sort((a, b) => a.zIndex.compareTo(b.zIndex));
      }
    });
  }

  Future<void> _openStickerPicker() async {
    AppHaptics.lightImpact();
    final currentIds = _items.map((it) => it.sticker.id).toSet();
    final picked = await showShareStickerPicker(
      context: context,
      repository: widget.repository,
      currentlySelectedIds: currentIds,
    );

    if (picked == null || !mounted) return;

    setState(() {
      // Clear existing and add selected
      _items.clear();
      final size = _getCanvasSize();
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final maxRadius = math.min(size.width, size.height) * 0.18;
      final baseSize = math.min(110.0, size.width * 0.32);
      final minX = (baseSize / 2) + 24.0;
      final maxX = size.width - (baseSize / 2) - 24.0;
      final minY = (baseSize / 2) + 24.0;
      final maxY = size.height - (baseSize / 2) - 24.0;

      for (int i = 0; i < picked.length; i++) {
        final s = picked[i];
        final angle = (i / math.max(picked.length, 1)) * 2 * math.pi;
        final radius = picked.length > 1 ? maxRadius : 0.0;
        final rawX = centerX + math.cos(angle) * radius;
        final rawY = centerY + math.sin(angle) * radius;
        _items.add(
          ShareStickerItem(
            id: '${s.id}_$i',
            sticker: s,
            position: Offset(
              rawX.clamp(minX, maxX),
              rawY.clamp(minY, maxY),
            ),
            baseSize: baseSize,
            scale: 1.0,
            rotation: (i % 2 == 0 ? 0.06 : -0.06) * (i + 1),
            zIndex: _nextZIndex++,
          ),
        );
      }
      _selectedItemId = null;
    });
  }

  // --- Auto-Layout Presets ---

  void _applyArtisticScatter() {
    AppHaptics.mediumImpact();
    final size = _getCanvasSize();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final random = math.Random(42);
    final maxRadius = math.min(size.width, size.height) * 0.25;

    setState(() {
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        final angle = (i / math.max(_items.length, 1)) * 2 * math.pi;
        final radius = maxRadius * (0.5 + random.nextDouble() * 0.5);
        item.position = Offset(
          centerX + math.cos(angle) * radius,
          centerY + math.sin(angle) * radius,
        );
        item.rotation = (random.nextDouble() - 0.5) * 0.45;
        item.scale = math.min(1.0, size.width / 320.0).clamp(0.65, 1.0);
      }
    });
  }

  void _applyCleanGrid() {
    AppHaptics.mediumImpact();
    if (_items.isEmpty) return;
    final size = _getCanvasSize();
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final cols = math.max(1, math.min(3, math.sqrt(_items.length).ceil()));
    final rows = (_items.length / cols).ceil();
    final spacingX = math.min(130.0, size.width / (cols + 0.5));
    final spacingY = math.min(130.0, size.height / (rows + 0.5));
    final startX = centerX - ((cols - 1) * spacingX / 2);
    final startY = centerY - ((rows - 1) * spacingY / 2);

    setState(() {
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        final c = i % cols;
        final r = i ~/ cols;
        item.position = Offset(startX + c * spacingX, startY + r * spacingY);
        item.rotation = 0.0;
        item.scale = math.min(0.85, size.width / 340.0).clamp(0.6, 0.85);
      }
    });
  }

  void _applyCircularCrown() {
    AppHaptics.mediumImpact();
    if (_items.isEmpty) return;
    final size = _getCanvasSize();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(size.width, size.height) * 0.28;

    setState(() {
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        final angle = (i / _items.length) * 2 * math.pi - (math.pi / 2);
        item.position = Offset(
          centerX + math.cos(angle) * radius,
          centerY + math.sin(angle) * radius,
        );
        item.rotation = angle + (math.pi / 2);
        item.scale = math.min(0.85, size.width / 340.0).clamp(0.6, 0.85);
      }
    });
  }

  void _applyCascade() {
    AppHaptics.mediumImpact();
    if (_items.isEmpty) return;
    final size = _getCanvasSize();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final step = math.min(36.0, size.width / (_items.length + 1));
    final startX = centerX - ((_items.length - 1) * step / 2);
    final startY = centerY - ((_items.length - 1) * step / 2);

    setState(() {
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        item.position = Offset(startX + i * step, startY + i * step);
        item.rotation = (i - (_items.length / 2)) * 0.08;
        item.scale = math.min(0.95, size.width / 320.0).clamp(0.65, 0.95);
      }
    });
  }

  // --- Snapshot Export & Share ---

  Future<void> _captureAndShare() async {
    AppHaptics.mediumImpact();
    setState(() {
      _selectedItemId = null; // Clear selection box for clean image
      _isCapturing = true;
    });

    try {
      // Ensure layout is cleanly painted
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final boundary = _canvasRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Canvas boundary not found');
      }

      // Render at 3.0 pixel ratio for crisp high-resolution vinyl sticker details
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode snapshot');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final timeStr = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/memtickers_snapshot_$timeStr.png');
      await file.writeAsBytes(pngBytes);

      AppHaptics.success();

      // Open Android native share sheet
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Memories on vinyl stickers ✨ #Memtickers',
      );
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share snapshot: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopBar(scheme, textTheme),

            // Interactive Canvas
            Expanded(
              child: Center(
                child: _buildFramedCanvas(scheme),
              ),
            ),

            // Bottom Studio Action Bar
            _buildBottomBar(scheme, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MdSpacing.sm,
        vertical: MdSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: MdSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Studio',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                '${_items.length} stickers on canvas',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Aspect Ratio Cycle
          IconButton(
            icon: Icon(_settings.aspectRatio.icon, size: 20),
            tooltip: 'Aspect ratio: ${_settings.aspectRatio.label}',
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHigh,
            ),
            onPressed: () {
              AppHaptics.selection();
              final ratios = ShareAspectRatio.values;
              final nextIndex =
                  (ratios.indexOf(_settings.aspectRatio) + 1) % ratios.length;
              setState(() {
                _settings = _settings.copyWith(aspectRatio: ratios[nextIndex]);
              });
            },
          ),
          const SizedBox(width: MdSpacing.xs),

          // Background Style Picker
          IconButton(
            icon: Icon(_settings.backgroundStyle.icon, size: 20),
            tooltip: 'Backdrop: ${_settings.backgroundStyle.label}',
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHigh,
            ),
            onPressed: () {
              AppHaptics.selection();
              final styles = ShareBackgroundStyle.values;
              final nextIndex =
                  (styles.indexOf(_settings.backgroundStyle) + 1) %
                      styles.length;
              setState(() {
                _settings =
                    _settings.copyWith(backgroundStyle: styles[nextIndex]);
              });
            },
          ),
          const SizedBox(width: MdSpacing.xs),

          // Snapshot & Share CTA
          M3EFilledButton.icon(
            size: M3EButtonSize.sm,
            onPressed: _isCapturing ? null : _captureAndShare,
            icon: _isCapturing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Widget _buildFramedCanvas(ColorScheme scheme) {
    Widget canvasWidget = RepaintBoundary(
      key: _canvasRepaintKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 1. Studio Backdrop
            Positioned.fill(
              child: _buildBackdrop(scheme),
            ),

            // 2. Stickers with real-time dynamic light reflection
            ..._items.map((item) {
              return StickerReflectionView(
                key: ValueKey(item.id),
                item: item,
                light: _lightSource,
                isSelected: item.id == _selectedItemId && !_isCapturing,
                onTap: () => _selectItem(item.id),
                onPanUpdate: (details) {
                  final canvasSize = _getCanvasSize();
                  final minX = (item.effectiveWidth / 2) + 20.0;
                  final maxX = canvasSize.width - (item.effectiveWidth / 2) - 20.0;
                  final minY = (item.effectiveHeight / 2) + 20.0;
                  final maxY = canvasSize.height - (item.effectiveHeight / 2) - 20.0;
                  setState(() {
                    final nextPos = item.position + details.delta;
                    item.position = Offset(
                      nextPos.dx.clamp(minX, maxX),
                      nextPos.dy.clamp(minY, maxY),
                    );
                  });
                },
                onPanEnd: () => AppHaptics.lightImpact(),
                onScaleChanged: (newScale) {
                  setState(() {
                    item.scale = newScale;
                  });
                },
                onRotateUpdate: (details) {
                  final canvasBox = _canvasRepaintKey.currentContext
                      ?.findRenderObject() as RenderBox?;
                  if (canvasBox != null) {
                    final centerGlobal = canvasBox.localToGlobal(item.position);
                    final vector = details.globalPosition - centerGlobal;
                    final touchAngle = math.atan2(vector.dy, vector.dx);
                    final newAngle = touchAngle + (math.pi / 2);
                    setState(() {
                      item.rotation = newAngle;
                    });
                  } else {
                    setState(() {
                      item.rotation += details.delta.dx / 100.0;
                    });
                  }
                },
                onRotationChanged: (newRotation) {
                  setState(() {
                    item.rotation = newRotation;
                  });
                },
              );
            }),

            // 3. Invisible Light Source Placement Reticle
            // Shown when user is in light adjustment mode, lighting is enabled,
            // and reticle is set to visible (strictly excluded during snapshot capture!).
            if (!_isCapturing &&
                _lightSource.isEnabled &&
                (_isLightMode || _lightSource.isReticleVisible))
              _buildLightReticle(scheme),

            // 4. Memtickers Badge Watermark (if enabled)
            if (_settings.showWatermark)
              Positioned(
                right: 14,
                bottom: 14,
                child: Opacity(
                  opacity: 0.65,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: _settings.backgroundStyle ==
                                ShareBackgroundStyle.cleanWhite
                            ? Colors.black54
                            : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Memtickers',
                        style: TextStyle(
                          fontFamily: 'Excalifont',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _settings.backgroundStyle ==
                                  ShareBackgroundStyle.cleanWhite
                              ? Colors.black54
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // If an aspect ratio is chosen, wrap in AspectRatio widget
    if (_settings.aspectRatio.ratio != null) {
      canvasWidget = AspectRatio(
        aspectRatio: _settings.aspectRatio.ratio!,
        child: canvasWidget,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_isLightMode && _lightSource.isEnabled) {
          // If light mode is active and enabled, tap places the light!
          AppHaptics.lightImpact();
        } else {
          // Deselect sticker on empty canvas tap
          _selectItem(null);
        }
      },
      onTapDown: (details) {
        if (_isLightMode && _lightSource.isEnabled) {
          AppHaptics.lightImpact();
          setState(() {
            _lightSource = _lightSource.copyWith(
              position: details.localPosition,
              isReticleVisible: true,
            );
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.all(MdSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: canvasWidget,
      ),
    );
  }

  Widget _buildBackdrop(ColorScheme scheme) {
    switch (_settings.backgroundStyle) {
      case ShareBackgroundStyle.studioNoir:
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.3),
              radius: 1.1,
              colors: [
                Color(0xFF2C3440),
                Color(0xFF191D24),
                Color(0xFF0E1116),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        );
      case ShareBackgroundStyle.craftPaper:
        return Container(
          color: const Color(0xFFF3E9D9),
          child: CustomPaint(
            painter: _PaperTexturePainter(),
          ),
        );
      case ShareBackgroundStyle.minimalSurface:
        return Container(
          color: scheme.surfaceContainerHigh,
        );
      case ShareBackgroundStyle.sunsetPeach:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFB39A),
                Color(0xFFFF8B7D),
                Color(0xFFEA5455),
              ],
            ),
          ),
        );
      case ShareBackgroundStyle.midnightNeon:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A102F),
                Color(0xFF2E1C4E),
                Color(0xFF4A1E6D),
              ],
            ),
          ),
        );
      case ShareBackgroundStyle.cleanWhite:
        return Container(
          color: Colors.white,
        );
      case ShareBackgroundStyle.transparent:
        return Container(
          color: Colors.transparent,
        );
    }
  }

  /// Luminous interactive reticle indicating the invisible light source position
  Widget _buildLightReticle(ColorScheme scheme) {
    return Positioned(
      left: _lightSource.position.dx - 36,
      top: _lightSource.position.dy - 36,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            _lightSource = _lightSource.copyWith(
              position: _lightSource.position + details.delta,
              isReticleVisible: true,
            );
          });
        },
        onPanEnd: (_) => AppHaptics.lightImpact(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer radiant glow
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _lightSource.tone.color.withValues(
                      alpha: (0.60 * (_lightSource.intensity / 0.85))
                          .clamp(0.12, 0.90),
                    ),
                    _lightSource.tone.color.withValues(
                      alpha: (0.18 * (_lightSource.intensity / 0.85))
                          .clamp(0.04, 0.40),
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Light source core
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _lightSource.tone.color,
                boxShadow: [
                  BoxShadow(
                    color: _lightSource.tone.color.withValues(alpha: 0.8),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _lightSource.tone.icon,
                size: 18,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MdSpacing.sm,
        vertical: MdSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Contextual action bar for currently selected sticker
          if (_selectedItemId != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: MdSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: MdSpacing.sm,
                vertical: MdSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Remove button with clear delete styling
                    M3EFilledButton.icon(
                      size: M3EButtonSize.xs,
                      decoration: M3EButtonDecoration(
                        backgroundColor:
                            WidgetStatePropertyAll(scheme.errorContainer),
                        foregroundColor:
                            WidgetStatePropertyAll(scheme.onErrorContainer),
                      ),
                      onPressed: () {
                        AppHaptics.mediumImpact();
                        final targetId = _selectedItemId;
                        setState(() {
                          _items.removeWhere((it) => it.id == targetId);
                          _selectedItemId = null;
                        });
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Remove Sticker'),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    IconButton(
                      tooltip: 'Flip horizontally',
                      icon: const Icon(Icons.flip_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        AppHaptics.lightImpact();
                        setState(() {
                          final item =
                              _items.firstWhere((it) => it.id == _selectedItemId);
                          item.isFlipped = !item.isFlipped;
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Rotate left (-15°)',
                      icon: const Icon(Icons.rotate_left_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        AppHaptics.lightImpact();
                        setState(() {
                          final item =
                              _items.firstWhere((it) => it.id == _selectedItemId);
                          item.rotation -= (math.pi / 12);
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Rotate right (+15°)',
                      icon: const Icon(Icons.rotate_right_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        AppHaptics.lightImpact();
                        setState(() {
                          final item =
                              _items.firstWhere((it) => it.id == _selectedItemId);
                          item.rotation += (math.pi / 12);
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Bring to front',
                      icon: const Icon(Icons.flip_to_front_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        AppHaptics.lightImpact();
                        setState(() {
                          final item =
                              _items.firstWhere((it) => it.id == _selectedItemId);
                          item.zIndex = _nextZIndex++;
                          _items.sort((a, b) => a.zIndex.compareTo(b.zIndex));
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Send backward',
                      icon: const Icon(Icons.flip_to_back_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        AppHaptics.lightImpact();
                        setState(() {
                          final item =
                              _items.firstWhere((it) => it.id == _selectedItemId);
                          item.zIndex = 0;
                          _items.sort((a, b) => a.zIndex.compareTo(b.zIndex));
                        });
                      },
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    IconButton(
                      tooltip: 'Smaller (-)',
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        AppHaptics.lightImpact();
                        setState(() {
                          final item =
                              _items.firstWhere((it) => it.id == _selectedItemId);
                          item.scale = (item.scale - 0.1).clamp(0.4, 2.5);
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Larger (+)',
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        AppHaptics.lightImpact();
                        setState(() {
                          final item =
                              _items.firstWhere((it) => it.id == _selectedItemId);
                          item.scale = (item.scale + 0.1).clamp(0.4, 2.5);
                        });
                      },
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    IconButton(
                      tooltip: 'Done',
                      icon: const Icon(Icons.check_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        AppHaptics.lightImpact();
                        setState(() => _selectedItemId = null);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],

          // If Light Mode is on, show comprehensive light configuration controls
          if (_isLightMode) ...[
            Row(
              children: [
                Icon(
                  _lightSource.isEnabled
                      ? _lightSource.tone.icon
                      : Icons.blur_off_rounded,
                  size: 20,
                  color: _lightSource.isEnabled ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: MdSpacing.xs),
                Expanded(
                  child: Text(
                    _lightSource.isEnabled
                        ? 'Lighting: ${_lightSource.isReticleVisible ? "Visible Reticle" : "Invisible"}'
                        : 'Lighting: Flat (Disabled)',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                // Toggle lighting completely ON or OFF (Flat)
                TextButton.icon(
                  onPressed: () {
                    AppHaptics.mediumImpact();
                    setState(() {
                      final newEnabled = !_lightSource.isEnabled;
                      _lightSource = _lightSource.copyWith(
                        isEnabled: newEnabled,
                        isReticleVisible: newEnabled,
                      );
                    });
                  },
                  icon: Icon(
                    _lightSource.isEnabled
                        ? Icons.flash_off_rounded
                        : Icons.flash_on_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _lightSource.isEnabled ? 'Disable (Flat)' : 'Enable Light',
                  ),
                ),
                if (_lightSource.isEnabled) ...[
                  const SizedBox(width: MdSpacing.xxs),
                  // Toggle invisibility
                  TextButton.icon(
                    onPressed: () {
                      AppHaptics.lightImpact();
                      setState(() {
                        _lightSource = _lightSource.copyWith(
                          isReticleVisible: !_lightSource.isReticleVisible,
                        );
                      });
                    },
                    icon: Icon(
                      _lightSource.isReticleVisible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _lightSource.isReticleVisible
                          ? 'Make Invisible'
                          : 'Show Reticle',
                    ),
                  ),
                ],
              ],
            ),
            if (!_lightSource.isEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: MdSpacing.xs),
                child: Text(
                  'Lighting is disabled. Stickers appear flat without reflections.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            // Tone selector chips & intensity control (only visible when lighting is enabled)
            if (_lightSource.isEnabled) ...[
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ShareLightTone.values.map((tone) {
                    final isSelected = _lightSource.tone == tone;
                    return Padding(
                      padding: const EdgeInsets.only(right: MdSpacing.xs),
                      child: FilterChip(
                        selected: isSelected,
                        avatar: CircleAvatar(
                          backgroundColor: tone.color,
                          radius: 7,
                        ),
                        label: Text(tone.label),
                        onSelected: (val) {
                          AppHaptics.selection();
                          setState(() {
                            _lightSource = _lightSource.copyWith(tone: tone);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: MdSpacing.xs),
              // Light Intensity Slider Control
              Padding(
                padding: const EdgeInsets.only(bottom: MdSpacing.xxs),
                child: Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    Text(
                      'Intensity',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: _lightSource.intensity.clamp(0.1, 1.0),
                          min: 0.1,
                          max: 1.0,
                          divisions: 18,
                          label: '${(_lightSource.intensity * 100).round()}%',
                          onChanged: (val) {
                            setState(() {
                              _lightSource =
                                  _lightSource.copyWith(intensity: val);
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${(_lightSource.intensity * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MdSpacing.xs),
          ],

          // Primary bottom tool strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Add / Choose Stickers
                M3EFilledButton.tonalIcon(
                  size: M3EButtonSize.sm,
                  onPressed: _openStickerPicker,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: const Text('Stickers'),
                ),
                const SizedBox(width: MdSpacing.xs),

                // Lighting Section Toggle (Reflects Flat vs Active vs Off)
                FilterChip(
                  avatar: Icon(
                    !_lightSource.isEnabled
                        ? Icons.blur_off_rounded
                        : (_isLightMode
                            ? Icons.highlight_rounded
                            : Icons.light_mode_outlined),
                    size: 16,
                  ),
                  label: Text(!_lightSource.isEnabled
                      ? 'Lighting (Flat)'
                      : (_isLightMode ? 'Lighting (Active)' : 'Lighting')),
                  selected: _isLightMode,
                  onSelected: (val) {
                    AppHaptics.lightImpact();
                    setState(() {
                      _isLightMode = val;
                      if (val && _lightSource.isEnabled) {
                        _lightSource =
                            _lightSource.copyWith(isReticleVisible: true);
                      }
                    });
                  },
                ),
                const SizedBox(width: MdSpacing.xs),

                // Auto-Layout Options Menu
                PopupMenuButton<String>(
                  tooltip: 'Align & Layout',
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHigh,
                  ),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'scatter':
                        _applyArtisticScatter();
                        break;
                      case 'grid':
                        _applyCleanGrid();
                        break;
                      case 'crown':
                        _applyCircularCrown();
                        break;
                      case 'cascade':
                        _applyCascade();
                        break;
                      case 'clear_all':
                        AppHaptics.mediumImpact();
                        setState(() {
                          _items.clear();
                          _selectedItemId = null;
                        });
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'scatter',
                      child: Row(
                        children: [
                          Icon(Icons.grain_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Artistic Scatter'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'grid',
                      child: Row(
                        children: [
                          Icon(Icons.grid_on_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Clean Grid'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'crown',
                      child: Row(
                        children: [
                          Icon(Icons.donut_large_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Circular Crown'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cascade',
                      child: Row(
                        children: [
                          Icon(Icons.style_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Cascade Fan'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_sweep_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Clear Canvas'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: MdSpacing.xs),

                // Watermark toggle chip
                FilterChip(
                  avatar: const Icon(Icons.branding_watermark_rounded, size: 16),
                  label: const Text('Badge'),
                  selected: _settings.showWatermark,
                  onSelected: (val) {
                    AppHaptics.selection();
                    setState(() {
                      _settings = _settings.copyWith(showWatermark: val);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paper grain texture painter for craft paper background
class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.brown.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final random = math.Random(101);
    for (int i = 0; i < 400; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.5 + random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
