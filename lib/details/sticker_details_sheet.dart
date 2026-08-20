import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';

import '../data/sticker.dart';
import '../data/sticker_repository.dart';
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
            width: 400,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(MdSpacing.extraLargeIncreased),
              ),
              child: SafeArea(
                child: _StickerDetailsBody(
                  sticker: sticker,
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
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MdSpacing.extraLargeIncreased),
      ),
    ),
    builder: (context) {
      return _StickerDetailsBody(sticker: sticker, repository: repository);
    },
  );
}

class _StickerDetailsBody extends StatelessWidget {
  const _StickerDetailsBody({
    required this.sticker,
    required this.repository,
  });

  final Sticker sticker;
  final StickerRepository repository;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateFormat.yMMMEd().format(sticker.createdAt);
    final time = DateFormat.jm().format(sticker.createdAt);
    final place = sticker.placeLabel ??
        (sticker.latitude != null && sticker.longitude != null
            ? '${sticker.latitude!.toStringAsFixed(4)}, ${sticker.longitude!.toStringAsFixed(4)}'
            : 'Place unknown');

    final rows = [
      ('Place', place, Icons.place_outlined),
      ('Date', date, Icons.calendar_today_outlined),
      ('Time', time, Icons.schedule_outlined),
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
          Text('Memory', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: MdSpacing.sm),
          M3ECardList(
            itemCount: rows.length,
            color: scheme.surfaceContainerLowest,
            haptic: M3EHapticFeedback.light,
            itemBuilder: (context, index) {
              final row = rows[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(row.$3, color: scheme.onSurfaceVariant),
                title: Text(row.$1, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(
                  row.$2,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: MdSpacing.md),
          Row(
            children: [
              Expanded(
                child: M3ETextButton(
                  size: M3EButtonSize.md,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: MdSpacing.xs),
              Expanded(
                child: M3EFilledButton.tonal(
                  size: M3EButtonSize.md,
                  onPressed: () => _confirmDelete(context),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MdSpacing.extraLarge),
          ),
          title: Text(
            'Peel this sticker off the board?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          content: Text(
            'This memory stays only on this device. Deleting removes the sticker file.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          actions: [
            M3ETextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            M3EFilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
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
