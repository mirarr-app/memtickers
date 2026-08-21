import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

import '../data/sticker_repository.dart';
import '../data/sticker_settings.dart';
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

  @override
  void initState() {
    super.initState();
    _saturation = widget.repository.settings.saturation;
    _brightness = widget.repository.settings.brightness;
  }

  String _formatAdjustment(double value) {
    final diff = ((value - 1.0) * 100).round();
    if (diff == 0) return '100% (Default)';
    final sign = diff > 0 ? '+' : '';
    final percent = (value * 100).round();
    return '$percent% ($sign$diff%)';
  }

  void _reset() {
    M3EHapticFeedback.medium.apply();
    setState(() {
      _saturation = 1.0;
      _brightness = 1.0;
    });
  }

  Future<void> _save() async {
    M3EHapticFeedback.medium.apply();
    final updated = StickerSettings(
      saturation: _saturation,
      brightness: _brightness,
    );
    await widget.repository.updateSettings(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sticker creation settings saved'),
        duration: Duration(seconds: 2),
      ),
    );
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
                    M3EHapticFeedback.light.apply();
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
                    M3EHapticFeedback.light.apply();
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
                    M3EHapticFeedback.light.apply();
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
                    M3EHapticFeedback.light.apply();
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
