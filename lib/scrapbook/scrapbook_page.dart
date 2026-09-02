import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

import '../boards/boards_sheet.dart';
import '../capture/capture_page.dart';
import '../data/sticker.dart';
import '../data/sticker_repository.dart';
import '../details/sticker_details_sheet.dart';
import '../search/search_sheet.dart';
import '../search/sticker_search_filter.dart';
import '../settings/sticker_settings_sheet.dart';
import '../tags/tags_sheet.dart';
import '../theme/app_haptics.dart';
import '../theme/spacing.dart';
import 'scrapbook_canvas.dart';

class ScrapbookPage extends StatefulWidget {
  const ScrapbookPage({super.key, required this.repository});

  final StickerRepository repository;

  @override
  State<ScrapbookPage> createState() => _ScrapbookPageState();
}

class _ScrapbookPageState extends State<ScrapbookPage>
    with TickerProviderStateMixin {
  final _transform = TransformationController();
  AnimationController? _matrixAnimationController;
  String? _droppingId;
  String? _snappingId;
  StickerSearchFilter? _activeFilter;

  bool get _isSearching => _activeFilter != null && _activeFilter!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCanvas();
    });
  }

  void _centerCanvas() {
    final size = MediaQuery.sizeOf(context);
    final start = Offset(
      (kBoardSize - size.width) / 2,
      (kBoardSize - size.height) / 2,
    );
    _transform.value = Matrix4.identity()
      ..translateByDouble(-start.dx, -start.dy, 0, 1);
  }

  @override
  void dispose() {
    _matrixAnimationController?.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _animateToMatrix(
    Matrix4 targetMatrix, {
    Duration duration = const Duration(milliseconds: 600),
  }) {
    _matrixAnimationController?.stop();
    _matrixAnimationController?.dispose();

    final startMatrix = _transform.value;
    final controller = AnimationController(vsync: this, duration: duration);
    _matrixAnimationController = controller;

    final curved = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubicEmphasized,
    );
    final matrixTween = Matrix4Tween(begin: startMatrix, end: targetMatrix);

    controller.addListener(() {
      _transform.value = matrixTween.evaluate(curved);
    });

    controller.forward().whenComplete(() {
      controller.dispose();
      if (_matrixAnimationController == controller) {
        _matrixAnimationController = null;
      }
    });
  }

  Offset _dropPoint(Size viewport) {
    return boardCenterOfView(_transform, viewport) - const Offset(84, 84);
  }

  Future<void> _openCapture({required bool gallery}) async {
    if (widget.repository.activeBoard.isNavigationMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${widget.repository.activeBoard.name}" is in navigation mode (locked).',
          ),
          action: SnackBarAction(
            label: 'Unlock',
            onPressed: () {
              widget.repository.setBoardNavigationMode(
                widget.repository.activeBoardId,
                false,
              );
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

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

  Future<void> _openDetails(Sticker sticker) async {
    final deleted = await showStickerDetails(
      context: context,
      sticker: sticker,
      repository: widget.repository,
    );

    if (deleted == true && mounted) {
      setState(() => _snappingId = sticker.id);
      AppHaptics.snapDisintegrate();
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        await widget.repository.delete(sticker.id);
        setState(() => _snappingId = null);
      }
    }
  }

  Future<void> _openSearch() async {
    final result = await showStickerSearchSheet(
      context: context,
      repository: widget.repository,
      initialFilter: _activeFilter,
    );

    if (!mounted) return;

    setState(() => _activeFilter = result);

    if (result != null && result.isNotEmpty) {
      final matching = widget.repository.stickers
          .where((s) => result.matches(s))
          .toList();
      final viewport = MediaQuery.sizeOf(context);
      final double targetScale = matching.length <= 4
          ? 1.0
          : (matching.length <= 9 ? 0.85 : 0.7);

      final centerMatrix = matrixForCenter(
        const Offset(kBoardSize / 2, kBoardSize / 2),
        viewport,
        scale: targetScale,
      );
      _animateToMatrix(centerMatrix);
    }
  }

  void _onBundledStickerTap(Sticker sticker) {
    AppHaptics.mediumImpact();
    setState(() {
      _activeFilter = null;
      _droppingId = sticker.id;
    });

    final viewport = MediaQuery.sizeOf(context);
    final targetCenter = Offset(sticker.x + 84, sticker.y + 84);
    final targetMatrix = matrixForCenter(targetCenter, viewport, scale: 1.0);
    _animateToMatrix(targetMatrix);

    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _droppingId = null);
    });
  }

  void _openBoards() {
    showBoardsSheet(
      context: context,
      repository: widget.repository,
      onBoardSelected: (board) {
        setState(() {
          _activeFilter = null;
        });
        final viewport = MediaQuery.sizeOf(context);
        final centerMatrix = matrixForCenter(
          const Offset(kBoardSize / 2, kBoardSize / 2),
          viewport,
          scale: 1.0,
        );
        _animateToMatrix(centerMatrix);
      },
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
    final compact = MediaQuery.sizeOf(context).width < 600;
    final margin = compact ? MdSpacing.compactMargin : MdSpacing.mediumMargin;
    final isSearching = _isSearching;

    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.repository,
        builder: (context, _) {
          final activeBoard = widget.repository.activeBoard;
          final empty = widget.repository.stickers.isEmpty;

          return Stack(
            children: [
              Positioned.fill(
                child: ScrapbookCanvas(
                  repository: widget.repository,
                  transformationController: _transform,
                  searchFilter: _activeFilter,
                  onBundledStickerTap: _onBundledStickerTap,
                  droppingId: _droppingId,
                  snappingId: _snappingId,
                  onStickerTap: _openDetails,
                ),
              ),

          // Active Search Status Banner
          if (isSearching)
            Positioned(
              top: MediaQuery.paddingOf(context).top + MdSpacing.xs,
              left: margin,
              right: margin,
              child: Center(
                child: Material(
                  elevation: 6,
                  shadowColor: scheme.shadow.withValues(alpha: 0.25),
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(MdSpacing.radiusFull),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(MdSpacing.radiusFull),
                    onTap: _openSearch,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        MdSpacing.sm,
                        MdSpacing.xxs,
                        MdSpacing.xxs,
                        MdSpacing.xxs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: MdSpacing.xs),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _activeFilter!.summaryDescription.isNotEmpty
                                      ? _activeFilter!.summaryDescription
                                      : 'Filtered Results',
                                  style: textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Tap sticker to navigate on board',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: MdSpacing.xs),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Exit search',
                            style: IconButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              backgroundColor: scheme.surfaceContainerHigh,
                            ),
                            onPressed: () {
                              AppHaptics.lightImpact();
                              setState(() => _activeFilter = null);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Active Navigation Mode Lock Indicator
          if (activeBoard.isNavigationMode)
            Positioned(
              top: MediaQuery.paddingOf(context).top + MdSpacing.xs,
              right: margin,
              child: Tooltip(
                message: 'Navigation mode (locked)',
                child: Material(
                  elevation: 3,
                  shadowColor: scheme.shadow.withValues(alpha: 0.2),
                  color: scheme.tertiaryContainer,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      AppHaptics.lightImpact();
                      _openBoards();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(MdSpacing.xs),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (empty && !isSearching)
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
                        'Peel a memory onto ${activeBoard.name}',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MdSpacing.xs),
                      Text(
                        'Capture photos and drop them as vinyl stickers on this scrapbook board.',
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
                              AppHaptics.mediumImpact();
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
                              AppHaptics.mediumImpact();
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
                        AppHaptics.lightImpact();
                        _openCapture(gallery: true);
                      },
                      icon: const Icon(Icons.photo_library_outlined, size: 22),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    M3EFilledButton.icon(
                      size: M3EButtonSize.sm,
                      onPressed: () {
                        AppHaptics.mediumImpact();
                        _openCapture(gallery: false);
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 20),
                      label: const Text('Capture'),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    IconButton(
                      tooltip: 'Boards',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHigh,
                        padding: const EdgeInsets.all(MdSpacing.xs),
                      ),
                      onPressed: () {
                        AppHaptics.lightImpact();
                        _openBoards();
                      },
                      icon: const Icon(
                        Icons.dashboard_customize_outlined,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    IconButton(
                      tooltip: 'Search',
                      style: IconButton.styleFrom(
                        backgroundColor: isSearching
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHigh,
                        foregroundColor: isSearching
                            ? scheme.onPrimaryContainer
                            : null,
                        padding: const EdgeInsets.all(MdSpacing.xs),
                      ),
                      onPressed: () {
                        AppHaptics.lightImpact();
                        _openSearch();
                      },
                      icon: Icon(
                        isSearching
                            ? Icons.search_rounded
                            : Icons.search_outlined,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    IconButton(
                      tooltip: 'Tags',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHigh,
                        padding: const EdgeInsets.all(MdSpacing.xs),
                      ),
                      onPressed: () {
                        AppHaptics.lightImpact();
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
                        AppHaptics.lightImpact();
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
      );
    },
  ),
);
  }
}
