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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
          Row(
            children: [
              Icon(Icons.tune_rounded, color: scheme.primary),
              const SizedBox(width: MdSpacing.xs),
              Expanded(
                child: Text(
                  'Sticker Adjustments',
                  style: textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: MdSpacing.xs),
          Text(
            'Customize color adjustments for saving newly generated stickers. These enhancements take effect after subject cutout and vinyl backing are complete and do not alter previously created stickers.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: MdSpacing.md),

          // Saturation Card
          Container(
            padding: const EdgeInsets.all(MdSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(MdSpacing.sm),
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
                          Icons.palette_outlined,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: MdSpacing.xs),
                        Text(
                          'Saturation',
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MdSpacing.xs,
                        vertical: MdSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(MdSpacing.xxs),
                      ),
                      child: Text(
                        _formatAdjustment(_saturation),
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
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
              borderRadius: BorderRadius.circular(MdSpacing.sm),
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
                          Icons.wb_sunny_outlined,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: MdSpacing.xs),
                        Text(
                          'Brightness',
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MdSpacing.xs,
                        vertical: MdSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(MdSpacing.xxs),
                      ),
                      child: Text(
                        _formatAdjustment(_brightness),
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
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
                  size: M3EButtonSize.md,
                  onPressed: _reset,
                  child: const Text('Reset to default'),
                ),
              ),
              const SizedBox(width: MdSpacing.xs),
              Expanded(
                child: M3EFilledButton(
                  size: M3EButtonSize.lg,
                  onPressed: _save,
                  child: const Text('Save settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
