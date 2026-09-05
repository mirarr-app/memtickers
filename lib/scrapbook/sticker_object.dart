import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/sticker.dart';
import '../theme/app_haptics.dart';
import 'in_place_snappable.dart';

/// Scope providing shared accelerometer tilt state to stickers on the canvas.
class StickerTiltScope extends InheritedWidget {
  const StickerTiltScope({
    super.key,
    required this.tiltNotifier,
    required super.child,
  });

  final ValueListenable<Offset> tiltNotifier;

  static ValueListenable<Offset>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<StickerTiltScope>()
        ?.tiltNotifier;
  }

  @override
  bool updateShouldNotify(covariant StickerTiltScope oldWidget) {
    return tiltNotifier != oldWidget.tiltNotifier;
  }
}

class StickerObject extends StatefulWidget {
  const StickerObject({
    super.key,
    required this.sticker,
    required this.selected,
    required this.dropping,
    this.snapping = false,
    this.tiltNotifier,
    required this.onTap,
    required this.onLongPress,
  });

  final Sticker sticker;
  final bool selected;
  final bool dropping;
  final bool snapping;
  final ValueListenable<Offset>? tiltNotifier;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<StickerObject> createState() => _StickerObjectState();
}

class _StickerObjectState extends State<StickerObject>
    with TickerProviderStateMixin {
  late final AnimationController _stickController;
  late final AnimationController _snapController;
  bool _impactHapticFired = false;

  @override
  void initState() {
    super.initState();
    _stickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _stickController.addListener(() {
      if (_stickController.value >= 0.50 && !_impactHapticFired) {
        _impactHapticFired = true;
        AppHaptics.stickerStick();
      }
    });

    if (widget.dropping) {
      _startSticking();
    } else {
      _stickController.value = 1.0;
    }

    if (widget.snapping) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.snapping) {
          _snapController.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant StickerObject oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.dropping && widget.dropping) {
      _startSticking();
    }
    if (!oldWidget.snapping && widget.snapping) {
      _snapController.forward(from: 0.0);
    }
  }

  void _startSticking() {
    _impactHapticFired = false;
    AppHaptics.lightImpact();
    _stickController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _stickController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.sticker.imagePath);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final effectiveTiltNotifier =
        widget.tiltNotifier ?? StickerTiltScope.maybeOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.snapping
          ? null
          : () {
              AppHaptics.lightImpact();
              widget.onTap();
            },
      onLongPress: widget.snapping ? null : widget.onLongPress,
      child: InPlaceSnappable(
        animation: _snapController,
        outerPadding: const EdgeInsets.fromLTRB(200, 320, 200, 100),
        particleLifetime: 0.65,
        fadeOutDuration: 0.35,
        particleSpeed: 1.1,
        relativeParticleSize: 0.015,
        child: AnimatedBuilder(
          animation: effectiveTiltNotifier != null
              ? Listenable.merge([_stickController, effectiveTiltNotifier])
              : _stickController,
          builder: (context, child) {
            final t = _stickController.value;
            final isAnimating = _stickController.isAnimating || t < 1.0;
            final tilt = effectiveTiltNotifier?.value ?? Offset.zero;
            final tiltX = tilt.dx;
            final tiltY = tilt.dy;

            // 1. Scale & Squash-and-Stretch calculation
            double scaleX = 1.0;
            double scaleY = 1.0;
            if (isAnimating) {
              if (t <= 0.50) {
                // Swooping down and accelerating from lifted floating scale to board
                final p = Curves.easeInCubic.transform(t / 0.50);
                final s = 1.34 - (1.34 - 0.94) * p;
                scaleX = s;
                scaleY = s;
              } else if (t <= 0.72) {
                // Impact squash & spring rebound
                final p = Curves.easeOutBack.transform((t - 0.50) / 0.22);
                scaleX = 0.94 + (1.05 - 0.94) * p;
                scaleY = 0.94 + (1.03 - 0.94) * p;
              } else if (t <= 0.88) {
                // Secondary rebound
                final p = Curves.easeInOut.transform((t - 0.72) / 0.16);
                scaleX = 1.05 - (1.05 - 0.99) * p;
                scaleY = 1.03 - (1.03 - 0.99) * p;
              } else {
                // Settle to resting scale
                final p = Curves.easeOut.transform((t - 0.88) / 0.12);
                scaleX = 0.99 + (1.0 - 0.99) * p;
                scaleY = 0.99 + (1.0 - 0.99) * p;
              }
            }

            // 2. 3D Peel Roll / Angle calculation
            double rotX = tiltX;
            double rotY = tiltY;
            double rotZ = 0.0;
            if (isAnimating && t < 0.54) {
              final p = Curves.easeInQuad.transform((t / 0.54).clamp(0.0, 1.0));
              final lift = 1.0 - p;
              rotX = lift * 0.38 + tiltX;
              rotY = lift * -0.28 + tiltY;
              rotZ = lift * 0.08;
            }

            // 3. Dynamic Shadow Transition
            Offset shadowOffset = const Offset(3, 5);
            double shadowScale = 1.0;
            double shadowAlpha = 0.32;
            if (isAnimating && t < 0.50) {
              final p = Curves.easeInCubic.transform(t / 0.50);
              shadowOffset =
                  Offset.lerp(const Offset(16, 28), const Offset(3, 5), p)!;
              shadowScale = 1.22 - 0.22 * p;
              shadowAlpha = 0.16 + 0.16 * p;
            }

            // 4. Gloss Sheen Sweep (Active between 0.44 and 0.94)
            double sheenProgress = -1.0;
            if (isAnimating && t >= 0.44 && t <= 0.94) {
              sheenProgress = (t - 0.44) / 0.50;
            }

            // 5. Adhesive Impact Shockwave Burst (Active between 0.50 and 1.0)
            double impactProgress = -1.0;
            if (isAnimating && t >= 0.50) {
              impactProgress = (t - 0.50) / 0.50;
            }

            Widget imageWidget = _StickerImage(file: file, width: 168);
            if (sheenProgress >= 0.0) {
              imageWidget = ShaderMask(
                shaderCallback: (bounds) {
                  final sweepPos = -2.5 + sheenProgress * 5.0;
                  return LinearGradient(
                    begin: Alignment(sweepPos - 0.7, sweepPos - 0.7),
                    end: Alignment(sweepPos + 0.7, sweepPos + 0.7),
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.25),
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.25),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: imageWidget,
              );
            }

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..rotateX(rotX)
                ..rotateY(rotY)
                ..rotateZ(rotZ),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scaleByDouble(scaleX, scaleY, 1.0, 1.0),
                child: Semantics(
                  button: true,
                  label: 'Memory sticker',
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Adhesive impact ring & sparkle particles
                      if (impactProgress >= 0.0)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _AdhesiveImpactPainter(
                              progress: impactProgress,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      // Dynamic Cast Shadow (optimized single transform and FilterQuality.low)
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..translateByDouble(
                            shadowOffset.dx,
                            shadowOffset.dy,
                            0,
                            1,
                          )
                          ..scaleByDouble(shadowScale, shadowScale, 1.0, 1.0),
                        child: _StickerImage(
                          file: file,
                          width: 168,
                          filterQuality: FilterQuality.low,
                          color: scheme.shadow.withValues(alpha: shadowAlpha),
                        ),
                      ),
                      // Main Sticker with Gloss Sheen (Redundant white border removed)
                      imageWidget,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdhesiveImpactPainter extends CustomPainter {
  const _AdhesiveImpactPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;

    final eased = Curves.easeOutCubic.transform(progress);
    final alpha = ((1.0 - progress) * 0.45).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.8 * (1.0 - progress)).clamp(0.5, 2.8);

    final expansion = 6.0 + 24.0 * eased;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width + expansion * 2,
      height: size.height + expansion * 2,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(20.0 + expansion * 0.4),
    );
    canvas.drawRRect(rrect, paint);

    // Corner sparkle bursts
    final dotPaint = Paint()
      ..color = color.withValues(alpha: alpha * 1.3)
      ..style = PaintingStyle.fill;
    final dotDist = expansion * 1.15;
    final dotSize = (3.2 * (1.0 - eased)).clamp(0.5, 3.2);

    final corners = [
      rect.topLeft + Offset(-dotDist * 0.18, -dotDist * 0.18),
      rect.topRight + Offset(dotDist * 0.18, -dotDist * 0.18),
      rect.bottomLeft + Offset(-dotDist * 0.18, dotDist * 0.18),
      rect.bottomRight + Offset(dotDist * 0.18, dotDist * 0.18),
    ];

    for (final c in corners) {
      canvas.drawCircle(c, dotSize, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AdhesiveImpactPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
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
      height: width,
      cacheWidth: (width * 2).round(),
      cacheHeight: (width * 2).round(),
      fit: BoxFit.contain,
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
