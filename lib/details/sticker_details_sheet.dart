import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/sticker.dart';
import '../data/sticker_repository.dart';
import '../tags/tag_selection_sheet.dart';
import '../theme/spacing.dart';

Future<void> showStickerDetails({
  required BuildContext context,
  required Sticker sticker,
  required StickerRepository repository,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss sticker details',
      pageBuilder: (context, animation, secondary) {
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 420,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(MdSpacing.radiusXlIncreased),
              ),
              child: SafeArea(
                child: _StickerDetailsBody(
                  initialSticker: sticker,
                  repository: repository,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MdSpacing.radiusXlIncreased),
      ),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          child: _StickerDetailsBody(
            initialSticker: sticker,
            repository: repository,
          ),
        ),
      );
    },
  );
}

class _StickerDetailsBody extends StatelessWidget {
  const _StickerDetailsBody({
    required this.initialSticker,
    required this.repository,
  });

  final Sticker initialSticker;
  final StickerRepository repository;

  Future<void> _openInMaps(BuildContext context, Sticker sticker) async {
    final hasCoords = sticker.latitude != null && sticker.longitude != null;
    if (!hasCoords &&
        (sticker.placeLabel == null || sticker.placeLabel!.isEmpty)) {
      return;
    }

    final query = hasCoords
        ? '${sticker.latitude},${sticker.longitude}'
        : sticker.placeLabel!;
    final label = sticker.placeLabel ?? query;

    final uri = hasCoords
        ? Uri.parse(
            'geo:${sticker.latitude},${sticker.longitude}?q=${sticker.latitude},${sticker.longitude}(${Uri.encodeComponent(label)})',
          )
        : Uri.parse('geo:0,0?q=${Uri.encodeComponent(label)}');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        final fallback = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
        );
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _manageStickerTags(BuildContext context, Sticker sticker) async {
    final updated = await showTagSelectionSheet(
      context: context,
      repository: repository,
      initialSelectedTags: Set<String>.from(sticker.tags),
    );
    if (updated != null) {
      M3EHapticFeedback.medium.apply();
      await repository.setStickerTags(sticker.id, updated.toList());
    }
  }

