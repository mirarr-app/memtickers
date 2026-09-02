import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

import '../data/sticker_repository.dart';
import '../data/sticker_tag.dart';
import '../theme/app_haptics.dart';
import '../theme/spacing.dart';

Future<void> showTagsSheet({
  required BuildContext context,
  required StickerRepository repository,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss tags',
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
              child: SafeArea(child: _TagsSheetBody(repository: repository)),
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
            child: _TagsSheetBody(repository: repository),
          ),
        ),
      );
    },
  );
}

class _TagsSheetBody extends StatefulWidget {
  const _TagsSheetBody({required this.repository});

  final StickerRepository repository;

  @override
  State<_TagsSheetBody> createState() => _TagsSheetBodyState();
}

class _TagsSheetBodyState extends State<_TagsSheetBody> {
  final _tagInputController = TextEditingController();
  final _tagFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addNewTag() async {
    final text = _tagInputController.text.trim();
    if (text.isEmpty) return;

    final existing = widget.repository.tags
        .where((t) => t.name.toLowerCase() == text.toLowerCase())
        .firstOrNull;

    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tag "$text" already exists.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      AppHaptics.success();
      await widget.repository.createTag(text);
      _tagInputController.clear();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _editTag(StickerTag tag) async {
    final controller = TextEditingController(text: tag.name);
    final count = widget.repository.getStickerCountForTag(tag.name);
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
            'Edit Tag',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count > 0
                    ? 'Renaming this tag will update $count sticker(s).'
                    : 'Enter the new name for this tag.',
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
                  labelText: 'Tag Name',
                  prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
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

    if (newName != null && newName.isNotEmpty && newName != tag.name) {
      final conflict = widget.repository.tags
          .where(
            (t) =>
                t.id != tag.id && t.name.toLowerCase() == newName.toLowerCase(),
          )
          .firstOrNull;
      if (conflict != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tag "$newName" already exists.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      AppHaptics.mediumImpact();
      await widget.repository.updateTag(tag.id, newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag renamed to "$newName"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteTag(StickerTag tag) async {
    final count = widget.repository.getStickerCountForTag(tag.name);
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
              Icons.delete_outline_rounded,
              color: scheme.onErrorContainer,
              size: 26,
            ),
          ),
          title: Text(
            'Delete Tag "${tag.name}"?',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Text(
            count > 0
                ? 'This will remove the tag from $count sticker(s). The stickers themselves will not be deleted.'
                : 'This will permanently delete this tag.',
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

    if (confirmed == true) {
      AppHaptics.heavyImpact();
      await widget.repository.deleteTag(tag.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "${tag.name}" deleted'),
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
        final tags = widget.repository.tags;

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
                          'Tags',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Organize and label your memories',
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

              // Create new tag input bar
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
                        controller: _tagInputController,
                        focusNode: _tagFocusNode,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'New tag name\u2026',
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.add_circle_outline_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: MdSpacing.xs,
                            vertical: MdSpacing.xs,
                          ),
                        ),
                        onSubmitted: (_) => _addNewTag(),
                      ),
                    ),
                    const SizedBox(width: MdSpacing.xxs),
                    M3EFilledButton.icon(
                      size: M3EButtonSize.sm,
                      onPressed: _isSubmitting ? null : _addNewTag,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MdSpacing.sm),

              // Tags List / Empty State
              Expanded(
                child: tags.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLow,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.label_off_outlined,
                                  size: 28,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: MdSpacing.xs),
                              Text(
                                'No tags created yet',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: MdSpacing.lg,
                                ),
                                child: Text(
                                  'Create tags to organize, search, and categorize your vinyl memory stickers.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: tags.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final tag = tags[index];
                          final count = widget.repository.getStickerCountForTag(
                            tag.name,
                          );

                          return Container(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(
                                MdSpacing.radiusMd,
                              ),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: MdSpacing.sm,
                              vertical: MdSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: MdSpacing.xs,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer.withValues(
                                      alpha: 0.6,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      MdSpacing.radiusFull,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.tag_rounded,
                                        size: 14,
                                        color: scheme.onSecondaryContainer,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        tag.name,
                                        style: textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: MdSpacing.xs),
                                Expanded(
                                  child: Text(
                                    count == 1
                                        ? '1 sticker'
                                        : '$count stickers',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit tag',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(6),
                                    minimumSize: const Size(32, 32),
                                  ),
                                  onPressed: () {
                                    AppHaptics.lightImpact();
                                    _editTag(tag);
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete tag',
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
                                    AppHaptics.lightImpact();
                                    _deleteTag(tag);
                                  },
                                ),
                              ],
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
