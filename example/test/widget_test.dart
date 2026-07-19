// Exercises the demo's "learned corrections" flow end-to-end: type a word,
// pick a suggestion other than the top one, and confirm the app both
// remembers it (ranks it first on the next lookup) and reflects that in the
// UI (snackbar + saved-count label).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_transliteration/nepali_transliteration.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nepali_transliteration_example/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Pumps in bounded steps instead of [WidgetTester.pumpAndSettle] — the
  /// loading screen's [CircularProgressIndicator] animates indefinitely, so
  /// pumpAndSettle would never consider the tree "settled".
  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
  }

  testWidgets('picking a non-top suggestion is learned and persisted', (
    tester,
  ) async {
    // Pre-warm the dictionary singleton via a real event loop turn — the
    // asset read is genuine file I/O, which fake-async `pump()` alone can't
    // service.
    await tester.runAsync(() => NepaliDictionary.load());

    await tester.pumpWidget(const MyApp());
    await pumpUntilLoaded(tester); // dictionary (cached) + prefs load

    expect(find.textContaining('learned correction'), findsOneWidget);
    expect(find.text('0 learned corrections saved'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'kathmandu');
    await tester.pump();

    // Dictionary hit ranks first; phonetic fallback is the second chip.
    expect(find.widgetWithText(ActionChip, 'काठमाडौं'), findsOneWidget);
    final Finder fallbackChip = find.widgetWithText(ActionChip, 'कथ्मन्दु');
    expect(fallbackChip, findsOneWidget);

    // The chip sits in a horizontally-scrolling ListView, which is prone to
    // off-viewport hit-test flakiness under the default test surface size.
    // Invoking the widget's own onPressed exercises the exact same
    // production callback (_selectCandidate) without depending on
    // coordinate-based hit-testing.
    tester.widget<ActionChip>(fallbackChip).onPressed!();
    await tester.pump(); // shows the snackbar
    expect(find.textContaining('Learned: "kathmandu"'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3)); // let the snackbar dismiss
    expect(find.text('1 learned correction saved'), findsOneWidget);

    // The correction is live immediately, through the same singleton the
    // widget itself calls into.
    expect(NepaliDictionary.instance.candidates('kathmandu').first, 'कथ्मन्दु');

    // Reset clears it back out and updates the UI + underlying dictionary.
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Reset'))
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // let its snackbar dismiss
    expect(find.text('0 learned corrections saved'), findsOneWidget);
    expect(
      NepaliDictionary.instance.candidates('kathmandu').first,
      isNot('कथ्मन्दु'),
    );
  });
}
