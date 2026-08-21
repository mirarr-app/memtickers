import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

import '../data/sticker.dart';
import '../data/sticker_repository.dart';
import '../search/sticker_search_filter.dart';
import '../theme/spacing.dart';
import 'sticker_object.dart';

const double kBoardSize = 4000;

class BundledStickerLayout {
  static List<({Sticker sticker, Offset position, double rotation})> compute({
    required List<Sticker> stickers,
    required Offset center,
    double cellSize = 190.0,
  }) {
    if (stickers.isEmpty) return const [];
    final n = stickers.length;
    final int cols;
    if (n <= 2) {
      cols = n;
    } else if (n <= 6) {
      cols = (n <= 4) ? 2 : 3;
    } else if (n <= 12) {
      cols = 3;
    } else {
      cols = 4;
    }
    final rows = (n / cols).ceil();
    final totalWidth = cols * cellSize;
    final totalHeight = rows * cellSize;
    final startX = center.dx - (totalWidth / 2);
    final startY = center.dy - (totalHeight / 2);

    return List.generate(n, (i) {
      final col = i % cols;
      final row = i ~/ cols;
      final x = startX + col * cellSize;
      final y = startY + row * cellSize;
      final rot = ((i % 5) - 2) * 0.035; // Subtle vinyl tilt (-4° to +4°)
      return (sticker: stickers[i], position: Offset(x, y), rotation: rot);
    });
  }
}

class ScrapbookCanvas extends StatefulWidget {
  const ScrapbookCanvas({
    super.key,
    required this.repository,
    required this.transformationController,
    required this.onStickerTap,
    this.searchFilter,
    this.onBundledStickerTap,
    this.droppingId,
  });

  final StickerRepository repository;
  final TransformationController transformationController;
  final ValueChanged<Sticker> onStickerTap;
  final StickerSearchFilter? searchFilter;
  final ValueChanged<Sticker>? onBundledStickerTap;
  final String? droppingId;

  @override
  State<ScrapbookCanvas> createState() => _ScrapbookCanvasState();
}

class _ScrapbookCanvasState extends State<ScrapbookCanvas> {
  String? _selectedId;
  String? _activeId;
  Offset? _lastFocal;
  double _startScale = 1;
  double _startRotation = 0;
  int _pointers = 0;

  bool get _isSearching =>
      widget.searchFilter != null && widget.searchFilter!.isNotEmpty;

  List<Sticker> get _filteredStickers {
    if (!_isSearching) return widget.repository.stickers;
    return widget.repository.stickers
        .where((s) => widget.searchFilter!.matches(s))
        .toList();
  }

  List<Sticker> get _sorted {
    final copy = [...widget.repository.stickers];
    copy.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return copy;
  }

  Future<void> _bringToFront(Sticker sticker) async {
    final updated = sticker.copyWith(zIndex: widget.repository.nextZIndex());
    await widget.repository.updateTransform(updated);
    setState(() => _selectedId = sticker.id);
  }

