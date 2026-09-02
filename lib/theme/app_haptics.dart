import 'package:haptic_kit/haptic_kit.dart';

/// Centralized haptic feedback controller powered by `haptic_kit`.
///
/// Dispatches semantic, tasteful haptic vibrations (impact, notification, selection,
/// and custom waveforms) only when haptics are enabled by user settings.
class AppHaptics {
  AppHaptics._();

  /// Global toggle for haptic feedback. Initialized and synchronized with
  /// [StickerRepository.settings.hapticFeedbackEnabled].
  static bool enabled = true;

  /// Subtle tactile click for standard interactive taps:
  /// - buttons, icon buttons, chips, list rows, tabs.
  /// Uses a crisp, low-latency micro-waveform so it is universally felt
  /// on Android devices even when TOUCH vibration effects are suppressed.
  static Future<void> lightImpact() async {
    if (!enabled) return;
    try {
      await Vibration.vibrateWaveform(
        timings: const [
          Duration.zero,
          Duration(milliseconds: 18),
        ],
        amplitudes: const [0, 110],
      );
    } catch (_) {
      try {
        await Haptics.impact(HapticImpactStyle.light);
      } catch (_) {}
    }
  }

  /// Medium tactile pulse for deliberate, noticeable state changes:
  /// - toggling navigation lock, moving sticker boards, saving settings,
  ///   capture button press, shutter capture.
  static Future<void> mediumImpact() async {
    if (!enabled) return;
    try {
      await Vibration.vibrateWaveform(
        timings: const [
          Duration.zero,
          Duration(milliseconds: 32),
        ],
        amplitudes: const [0, 180],
      );
    } catch (_) {
      try {
        await Haptics.impact(HapticImpactStyle.medium);
      } catch (_) {}
    }
  }

  /// Heavy tactile thud for destructive or high-impact actions:
  /// - Thanos snap deletion, board deletion, clearing all filters.
  static Future<void> heavyImpact() async {
    if (!enabled) return;
    try {
      await Vibration.vibrateWaveform(
        timings: const [
          Duration.zero,
          Duration(milliseconds: 55),
        ],
        amplitudes: const [0, 255],
      );
    } catch (_) {
      try {
        await Haptics.impact(HapticImpactStyle.heavy);
      } catch (_) {}
    }
  }

  /// Delicate tick for selection controls:
  /// - slider value steps, switch toggling, tag selection checkboxes.
  static Future<void> selection() async {
    if (!enabled) return;
    try {
      await Vibration.vibrateWaveform(
        timings: const [
          Duration.zero,
          Duration(milliseconds: 12),
        ],
        amplitudes: const [0, 90],
      );
    } catch (_) {
      try {
        await Haptics.selection();
      } catch (_) {}
    }
  }

  /// Semantic notification feedback for success operations:
  /// - sticker saved and placed, board created.
  static Future<void> success() async {
    if (!enabled) return;
    try {
      await Haptics.notification(HapticNotificationStyle.success);
    } catch (_) {}
  }

  /// Semantic notification feedback for warnings or invalid inputs:
  /// - duplicate board name, duplicate tag name.
  static Future<void> warning() async {
    if (!enabled) return;
    try {
      await Haptics.notification(HapticNotificationStyle.warning);
    } catch (_) {}
  }

  /// Semantic notification feedback for errors:
  /// - camera capture failure, cutout failure.
  static Future<void> error() async {
    if (!enabled) return;
    try {
      await Haptics.notification(HapticNotificationStyle.error);
    } catch (_) {}
  }

  /// Predefined click effect (tick / click) when supported on Android.
  static Future<void> click() async {
    if (!enabled) return;
    try {
      await Vibration.playPredefined(PredefinedEffect.click);
    } catch (_) {
      await lightImpact();
    }
  }

  /// Tactile double-tick pulse for sticker snap & stick landing.
  static Future<void> stickerStick() async {
    if (!enabled) return;
    try {
      await HapticPattern.builder()
          .tap(intensity: 0.5, sharpness: 0.7)
          .pause(const Duration(milliseconds: 60))
          .tap(intensity: 0.85, sharpness: 0.9)
          .play();
    } catch (_) {
      await mediumImpact();
    }
  }

  /// Multi-pulse disintegrating rumble for Thanos snap sticker deletion.
  static Future<void> snapDisintegrate() async {
    if (!enabled) return;
    try {
      await Vibration.vibrateWaveform(
        timings: const [
          Duration.zero,
          Duration(milliseconds: 70),
          Duration(milliseconds: 50),
          Duration(milliseconds: 60),
          Duration(milliseconds: 50),
          Duration(milliseconds: 50),
          Duration(milliseconds: 70),
          Duration(milliseconds: 40),
        ],
        amplitudes: const [0, 180, 0, 140, 0, 90, 0, 40],
      );
    } catch (_) {
      await heavyImpact();
    }
  }
}
