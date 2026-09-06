import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';

import '../backup/backup_restore_service.dart';
import '../data/sticker_repository.dart';
import '../data/sticker_settings.dart';
import '../theme/app_haptics.dart';
import '../theme/spacing.dart';

Future<void> showStickerSettings({
  required BuildContext context,
  required StickerRepository repository,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss sticker settings',
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
                child: _StickerSettingsBody(repository: repository),
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
      return SafeArea(
        child: SingleChildScrollView(
          child: _StickerSettingsBody(repository: repository),
        ),
      );
    },
  );
}

class _StickerSettingsBody extends StatefulWidget {
  const _StickerSettingsBody({required this.repository});

  final StickerRepository repository;

  @override
  State<_StickerSettingsBody> createState() => _StickerSettingsBodyState();
}

class _StickerSettingsBodyState extends State<_StickerSettingsBody> {
  late double _saturation;
  late double _brightness;
  late bool _hapticFeedbackEnabled;

  @override
  void initState() {
    super.initState();
    _saturation = widget.repository.settings.saturation;
    _brightness = widget.repository.settings.brightness;
    _hapticFeedbackEnabled = widget.repository.settings.hapticFeedbackEnabled;
  }

  String _formatAdjustment(double value) {
    final diff = ((value - 1.0) * 100).round();
    if (diff == 0) return '100% (Default)';
    final sign = diff > 0 ? '+' : '';
    final percent = (value * 100).round();
    return '$percent% ($sign$diff%)';
  }

  void _reset() {
    AppHaptics.mediumImpact();
    setState(() {
      _saturation = 1.0;
      _brightness = 1.0;
      _hapticFeedbackEnabled = true;
    });
  }

