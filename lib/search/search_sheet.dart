import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';

import '../data/sticker_repository.dart';
import '../theme/spacing.dart';
import 'sticker_search_filter.dart';

Future<StickerSearchFilter?> showStickerSearchSheet({
  required BuildContext context,
  required StickerRepository repository,
  StickerSearchFilter? initialFilter,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) {
    return showGeneralDialog<StickerSearchFilter?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss search',
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
                child: _SearchSheetBody(
                  repository: repository,
                  initialFilter: initialFilter,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<StickerSearchFilter?>(
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
            height: MediaQuery.sizeOf(context).height * 0.85,
            child: _SearchSheetBody(
              repository: repository,
              initialFilter: initialFilter,
            ),
          ),
        ),
      );
    },
  );
}

class _SearchSheetBody extends StatefulWidget {
  const _SearchSheetBody({required this.repository, this.initialFilter});

  final StickerRepository repository;
  final StickerSearchFilter? initialFilter;

  @override
  State<_SearchSheetBody> createState() => _SearchSheetBodyState();
}

class _SearchSheetBodyState extends State<_SearchSheetBody> {
  late final Set<String> _selectedTags;
  DateTimeRange? _dateRange;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _selectedTags = Set.from(widget.initialFilter?.tags ?? const []);
    _dateRange = widget.initialFilter?.dateRange;
    _locationController = TextEditingController(
      text: widget.initialFilter?.locationQuery ?? '',
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  StickerSearchFilter get _currentFilter => StickerSearchFilter(
    tags: _selectedTags.toList(),
    dateRange: _dateRange,
    locationQuery: _locationController.text.trim().isEmpty
        ? null
        : _locationController.text.trim(),
  );

  int get _matchingCount {
    final filter = _currentFilter;
    return widget.repository.stickers.where((s) => filter.matches(s)).length;
  }

  List<String> get _distinctLocations {
    final locs = <String>{};
    for (final sticker in widget.repository.stickers) {
      if (sticker.placeLabel != null && sticker.placeLabel!.trim().isNotEmpty) {
        locs.add(sticker.placeLabel!.trim());
      }
    }
    return locs.toList()..sort();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(2000);
    final lastDate = DateTime(now.year + 5);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              surfaceContainerHigh: theme.colorScheme.surface,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      M3EHapticFeedback.light.apply();
      setState(() => _dateRange = picked);
    }
  }

  void _clearAll() {
    M3EHapticFeedback.medium.apply();
    setState(() {
      _selectedTags.clear();
      _dateRange = null;
      _locationController.clear();
    });
  }

  void _applyAndClose() {
    M3EHapticFeedback.medium.apply();
    final filter = _currentFilter;
    Navigator.of(context).pop(filter.isEmpty ? null : filter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final allTags = widget.repository.tags;
    final matchCount = _matchingCount;
    final hasActiveFilters = _currentFilter.isNotEmpty;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MdSpacing.md,
            MdSpacing.xs,
            MdSpacing.sm,
            MdSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: MdSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Memories',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'Filter board by tags, date & location',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasActiveFilters)
                M3ETextButton(
                  size: M3EButtonSize.sm,
                  onPressed: _clearAll,
                  child: const Text('Reset'),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: MdSpacing.md,
              vertical: MdSpacing.sm,
            ),
            children: [
              // TAGS FILTER SECTION
              _SectionHeader(
                icon: Icons.label_outline_rounded,
                title: 'Tags',
                trailing: _selectedTags.isNotEmpty
                    ? Text(
                        '${_selectedTags.length} selected',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: MdSpacing.xxs),
              if (allTags.isEmpty)
                Container(
                  padding: const EdgeInsets.all(MdSpacing.sm),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                  ),
                  child: Text(
                    'No tags created yet. Create tags when capturing or viewing stickers.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: MdSpacing.xs,
                  runSpacing: MdSpacing.xxs,
                  children: allTags.map((tag) {
                    final selected = _selectedTags.contains(tag.name);
                    final count = widget.repository.getStickerCountForTag(
                      tag.name,
                    );
                    return FilterChip(
                      selected: selected,
                      avatar: selected
                          ? null
                          : const Icon(Icons.tag_rounded, size: 16),
                      label: Text('#${tag.name} ($count)'),
                      selectedColor: scheme.primaryContainer,
                      checkmarkColor: scheme.onPrimaryContainer,
                      labelStyle: TextStyle(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        M3EHapticFeedback.light.apply();
                        setState(() {
                          if (val) {
                            _selectedTags.add(tag.name);
                          } else {
                            _selectedTags.remove(tag.name);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: MdSpacing.md),

              // DATE RANGE FILTER SECTION
              _SectionHeader(
                icon: Icons.calendar_month_outlined,
                title: 'Date Range',
                trailing: _dateRange != null
                    ? InkWell(
                        onTap: () {
                          M3EHapticFeedback.light.apply();
                          setState(() => _dateRange = null);
                        },
                        borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            'Clear',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: MdSpacing.xxs),
              Material(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                child: InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MdSpacing.sm,
                      vertical: MdSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range_rounded,
                          color: _dateRange != null
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: MdSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dateRange != null
                                    ? '${dateFormat.format(_dateRange!.start)} – ${dateFormat.format(_dateRange!.end)}'
                                    : 'Any capture date',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: _dateRange != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: _dateRange != null
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              if (_dateRange == null)
                                Text(
                                  'Tap to choose start and end dates',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: MdSpacing.md),

              // LOCATION FILTER SECTION
              _SectionHeader(
                icon: Icons.place_outlined,
                title: 'Location',
                trailing: _locationController.text.isNotEmpty
                    ? InkWell(
                        onTap: () {
                          M3EHapticFeedback.light.apply();
                          setState(() => _locationController.clear());
                        },
                        borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            'Clear',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: MdSpacing.xxs),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'City, venue, address, or country...',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: _locationController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            setState(() => _locationController.clear());
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: scheme.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: MdSpacing.sm,
                    vertical: MdSpacing.sm,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              // Quick location suggestions
              if (_distinctLocations.isNotEmpty) ...[
                const SizedBox(height: MdSpacing.xs),
                Wrap(
                  spacing: MdSpacing.xxs,
                  runSpacing: MdSpacing.xxs,
                  children: _distinctLocations.take(6).map((loc) {
                    final isSelected = _locationController.text.trim() == loc;
                    return ActionChip(
                      avatar: const Icon(Icons.pin_drop_outlined, size: 14),
                      label: Text(
                        loc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: isSelected
                          ? scheme.primaryContainer
                          : scheme.surfaceContainer,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      onPressed: () {
                        M3EHapticFeedback.light.apply();
                        setState(() {
                          if (isSelected) {
                            _locationController.clear();
                          } else {
                            _locationController.text = loc;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),

        const Divider(height: 1),

        // Bottom Action Bar
        Padding(
          padding: const EdgeInsets.all(MdSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$matchCount ${matchCount == 1 ? 'sticker' : 'stickers'} found',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: matchCount > 0 ? scheme.primary : scheme.error,
                      ),
                    ),
                    Text(
                      hasActiveFilters
                          ? 'Showing matching cluster'
                          : 'Showing all stickers',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MdSpacing.sm),
              M3EFilledButton.icon(
                size: M3EButtonSize.md,
                onPressed: hasActiveFilters || widget.initialFilter != null
                    ? _applyAndClose
                    : null,
                icon: const Icon(Icons.filter_list_rounded, size: 20),
                label: const Text('View on Board'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: MdSpacing.xs),
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
