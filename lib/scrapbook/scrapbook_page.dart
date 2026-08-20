import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

import '../capture/capture_page.dart';
import '../data/sticker.dart';
import '../data/sticker_repository.dart';
import '../details/sticker_details_sheet.dart';
import '../settings/sticker_settings_sheet.dart';
import '../theme/spacing.dart';
import 'scrapbook_canvas.dart';

class ScrapbookPage extends StatefulWidget {
  const ScrapbookPage({super.key, required this.repository});

  final StickerRepository repository;

  @override
  State<ScrapbookPage> createState() => _ScrapbookPageState();
}

class _ScrapbookPageState extends State<ScrapbookPage> {
  final _transform = TransformationController();
  String? _droppingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.sizeOf(context);
      final start = Offset(
        (kBoardSize - size.width) / 2,
        (kBoardSize - size.height) / 2,
      );
      _transform.value = Matrix4.identity()
        ..translateByDouble(-start.dx, -start.dy, 0, 1);
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Offset _dropPoint(Size viewport) {
    return boardCenterOfView(_transform, viewport) - const Offset(84, 84);
  }

  Future<void> _openCapture({required bool gallery}) async {
    final size = MediaQuery.sizeOf(context);
    final drop = _dropPoint(size);
    final result = await Navigator.of(context).push<CaptureResult>(
      MaterialPageRoute(
        builder: (context) => CapturePage(
          repository: widget.repository,
          dropX: drop.dx.clamp(80, kBoardSize - 240),
          dropY: drop.dy.clamp(80, kBoardSize - 240),
          openGalleryImmediately: gallery,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _droppingId = result.sticker.id);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _droppingId = null);
    });
  }

  void _openDetails(Sticker sticker) {
    showStickerDetails(
      context: context,
      sticker: sticker,
      repository: widget.repository,
    );
  }

  void _openSettings() {
    showStickerSettings(
      context: context,
      repository: widget.repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = widget.repository.stickers.isEmpty;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final margin = compact ? MdSpacing.compactMargin : MdSpacing.mediumMargin;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: widget.repository,
              builder: (context, _) {
                return ScrapbookCanvas(
                  repository: widget.repository,
                  transformationController: _transform,
                  droppingId: _droppingId,
                  onStickerTap: _openDetails,
                );
              },
            ),
          ),
          if (empty)
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(margin),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      M3EShape.flower(
                        width: 96,
                        height: 96,
                        color: scheme.primaryContainer,
                      ),
                      const SizedBox(height: MdSpacing.md),
                      Text(
                        'Peel a memory onto the board',
                        style: Theme.of(context).textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MdSpacing.xs),
                      Text(
                        'Capture a photo and drop it as a vinyl sticker.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: margin + MediaQuery.paddingOf(context).bottom,
              ),
              child: M3EHorizontalFloatingToolbar(
                expanded: true,
                tooltip: 'Capture dock',
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Camera',
                      onPressed: () {
                        M3EHapticFeedback.medium.apply();
                        _openCapture(gallery: false);
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                    IconButton(
                      tooltip: 'Gallery',
                      onPressed: () {
                        M3EHapticFeedback.medium.apply();
                        _openCapture(gallery: true);
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () {
                        M3EHapticFeedback.medium.apply();
                        _openSettings();
                      },
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