  Future<void> _save() async {
    AppHaptics.mediumImpact();
    final updated = StickerSettings(
      saturation: _saturation,
      brightness: _brightness,
      hapticFeedbackEnabled: _hapticFeedbackEnabled,
    );
    await widget.repository.updateSettings(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _progressMessage;

  Future<void> _handleCreateBackup() async {
    if (_isBackingUp || _isRestoring) return;
    AppHaptics.mediumImpact();
    setState(() {
      _isBackingUp = true;
      _progressMessage = 'Creating backup...';
    });

    try {
      final backupFile = await BackupRestoreService.createBackup(
        repository: widget.repository,
        onProgress: (msg) {
          if (mounted) {
            setState(() => _progressMessage = msg);
          }
        },
      );

      if (!mounted) return;
      final sizeMb = (backupFile.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup created ($sizeMb MB). Sharing...'),
          duration: const Duration(seconds: 2),
        ),
      );

      await BackupRestoreService.shareBackup(backupFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _progressMessage = null;
        });
      }
    }
  }

  Future<void> _handleRestoreBackup() async {
    if (_isBackingUp || _isRestoring) return;
    AppHaptics.lightImpact();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      final zipFile = File(path);

      setState(() {
        _isRestoring = true;
        _progressMessage = 'Reading backup file...';
      });

      final metadata = await BackupRestoreService.inspectBackup(zipFile);

      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _progressMessage = null;
      });

      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final scheme = Theme.of(ctx).colorScheme;
          final dateStr =
              DateFormat.yMMMd().add_jm().format(metadata.createdAt.toLocal());
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('Restore Backup?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup contents:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text('• ${metadata.stickerCount} stickers'),
                if (metadata.boardCount > 0)
                  Text('• ${metadata.boardCount} boards'),
                Text('• Created: $dateStr'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: scheme.error.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '⚠️ Restoring will replace all current stickers, boards, and tags. This action cannot be undone.',
                    style: TextStyle(
                      color: scheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Restore & Replace'),
              ),
            ],
          );
        },
      );

      if (shouldRestore != true || !mounted) return;

      setState(() {
        _isRestoring = true;
        _progressMessage = 'Restoring database & stickers...';
      });

      await BackupRestoreService.restoreBackup(
        zipFile: zipFile,
        repository: widget.repository,
        onProgress: (msg) {
          if (mounted) {
            setState(() => _progressMessage = msg);
          }
        },
      );

      if (!mounted) return;
      AppHaptics.success();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restored successfully!'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore backup: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _progressMessage = null;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

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
                  Icons.tune_rounded,
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
                      'Sticker Adjustments',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Enhance vinyl color processing',
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
          const SizedBox(height: MdSpacing.xs),
          Text(
            'Fine-tune the appearance of newly generated stickers after subject cutout and vinyl backing.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: MdSpacing.sm),

          // Quick Preset Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Default (100%)'),
                  onPressed: () {
                    AppHaptics.lightImpact();
                    setState(() {
                      _saturation = 1.0;
                      _brightness = 1.0;
                    });
                  },
                ),
                const SizedBox(width: MdSpacing.xs),
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Vibrant (+30%)'),
                  onPressed: () {
                    AppHaptics.lightImpact();
                    setState(() {
                      _saturation = 1.3;
                      _brightness = 1.05;
                    });
                  },
                ),
                const SizedBox(width: MdSpacing.xs),
                ActionChip(
                  avatar: const Icon(Icons.wb_twilight_rounded, size: 16),
                  label: const Text('Moody Soft'),
                  onPressed: () {
                    AppHaptics.lightImpact();
                    setState(() {
                      _saturation = 0.85;
                      _brightness = 0.95;
                    });
                  },
                ),
                const SizedBox(width: MdSpacing.xs),
                ActionChip(
                  avatar: const Icon(Icons.filter_b_and_w_rounded, size: 16),
                  label: const Text('Monochrome'),
                  onPressed: () {
                    AppHaptics.lightImpact();
                    setState(() {
                      _saturation = 0.0;
                      _brightness = 1.0;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: MdSpacing.sm),

          // Saturation Card
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
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                          ),
                          child: Icon(
                            Icons.palette_rounded,
                            size: 18,
                            color: scheme.secondary,
                          ),
                        ),
                        const SizedBox(width: MdSpacing.xs),
                        Text(
                          'Saturation',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MdSpacing.xs,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(MdSpacing.radiusFull),
                      ),
                      child: Text(
                        _formatAdjustment(_saturation),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MdSpacing.xs),
                M3ESlider(
                  value: _saturation,
                  min: 0.0,
                  max: 2.0,
                  divisions: 40,
                  onChanged: (val) {
                    setState(() => _saturation = val);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Muted (0%)',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Natural (100%)',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Vibrant (200%)',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: MdSpacing.sm),

          // Brightness Card
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
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                          ),
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            size: 18,
                            color: scheme.secondary,
                          ),
                        ),
                        const SizedBox(width: MdSpacing.xs),
                        Text(
                          'Brightness',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MdSpacing.xs,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(MdSpacing.radiusFull),
                      ),
                      child: Text(
                        _formatAdjustment(_brightness),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MdSpacing.xs),
                M3ESlider(
                  value: _brightness,
                  min: 0.2,
                  max: 1.8,
                  divisions: 32,
                  onChanged: (val) {
                    setState(() => _brightness = val);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Darker (20%)',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Natural (100%)',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Brighter (180%)',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: MdSpacing.sm),

          // Haptic Feedback Card
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MdSpacing.sm,
              vertical: MdSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(MdSpacing.radiusLg),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                  ),
                  child: Icon(
                    Icons.vibration_rounded,
                    size: 20,
                    color: scheme.tertiary,
                  ),
                ),
                const SizedBox(width: MdSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Haptic Feedback',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Tactile vibrations on taps, snaps & actions',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _hapticFeedbackEnabled,
                  onChanged: (val) {
                    if (val) {
                      // Fire an immediate subtle feedback acknowledging enabling
                      AppHaptics.enabled = true;
                      AppHaptics.lightImpact();
                    } else {
                      AppHaptics.lightImpact();
                    }
                    setState(() => _hapticFeedbackEnabled = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: MdSpacing.sm),

          // Backup & Restore Card
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
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(MdSpacing.radiusSm),
                      ),
                      child: Icon(
                        Icons.cloud_sync_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup & Restore',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Full database, tags, boards & stickers',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MdSpacing.xs),
                Wrap(
                  spacing: MdSpacing.xs,
                  runSpacing: 4,
                  children: [
                    Chip(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.photo_library_outlined, size: 14),
                      label: Text('${widget.repository.allStickers.length} stickers'),
                    ),
                    Chip(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.dashboard_outlined, size: 14),
                      label: Text('${widget.repository.boards.length} boards'),
                    ),
                    Chip(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.label_outline_rounded, size: 14),
                      label: Text('${widget.repository.tags.length} tags'),
                    ),
                  ],
                ),
                if (_isBackingUp || _isRestoring) ...[
                  const SizedBox(height: MdSpacing.xs),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: MdSpacing.xs),
                      Expanded(
                        child: Text(
                          _progressMessage ?? 'Processing...',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: MdSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text('Restore'),
                        onPressed: (_isBackingUp || _isRestoring)
                            ? null
                            : _handleRestoreBackup,
                      ),
                    ),
                    const SizedBox(width: MdSpacing.xs),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.backup_rounded, size: 16),
                        label: const Text('Backup'),
                        onPressed: (_isBackingUp || _isRestoring)
                            ? null
                            : _handleCreateBackup,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: MdSpacing.md),

          // Actions
          Row(
            children: [
              Expanded(
                child: M3ETextButton(
                  size: M3EButtonSize.sm,
                  onPressed: _reset,
                  child: const Text('Reset to default'),
                ),
              ),
              const SizedBox(width: MdSpacing.xs),
              Expanded(
                child: M3EFilledButton.icon(
                  size: M3EButtonSize.sm,
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
