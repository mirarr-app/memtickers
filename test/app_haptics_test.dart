import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/theme/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppHaptics', () {
    setUp(() {
      AppHaptics.enabled = true;
    });

    test('enabled flag controls feedback execution', () {
      expect(AppHaptics.enabled, true);
      AppHaptics.enabled = false;
      expect(AppHaptics.enabled, false);
      AppHaptics.enabled = true;
      expect(AppHaptics.enabled, true);
    });

    test('all haptic methods execute gracefully without unhandled exceptions', () async {
      // With enabled = true
      AppHaptics.enabled = true;
      await expectLater(AppHaptics.lightImpact(), completes);
      await expectLater(AppHaptics.mediumImpact(), completes);
      await expectLater(AppHaptics.heavyImpact(), completes);
      await expectLater(AppHaptics.selection(), completes);
      await expectLater(AppHaptics.success(), completes);
      await expectLater(AppHaptics.warning(), completes);
      await expectLater(AppHaptics.error(), completes);
      await expectLater(AppHaptics.click(), completes);
      await expectLater(AppHaptics.stickerStick(), completes);
      await expectLater(AppHaptics.snapDisintegrate(), completes);

      // With enabled = false (bypasses native calls)
      AppHaptics.enabled = false;
      await expectLater(AppHaptics.lightImpact(), completes);
      await expectLater(AppHaptics.mediumImpact(), completes);
      await expectLater(AppHaptics.heavyImpact(), completes);
      await expectLater(AppHaptics.selection(), completes);
      await expectLater(AppHaptics.success(), completes);
      await expectLater(AppHaptics.warning(), completes);
      await expectLater(AppHaptics.error(), completes);
      await expectLater(AppHaptics.click(), completes);
      await expectLater(AppHaptics.stickerStick(), completes);
      await expectLater(AppHaptics.snapDisintegrate(), completes);
    });
  });
}
