import 'dart:io';
import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import '../data/sticker.dart';
import '../data/sticker_repository.dart';
import '../theme/app_haptics.dart';
import '../theme/spacing.dart';

/// Bottom sheet allowing users to pick and add stickers from any board to the Share Studio canvas.
Future<List<Sticker>?> showShareStickerPicker({
  required BuildContext context,
  required StickerRepository repository,
  required Set<String> currentlySelectedIds,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) {
    return showGeneralDialog<List<Sticker>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss sticker picker',
      pageBuilder: (context, animation, secondary) {
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 480,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(MdSpacing.extraLargeIncreased),
              ),
              child: SafeArea(
                child: _ShareStickerPickerBody(
                  repository: repository,
                  initiallySelectedIds: currentlySelectedIds,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<List<Sticker>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MdSpacing.extraLargeIncreased),
      ),
    ),
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.80,
          child: _ShareStickerPickerBody(
            repository: repository,
            initiallySelectedIds: currentlySelectedIds,
          ),
        ),
      );
    },
  );
}

class _ShareStickerPickerBody extends StatefulWidget {
  const _ShareStickerPickerBody({
    required this.repository,
    required this.initiallySelectedIds,
  });

  final StickerRepository repository;
  final Set<String> initiallySelectedIds;

  @override
  State<_ShareStickerPickerBody> createState() => _ShareStickerPickerBodyState();
}

class _ShareStickerPickerBodyState extends State<_ShareStickerPickerBody> {
  late String _selectedBoardId;
  late final Set<String> _selectedStickerIds;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedBoardId = widget.repository.activeBoardId;
    _selectedStickerIds = Set<String>.from(widget.initiallySelectedIds);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Sticker> _getFilteredStickers() {
    final boardStickers =
        widget.repository.getStickersForBoard(_selectedBoardId);
    if (_searchQuery.isEmpty) return boardStickers;

    return boardStickers.where((s) {
      final placeMatch =
          s.placeLabel?.toLowerCase().contains(_searchQuery) ?? false;
      final tagMatch =
          s.tags.any((t) => t.toLowerCase().contains(_searchQuery));
      final modelTagMatch =
          s.modelTags.any((t) => t.toLowerCase().contains(_searchQuery));
      return placeMatch || tagMatch || modelTagMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final boards = widget.repository.boards;
    final filtered = _getFilteredStickers();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MdSpacing.md,
            vertical: MdSpacing.xs,
          ),
          child: Row(
            children: [
              Text(
                'Choose Stickers',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  AppHaptics.lightImpact();
                  setState(() {
                    if (_selectedStickerIds.length == filtered.length) {
                      _selectedStickerIds.clear();
                    } else {
                      _selectedStickerIds
                          .addAll(filtered.map((s) => s.id));
                    }
                  });
                },
                child: Text(
                  _selectedStickerIds.length == filtered.length
                      ? 'Deselect All'
                      : 'Select All',
                ),
              ),
            ],
          ),
        ),

        // Board selection pills
        if (boards.length > 1)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: MdSpacing.md),
              itemCount: boards.length,
              separatorBuilder: (context, index) => const SizedBox(width: MdSpacing.xs),
              itemBuilder: (context, index) {
                final board = boards[index];
                final isSelected = board.id == _selectedBoardId;
                return FilterChip(
                  label: Text(board.name),
                  selected: isSelected,
                  onSelected: (val) {
                    AppHaptics.selection();
                    setState(() => _selectedBoardId = board.id);
                  },
                );
              },
            ),
          ),

        const SizedBox(height: MdSpacing.xs),

        // Search text field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MdSpacing.md),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by title or tag...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MdSpacing.sm,
                vertical: MdSpacing.xs,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MdSpacing.radiusFull),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: MdSpacing.xs),

        // Grid of stickers
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.collections_bookmark_outlined,
                        size: 48,
                        color: scheme.outline,
                      ),
                      const SizedBox(height: MdSpacing.xs),
                      Text(
                        'No stickers found',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(MdSpacing.md),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: MdSpacing.sm,
                    mainAxisSpacing: MdSpacing.sm,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final sticker = filtered[index];
                    final isSelected = _selectedStickerIds.contains(sticker.id);

                    return GestureDetector(
                      onTap: () {
                        AppHaptics.selection();
                        setState(() {
                          if (isSelected) {
                            _selectedStickerIds.remove(sticker.id);
                          } else {
                            _selectedStickerIds.add(sticker.id);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.primaryContainer.withValues(alpha: 0.35)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? scheme.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(MdSpacing.xs),
                              child: Image.file(
                                File(sticker.imagePath),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.image_not_supported_rounded,
                                  color: scheme.outline,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? scheme.primary
                                      : scheme.surface.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: scheme.onPrimary,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Confirmation Bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MdSpacing.md,
            vertical: MdSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${_selectedStickerIds.length} selected',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              M3EFilledButton(
                size: M3EButtonSize.sm,
                onPressed: () {
                  AppHaptics.mediumImpact();
                  final selectedList = widget.repository.stickers
                      .where((s) => _selectedStickerIds.contains(s.id))
                      .toList();
                  Navigator.of(context).pop(selectedList);
                },
                child: const Text('Add to Canvas'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
