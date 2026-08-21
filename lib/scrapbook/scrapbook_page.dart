import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

import '../capture/capture_page.dart';
import '../data/sticker.dart';
import '../data/sticker_repository.dart';
import '../details/sticker_details_sheet.dart';
import '../settings/sticker_settings_sheet.dart';
import '../tags/tags_sheet.dart';
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

  void _openTags() {
    showTagsSheet(context: context, repository: widget.repository);
  }

  void _openSettings() {
    showStickerSettings(context: context, repository: widget.repository);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: margin * 1.5,
                  vertical: margin,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Layered Expressive Shape Illustration
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          M3EShape.flower(
                            width: 110,
                            height: 110,
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          M3EShape.c12SidedCookie(
                            width: 80,
                            height: 80,
                            color: scheme.primaryContainer,
                          ),
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 38,
                            color: scheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                      const SizedBox(height: MdSpacing.md),
                      Text(
                        'Peel a memory onto the board',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MdSpacing.xs),
                      Text(
                        'Capture photos and drop them as vinyl stickers on your infinite scrapbook canvas.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MdSpacing.md),
                      Wrap(
                        spacing: MdSpacing.xs,
                        runSpacing: MdSpacing.xs,
                        alignment: WrapAlignment.center,
                        children: [
                          M3EFilledButton.icon(
                            size: M3EButtonSize.sm,
                            onPressed: () {
                              M3EHapticFeedback.medium.apply();
                              _openCapture(gallery: false);
                            },
                            icon: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                            ),
                            label: const Text('Take Photo'),
                          ),
                          M3EFilledButton.tonalIcon(
                            size: M3EButtonSize.sm,
                            onPressed: () {
                              M3EHapticFeedback.medium.apply();
                              _openCapture(gallery: true);
                            },
                            icon: const Icon(
                              Icons.photo_library_rounded,
                              size: 18,
                            ),
                            label: const Text('Pick Photo'),
                          ),
                        ],
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
                tooltip: 'Scrapbook actions',
                decoration: M3EFloatingToolbarDecoration(
                  colors: M3EFloatingToolbarColors(
                    toolbarContainerColor: scheme.surfaceContainerHighest,
                    toolbarContentColor: scheme.onSurface,
                    fabContainerColor: scheme.primary,
                    fabContentColor: scheme.onPrimary,
                  ),
                  shape: const StadiumBorder(),
                  expandedShadowElevation: 6,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: MdSpacing.xs,
                    vertical: MdSpacing.xxs,
                  ),
                ),
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Gallery',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHigh,
                        padding: const EdgeInsets.all(MdSpacing.xs),
                      ),
                      onPressed: () {
                        M3EHapticFeedback.light.apply();
                        _openCapture(gallery: true);
                      },
                      icon: const Icon(Icons.photo_library_outlined, size: 22),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    M3EFilledButton.icon(
                      size: M3EButtonSize.sm,
                      onPressed: () {
                        M3EHapticFeedback.medium.apply();
                        _openCapture(gallery: false);
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 20),
                      label: const Text('Capture'),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    IconButton(
                      tooltip: 'Tags',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHigh,
                        padding: const EdgeInsets.all(MdSpacing.xs),
                      ),
                      onPressed: () {
                        M3EHapticFeedback.light.apply();
                        _openTags();
                      },
                      icon: const Icon(Icons.label_outline_rounded, size: 22),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    IconButton(
                      tooltip: 'Adjustments',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHigh,
                        padding: const EdgeInsets.all(MdSpacing.xs),
                      ),
                      onPressed: () {
                        M3EHapticFeedback.light.apply();
                        _openSettings();
                      },
                      icon: const Icon(Icons.tune_rounded, size: 22),
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
