import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/sticker.dart';

class StickerObject extends StatefulWidget {
  const StickerObject({
    super.key,
    required this.sticker,
    required this.selected,
    required this.dropping,
    required this.onTap,
    required this.onLongPress,
  });

  final Sticker sticker;
  final bool selected;
  final bool dropping;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<StickerObject> createState() => _StickerObjectState();
}

class _StickerObjectState extends State<StickerObject>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drop;
  StreamSubscription<AccelerometerEvent>? _tilt;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    _drop = AnimationController.unbounded(vsync: this, value: 1);
    if (widget.dropping) {
      _drop.value = 1.28;
      _drop.animateWith(
        SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: 180,
            ratio: 0.55,
          ),
          1.28,
          1,
          0,
        ),
      );
      M3EHapticFeedback.heavy.apply();
    }
    _tilt = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      setState(() {
        _tiltX = (event.y * 0.035).clamp(-0.18, 0.18);
        _tiltY = (-event.x * 0.035).clamp(-0.18, 0.18);
      });
    });
  }

  @override
  void dispose() {
    _tilt?.cancel();
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.sticker.imagePath);
    return AnimatedBuilder(
      animation: _drop,
      builder: (context, child) {
        final scale = _drop.value;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateX(_tiltX)
            ..rotateY(_tiltY),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          M3EHapticFeedback.light.apply();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        child: Semantics(
          button: true,
          label: 'Memory sticker',
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(3, 5),
                child: _StickerImage(
                  file: file,
                  width: 168,
                  filterQuality: FilterQuality.medium,
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.32),
                ),
              ),
              Transform.translate(
                offset: const Offset(1.4, 1.8),
                child: _StickerImage(
                  file: file,
                  width: 168,
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                ),
              ),
              _StickerImage(file: file, width: 168),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickerImage extends StatelessWidget {
  const _StickerImage({
    required this.file,
    required this.width,
    this.color,
    this.filterQuality = FilterQuality.high,
  });

  final File file;
  final double width;
  final Color? color;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      file,
      width: width,
      filterQuality: filterQuality,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width,
          height: width,
          child: Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.outline,
          ),
        );
      },
    );
  }
}

