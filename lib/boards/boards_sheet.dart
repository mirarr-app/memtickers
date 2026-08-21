import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

import '../data/sticker_board.dart';
import '../data/sticker_repository.dart';
import '../theme/spacing.dart';

Future<void> showBoardsSheet({
  required BuildContext context,
  required StickerRepository repository,
  ValueChanged<StickerBoard>? onBoardSelected,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss boards',
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
                child: _BoardsSheetBody(
                  repository: repository,
                  onBoardSelected: onBoardSelected,
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
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: _BoardsSheetBody(
              repository: repository,
              onBoardSelected: onBoardSelected,
            ),
          ),
        ),
      );
    },
  );
}

class _BoardsSheetBody extends StatefulWidget {
  const _BoardsSheetBody({required this.repository, this.onBoardSelected});

  final StickerRepository repository;
  final ValueChanged<StickerBoard>? onBoardSelected;

  @override
  State<_BoardsSheetBody> createState() => _BoardsSheetBodyState();
}

class _BoardsSheetBodyState extends State<_BoardsSheetBody> {
  final _boardInputController = TextEditingController();
  final _boardFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _boardInputController.dispose();
    _boardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addNewBoard() async {
    final text = _boardInputController.text.trim();
    if (text.isEmpty) return;

    final existing = widget.repository.boards
        .where((b) => b.name.toLowerCase() == text.toLowerCase())
        .firstOrNull;

    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Board "$text" already exists.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      M3EHapticFeedback.medium.apply();
      final newBoard = await widget.repository.createBoard(text);
      _boardInputController.clear();
      _boardFocusNode.unfocus();
      widget.onBoardSelected?.call(newBoard);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Board "$text" created and selected.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _editBoard(StickerBoard board) async {
    final controller = TextEditingController(text: board.name);
    final count = widget.repository.getStickerCountForBoard(board.id);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MdSpacing.radiusXl),
          ),
          icon: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_rounded,
              color: scheme.onPrimaryContainer,
              size: 22,
            ),
          ),
          title: Text(
            'Edit Board Name',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rename this board ($count sticker${count == 1 ? '' : 's'}).',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: MdSpacing.sm),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Board Name',
                  prefixIcon: const Icon(Icons.dashboard_outlined, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerLowest,
                ),
                onSubmitted: (value) => Navigator.pop(context, value.trim()),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            M3ETextButton(
              size: M3EButtonSize.sm,
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: MdSpacing.xs),
            M3EFilledButton.icon(
              size: M3EButtonSize.sm,
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != board.name) {
      final conflict = widget.repository.boards
          .where(
            (b) =>
                b.id != board.id &&
                b.name.toLowerCase() == newName.toLowerCase(),
          )
          .firstOrNull;
      if (conflict != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Board "$newName" already exists.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      M3EHapticFeedback.medium.apply();
      await widget.repository.updateBoard(board.id, newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Board renamed to "$newName"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteBoard(StickerBoard board) async {
    if (widget.repository.boards.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your only remaining board.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final count = widget.repository.getStickerCountForBoard(board.id);
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
              Icons.delete_sweep_rounded,
              color: scheme.onErrorContainer,
              size: 26,
            ),
          ),
          title: Text(
            'Delete Board "${board.name}"?',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Text(
            count > 0
                ? 'This will permanently delete this board and its $count sticker${count == 1 ? '' : 's'}. This cannot be undone.'
                : 'This will permanently delete this board.',
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
              label: const Text('Delete Board'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      M3EHapticFeedback.heavy.apply();
      await widget.repository.deleteBoard(board.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Board "${board.name}" deleted'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final boards = widget.repository.boards;
        final activeId = widget.repository.activeBoardId;

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
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                    ),
                    child: Icon(
                      Icons.dashboard_customize_rounded,
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
                          'Boards',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Switch between or create separate scrapbooks',
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

              // Create new board input bar
              Container(
                padding: const EdgeInsets.all(MdSpacing.xs),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(MdSpacing.radiusLg),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _boardInputController,
                        focusNode: _boardFocusNode,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'New board name…',
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.add_to_photos_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: MdSpacing.xs,
                            vertical: MdSpacing.xs,
                          ),
                        ),
                        onSubmitted: (_) => _addNewBoard(),
                      ),
                    ),
                    const SizedBox(width: MdSpacing.xxs),
                    M3EFilledButton.icon(
                      size: M3EButtonSize.sm,
                      onPressed: _isSubmitting ? null : _addNewBoard,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MdSpacing.sm),

              // Boards List
              Expanded(
                child: ListView.separated(
                  itemCount: boards.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final board = boards[index];
                    final isActive = board.id == activeId;
                    final count = widget.repository.getStickerCountForBoard(
                      board.id,
                    );

                    return Material(
                      color: isActive
                          ? scheme.primaryContainer.withValues(alpha: 0.45)
                          : scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(MdSpacing.radiusMd),
                        onTap: () {
                          M3EHapticFeedback.medium.apply();
                          widget.repository.setActiveBoard(board.id);
                          widget.onBoardSelected?.call(board);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              MdSpacing.radiusMd,
                            ),
                            border: Border.all(
                              color: isActive
                                  ? scheme.primary.withValues(alpha: 0.6)
                                  : scheme.outlineVariant.withValues(
                                      alpha: 0.25,
                                    ),
                              width: isActive ? 1.5 : 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: MdSpacing.sm,
                            vertical: MdSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? scheme.primary
                                      : scheme.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.check_rounded
                                      : Icons.dashboard_outlined,
                                  size: 18,
                                  color: isActive
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: MdSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            board.name,
                                            style: textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: isActive
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  color: isActive
                                                      ? scheme.primary
                                                      : scheme.onSurface,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isActive) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    MdSpacing.radiusFull,
                                                  ),
                                            ),
                                            child: Text(
                                              'ACTIVE',
                                              style: textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: scheme.onPrimary,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      count == 1
                                          ? '1 memory sticker'
                                          : '$count memory stickers',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit board name',
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(32, 32),
                                ),
                                onPressed: () {
                                  M3EHapticFeedback.light.apply();
                                  _editBoard(board);
                                },
                              ),
                              if (boards.length > 1)
                                IconButton(
                                  tooltip: 'Delete board',
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: scheme.error,
                                  ),
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(6),
                                    minimumSize: const Size(32, 32),
                                  ),
                                  onPressed: () {
                                    M3EHapticFeedback.light.apply();
                                    _deleteBoard(board);
                                  },
                                ),
                            ],
                          ),
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
