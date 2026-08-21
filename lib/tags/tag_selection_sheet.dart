import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

import '../data/sticker_repository.dart';
import '../theme/spacing.dart';

/// Opens an M3 Expressive Tag Selection sheet that immediately focuses
/// the keyboard for fast search and inline creation.
Future<Set<String>?> showTagSelectionSheet({
  required BuildContext context,
  required StickerRepository repository,
  required Set<String> initialSelectedTags,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) {
    return showGeneralDialog<Set<String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss tag selection',
      pageBuilder: (context, animation, secondary) {
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 440,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(MdSpacing.extraLargeIncreased),
              ),
              child: SafeArea(
                child: _TagSelectionBody(
                  repository: repository,
                  initialSelectedTags: initialSelectedTags,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<Set<String>>(
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
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: _TagSelectionBody(
              repository: repository,
              initialSelectedTags: initialSelectedTags,
            ),
          ),
        ),
      );
    },
  );
}

class _TagSelectionBody extends StatefulWidget {
  const _TagSelectionBody({
    required this.repository,
    required this.initialSelectedTags,
  });

  final StickerRepository repository;
  final Set<String> initialSelectedTags;

  @override
  State<_TagSelectionBody> createState() => _TagSelectionBodyState();
}

class _TagSelectionBodyState extends State<_TagSelectionBody> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final Set<String> _selected;
  String _query = '';
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelectedTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _createAndSelect(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _isCreating) return;

    setState(() => _isCreating = true);
    try {
      M3EHapticFeedback.medium.apply();
      final tag = await widget.repository.createTag(trimmed);
      setState(() {
        _selected.add(tag.name);
        _searchController.clear();
        _query = '';
      });
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _toggleTag(String tagName) {
    M3EHapticFeedback.light.apply();
    setState(() {
      if (_selected.contains(tagName)) {
        _selected.remove(tagName);
      } else {
        _selected.add(tagName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final allTags = widget.repository.tags;
        final trimmedQuery = _query.trim();
        final filteredTags = trimmedQuery.isEmpty
            ? allTags
            : allTags
                  .where(
                    (t) => t.name.toLowerCase().contains(
                      trimmedQuery.toLowerCase(),
                    ),
                  )
                  .toList();

        final hasExactMatch =
            trimmedQuery.isNotEmpty &&
            allTags.any(
              (t) => t.name.toLowerCase() == trimmedQuery.toLowerCase(),
            );

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            MdSpacing.sm,
            MdSpacing.xs,
            MdSpacing.sm,
            MdSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                    ),
                    child: Icon(
                      Icons.label_rounded,
                      color: scheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: MdSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Tags',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _selected.isEmpty
                              ? 'Tap to select or type to create'
                              : '${_selected.length} selected',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  M3EFilledButton(
                    size: M3EButtonSize.sm,
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: MdSpacing.sm),

              // Search Bar with auto-focus for instant keyboard input
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(MdSpacing.radiusLg),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: MdSpacing.xs,
                  vertical: 2,
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Search or create tag\u2026',
                    hintStyle: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: scheme.primary,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MdSpacing.xs,
                      vertical: MdSpacing.xs,
                    ),
                  ),
                  onChanged: (val) => setState(() => _query = val),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty && !hasExactMatch) {
                      _createAndSelect(val);
                    }
                  },
                ),
              ),

              // Selected Tags Chip Strip (if any selected)
              if (_selected.isNotEmpty) ...[
                const SizedBox(height: MdSpacing.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tagName in _selected) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InputChip(
                            avatar: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: scheme.onPrimaryContainer,
                            ),
                            label: Text('#$tagName'),
                            labelStyle: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                            backgroundColor: scheme.primaryContainer,
                            deleteIcon: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: scheme.onPrimaryContainer,
                            ),
                            onDeleted: () => _toggleTag(tagName),
                            onPressed: () => _toggleTag(tagName),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: MdSpacing.xs),

              // Create Action Item (when search query doesn't match an existing tag)
              if (trimmedQuery.isNotEmpty && !hasExactMatch) ...[
                InkWell(
                  onTap: _isCreating
                      ? null
                      : () => _createAndSelect(trimmedQuery),
                  borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: MdSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MdSpacing.sm,
                      vertical: MdSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: _isCreating
                              ? Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.add_rounded,
                                  size: 20,
                                  color: scheme.onPrimary,
                                ),
                        ),
                        const SizedBox(width: MdSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create "#$trimmedQuery"',
                                style: textTheme.labelLarge?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Add as a new tag and select it',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Tag List
              Expanded(
                child: filteredTags.isEmpty
                    ? (trimmedQuery.isEmpty && allTags.isEmpty)
                          ? Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerLow,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.label_outline_rounded,
                                        size: 26,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: MdSpacing.xs),
                                    Text(
                                      'No tags yet',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Type above to create your first tag.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : (trimmedQuery.isNotEmpty && !hasExactMatch)
                          ? const SizedBox.shrink()
                          : Center(
                              child: Text(
                                'No tags matching "$trimmedQuery"',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                    : ListView.separated(
                        itemCount: filteredTags.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final tag = filteredTags[index];
                          final isSelected = _selected.contains(tag.name);
                          final count = widget.repository.getStickerCountForTag(
                            tag.name,
                          );

                          return InkWell(
                            onTap: () => _toggleTag(tag.name),
                            borderRadius: BorderRadius.circular(
                              MdSpacing.radiusMd,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: MdSpacing.sm,
                                vertical: MdSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? scheme.primaryContainer.withValues(
                                        alpha: 0.5,
                                      )
                                    : scheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(
                                  MdSpacing.radiusMd,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? scheme.primary.withValues(alpha: 0.4)
                                      : scheme.outlineVariant.withValues(
                                          alpha: 0.25,
                                        ),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? scheme.primary
                                          : scheme.surfaceContainerHigh,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? null
                                          : Border.all(
                                              color: scheme.outlineVariant,
                                              width: 1.5,
                                            ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: scheme.onPrimary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: MdSpacing.xs),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '#${tag.name}',
                                          style: textTheme.labelLarge?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? scheme.onSurface
                                                : scheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          count == 1
                                              ? '1 sticker'
                                              : '$count stickers',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
