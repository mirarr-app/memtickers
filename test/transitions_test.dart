import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memtickers/capture/capture_page.dart';
import 'package:memtickers/theme/memtickers_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ExpressivePageRoute pushes with scale and fade transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      ExpressivePageRoute(
                        builder: (ctx) => const Scaffold(
                          body: Center(child: Text('Target Page')),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Target Page'), findsNothing);

    // Tap Open to trigger ExpressivePageRoute
    await tester.tap(find.text('Open'));
    await tester.pump(); // Start transition

    // Mid-transition: both pages are present, target is fading and scaling in
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Target Page'), findsOneWidget);
    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(ScaleTransition), findsWidgets);

    // Finish transition
    await tester.pumpAndSettle();
    expect(find.text('Target Page'), findsOneWidget);
  });

  test('SafeInterval clamps out-of-range values without assertion error', () {
    const safeInterval = SafeInterval(0.2, 0.8, curve: Curves.easeOutCubic);

    // Below 0
    expect(safeInterval.transform(-0.5), equals(0.0));
    expect(safeInterval.transform(0.0), equals(0.0));
    expect(safeInterval.transform(0.1), equals(0.0));

    // Inside range
    final mid = safeInterval.transform(0.5);
    expect(mid > 0.0 && mid < 1.0, isTrue);

    // Above 1 (e.g. overshooting curve like 1.0008037616405636)
    expect(safeInterval.transform(0.9), equals(1.0));
    expect(safeInterval.transform(1.0), equals(1.0));
    expect(safeInterval.transform(1.0008037616405636), equals(1.0));
    expect(safeInterval.transform(2.5), equals(1.0));
  });

  testWidgets('AnimatedSwitcher handles viewport transition without assertion', (
    tester,
  ) async {
    final phaseNotifier = ValueNotifier<String>('camera');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: phaseNotifier,
            builder: (context, phase, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.linear,
                switchOutCurve: Curves.linear,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: const SafeInterval(0.0, 0.70,
                          curve: Curves.easeOutCubic),
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey(phase),
                  child: Text('Phase: $phase'),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Phase: camera'), findsOneWidget);

    // Switch to processing
    phaseNotifier.value = 'processing';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('Phase: processing'), findsOneWidget);

    // Switch to preview
    phaseNotifier.value = 'preview';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Phase: preview'), findsOneWidget);
  });
}

