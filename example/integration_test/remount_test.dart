// End-to-end regression test for issue #2:
// "M3View is not safe to unmount/remount — M3AppEngine.dispose() leaves the
//  singleton unusable".
//
// This must run as an integration test on a real device (e.g. -d windows),
// because M3View drives the real flutter_angle / GL context: it cannot be
// mounted under a headless `flutter test`. The bug only manifests once the
// engine has actually initialised, so a widget test would never reach it.
//
// Run:  flutter test integration_test/remount_test.dart -d windows
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:macbear_3d/macbear_3d.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A minimal host that shows or hides the real M3View, so the test can force
  // the widget to mount, unmount, and remount within a single process.
  Widget harness({required bool showView}) {
    return MaterialApp(home: Scaffold(body: showView ? const M3View() : const SizedBox.expand()));
  }

  testWidgets('M3View survives unmount -> remount without disposing the engine (issue #2)', (
    WidgetTester tester,
  ) async {
    final engine = M3AppEngine.instance;

    // Signals first-time engine initialisation (onDidInit runs once, after
    // _didInit flips true inside initApp).
    final initialized = Completer<void>();
    engine.onDidInit = () async {
      if (!initialized.isCompleted) initialized.complete();
    };

    // --- 1. First mount: the engine initialises the ANGLE context. ---
    await tester.pumpWidget(harness(showView: true));
    await _pumpUntil(tester, () => initialized.isCompleted, timeout: const Duration(seconds: 30));
    expect(initialized.isCompleted, isTrue, reason: 'engine should initialise on the first M3View mount');

    // --- 2. Unmount the M3View (disposes _M3ViewState). ---
    await tester.pumpWidget(harness(showView: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull, reason: 'unmounting M3View must not throw');

    // --- 3. Core regression assertion. ---
    // Before the fix, _M3ViewState.dispose() called M3AppEngine.dispose(),
    // which disposed the ChangeNotifier; any later notifyListeners() (here via
    // refresh()) then throws "used after being disposed". With the fix the
    // view calls unmount(), which keeps the singleton engine alive.
    expect(() => engine.refresh(), returnsNormally, reason: 'unmounting M3View must NOT dispose the singleton engine');

    // --- 4. Remount a fresh M3View. ---
    await tester.pumpWidget(harness(showView: true));
    await _pumpUntil(tester, () => find.byType(Texture).evaluate().isNotEmpty, timeout: const Duration(seconds: 15));

    // A live Texture (not the "Macbear 3D" placeholder that getAppWidget()
    // returns while !_didInit) means the engine stayed initialised and the
    // remounted view is presenting GL output again.
    expect(find.byType(Texture), findsOneWidget, reason: 'remounted M3View should present the engine texture');
    expect(find.text('Macbear 3D'), findsNothing, reason: 'remounted M3View should not fall back to the placeholder');

    // Let the render loop run a little so any post-remount GL fault (ticker
    // driving a torn-down render engine) has a chance to surface.
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'the render loop must stay healthy after remount');
  });
}

/// Pumps real frames until [condition] holds or [timeout] elapses.
///
/// The engine ticker advances in real time under the live integration binding,
/// so we interleave [WidgetTester.pump] with a real delay to let GL work land.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 50),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout && !condition()) {
    await tester.pump(step);
    await Future<void>.delayed(step);
  }
}