  Future<void> _persist(Sticker sticker) {
    return widget.repository.updateTransform(sticker);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_isSearching) {
      final matching = _filteredStickers;
      final bundled = BundledStickerLayout.compute(
        stickers: matching,
        center: const Offset(kBoardSize / 2, kBoardSize / 2),
      );

      return InteractiveViewer(
        transformationController: widget.transformationController,
        constrained: false,
        minScale: 0.35,
        maxScale: 3.5,
        boundaryMargin: const EdgeInsets.all(300),
        child: SizedBox(
          width: kBoardSize,
          height: kBoardSize,
          child: ColoredBox(
            color: scheme.surface,
            child: Stack(
              children: [
                if (matching.isEmpty)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Container(
                        padding: const EdgeInsets.all(MdSpacing.lg),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            MdSpacing.radiusXlIncreased,
                          ),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: MdSpacing.sm),
                            Text(
                              'No matching stickers',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: MdSpacing.xxs),
                            Text(
                              'No memory stickers match your current search filters. Try adjusting tags, date range, or location.',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Bundled search results
                  for (final item in bundled)
                    Positioned(
                      key: ValueKey('search-${item.sticker.id}'),
                      left: item.position.dx,
                      top: item.position.dy,
                      child: Transform.rotate(
                        angle: item.rotation,
                        child: StickerObject(
                          key: ValueKey('search-obj-${item.sticker.id}'),
                          sticker: item.sticker,
                          selected: _selectedId == item.sticker.id,
                          dropping: widget.droppingId == item.sticker.id,
                          onTap: () {
                            M3EHapticFeedback.medium.apply();
                            widget.onBundledStickerTap?.call(item.sticker);
                          },
                          onLongPress: () {},
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return InteractiveViewer(
      transformationController: widget.transformationController,
      constrained: false,
      minScale: 0.35,
      maxScale: 3.5,
      panEnabled: _activeId == null,
      scaleEnabled: _activeId == null,
      boundaryMargin: const EdgeInsets.all(300),
      child: SizedBox(
        width: kBoardSize,
        height: kBoardSize,
        child: ColoredBox(
          color: scheme.surface,
          child: Stack(
            children: [
              for (final sticker in _sorted)
                Positioned(
                  key: ValueKey(sticker.id),
                  left: sticker.x,
                  top: sticker.y,
                  child: Transform.rotate(
                    angle: sticker.rotation,
                    child: Transform.scale(
                      scale: sticker.scale,
                      child: Listener(
                        onPointerDown: (_) {
                          setState(() {
                            _pointers++;
                            _activeId = sticker.id;
                          });
                        },
                        onPointerUp: (_) {
                          setState(() {
                            _pointers = (_pointers - 1).clamp(0, 8);
                            if (_pointers == 0) _activeId = null;
                          });
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: (details) {
                            _lastFocal = details.focalPoint;
                            _startScale = sticker.scale;
                            _startRotation = sticker.rotation;
                          },
                          onScaleUpdate: (details) {
                            if (_activeId != sticker.id) return;
                            final current = widget.repository.stickers
                                .where((s) => s.id == sticker.id)
                                .firstOrNull;
                            if (current == null) return;
                            final last = _lastFocal ?? details.focalPoint;
                            final delta = details.focalPoint - last;
                            _lastFocal = details.focalPoint;
                            final scale = widget.transformationController.value
                                .getMaxScaleOnAxis();
                            final sceneDelta = delta / scale;
                            var nextScale = _startScale * details.scale;
                            nextScale = nextScale.clamp(0.45, 2.8);
                            final next = current.copyWith(
                              x: current.x + sceneDelta.dx,
                              y: current.y + sceneDelta.dy,
                              scale: nextScale,
                              rotation: _startRotation + details.rotation,
                            );
                            widget.repository.updateTransform(next);
                          },
                          onScaleEnd: (_) {
                            _lastFocal = null;
                            final current = widget.repository.stickers
                                .where((s) => s.id == sticker.id)
                                .firstOrNull;
                            if (current != null) _persist(current);
                          },
                          child: StickerObject(
                            key: ValueKey('object-${sticker.id}'),
                            sticker: sticker,
                            selected: _selectedId == sticker.id,
                            dropping: widget.droppingId == sticker.id,
                            onTap: () {
                              setState(() => _selectedId = sticker.id);
                              widget.onStickerTap(sticker);
                            },
                            onLongPress: () => _bringToFront(sticker),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Offset boardCenterOfView(TransformationController controller, Size viewport) {
  final inverse = Matrix4.inverted(controller.value);
  return MatrixUtils.transformPoint(
    inverse,
    Offset(viewport.width / 2, viewport.height / 2),
  );
}

Matrix4 matrixForCenter(
  Offset boardPoint,
  Size viewport, {
  double scale = 1.0,
}) {
  final tx = -boardPoint.dx * scale + viewport.width / 2;
  final ty = -boardPoint.dy * scale + viewport.height / 2;
  return Matrix4.identity()
    ..translateByDouble(tx, ty, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
}