  Future<void> _moveStickerBoard(BuildContext context, Sticker sticker) async {
    final boards = repository.boards;
    if (boards.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create another board first to move this sticker.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final selectedBoardId = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MdSpacing.radiusXl),
          ),
          title: Text(
            'Move to Board',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          children: [
            for (final b in boards)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, b.id),
                padding: const EdgeInsets.symmetric(
                  horizontal: MdSpacing.md,
                  vertical: MdSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      b.id == sticker.boardId
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: b.id == sticker.boardId
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    Expanded(
                      child: Text(
                        b.name,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: b.id == sticker.boardId
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: b.id == sticker.boardId
                              ? scheme.primary
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (selectedBoardId != null &&
        selectedBoardId != sticker.boardId &&
        context.mounted) {
      M3EHapticFeedback.medium.apply();
      await repository.moveStickerToBoard(sticker.id, selectedBoardId);
      final destName = boards.firstWhere((b) => b.id == selectedBoardId).name;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sticker moved to "$destName"'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final sticker =
            repository.allStickers
                .where((s) => s.id == initialSticker.id)
                .firstOrNull ??
            initialSticker;

        final currentBoard =
            repository.boards
                .where((b) => b.id == sticker.boardId)
                .firstOrNull ??
            repository.activeBoard;

        final date = DateFormat.yMMMEd().format(sticker.createdAt);
        final time = DateFormat.jm().format(sticker.createdAt);
        final hasLocation =
            sticker.latitude != null ||
            sticker.longitude != null ||
            (sticker.placeLabel != null && sticker.placeLabel!.isNotEmpty);

        final place =
            sticker.placeLabel ??
            (sticker.latitude != null && sticker.longitude != null
                ? '${sticker.latitude!.toStringAsFixed(4)}, ${sticker.longitude!.toStringAsFixed(4)}'
                : 'Location not recorded');

        final rows = [
          (
            'Board',
            currentBoard.name,
            Icons.dashboard_outlined,
            () => _moveStickerBoard(context, sticker),
          ),
          (
            'Place',
            place,
            Icons.place_rounded,
            hasLocation ? () => _openInMaps(context, sticker) : null,
          ),
          ('Date', date, Icons.calendar_today_rounded, null),
          ('Time', time, Icons.schedule_rounded, null),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            MdSpacing.sm,
            MdSpacing.xs,
            MdSpacing.sm,
            MdSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Sticker Thumbnail & Title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: File(sticker.imagePath).existsSync()
                        ? Image.file(
                            File(sticker.imagePath),
                            fit: BoxFit.contain,
                          )
                        : Icon(Icons.auto_awesome, color: scheme.primary),
                  ),
                  const SizedBox(width: MdSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Memory Details',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          date,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: MdSpacing.sm),

              // Expressive Card List for Metadata
              M3ECardList(
                itemCount: rows.length,
                color: scheme.surfaceContainerLowest,
                padding: const EdgeInsets.symmetric(
                  horizontal: MdSpacing.sm,
                  vertical: MdSpacing.xs,
                ),
                outerRadius: MdSpacing.radiusLg,
                innerRadius: MdSpacing.radiusXs,
                gap: 2.0,
                haptic: M3EHapticFeedback.light,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final onTap = row.$4;

                  Widget content = Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(
                              MdSpacing.radiusSm,
                            ),
                          ),
                          child: Icon(row.$3, size: 20, color: scheme.primary),
                        ),
                        const SizedBox(width: MdSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.$1,
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                row.$2,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: MdSpacing.xxs),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );

                  if (onTap != null) {
                    return InkWell(
                      onTap: () {
                        M3EHapticFeedback.light.apply();
                        onTap();
                      },
                      borderRadius: BorderRadius.circular(MdSpacing.radiusXs),
                      child: content,
                    );
                  }

                  return content;
                },
              ),

              const SizedBox(height: MdSpacing.xs),

              // Tags Section Card
              Container(
                padding: const EdgeInsets.all(MdSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(MdSpacing.radiusLg),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sell_outlined,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tags',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            M3EHapticFeedback.light.apply();
                            _manageStickerTags(context, sticker);
                          },
                          borderRadius: BorderRadius.circular(
                            MdSpacing.radiusFull,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MdSpacing.xs,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (sticker.tags.isEmpty)
                      Text(
                        'No tags assigned to this sticker.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final tag in sticker.tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MdSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(
                                  MdSpacing.radiusFull,
                                ),
                              ),
                              child: Text(
                                '#$tag',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: MdSpacing.md),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: M3ETextButton(
                      size: M3EButtonSize.sm,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: MdSpacing.xs),
                  Expanded(
                    child: M3EFilledButton.tonalIcon(
                      size: M3EButtonSize.sm,
                      decoration: M3EButtonDecoration(
                        backgroundColor: WidgetStatePropertyAll(
                          scheme.errorContainer.withValues(alpha: 0.7),
                        ),
                        foregroundColor: WidgetStatePropertyAll(
                          scheme.onErrorContainer,
                        ),
                      ),
                      onPressed: () {
                        M3EHapticFeedback.medium.apply();
                        _confirmDelete(context, sticker);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Sticker sticker) async {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MdSpacing.radiusXl),
          ),
          icon: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_forever_rounded,
              color: scheme.onErrorContainer,
              size: 26,
            ),
          ),
          title: Text(
            'Peel this sticker off?',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'This memory sticker exists only on this device. Deleting will permanently remove it from your scrapbook.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            M3ETextButton(
              size: M3EButtonSize.sm,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: MdSpacing.xs),
            M3EFilledButton.icon(
              size: M3EButtonSize.sm,
              decoration: M3EButtonDecoration(
                backgroundColor: WidgetStatePropertyAll(scheme.error),
                foregroundColor: WidgetStatePropertyAll(scheme.onError),
              ),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      await repository.delete(sticker.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
