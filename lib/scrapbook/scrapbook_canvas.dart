import 'package:flutter/material.dart';

import '../data/sticker.dart';
import '../data/sticker_repository.dart';
import 'sticker_object.dart';

const double kBoardSize = 4000;

class ScrapbookCanvas extends StatefulWidget {
  const ScrapbookCanvas({
    super.key,
    required this.repository,
    required this.transformationController,
    required this.onStickerTap,
    this.droppingId,
  });

  final StickerRepository repository;
  final TransformationController transformationController;
  final ValueChanged<Sticker> onStickerTap;
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
    final scheme = Theme.of(context).colorScheme;
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
                            final scale = widget
                                .transformationController
                                .value
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
