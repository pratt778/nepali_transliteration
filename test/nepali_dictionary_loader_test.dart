import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_transliteration/nepali_transliteration.dart';

void main() {
  Future<void> pumpUntil(WidgetTester tester, Finder ready) async {
    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (ready.evaluate().isNotEmpty) return;
    }
  }

  testWidgets('shows a default spinner, then hands the ready dictionary to builder', (
    tester,
  ) async {
    // Pre-warm via a real event loop turn — the asset read is genuine file
    // I/O, which fake-async `pump()` alone can't service.
    await tester.runAsync(() => NepaliDictionary.load());

    int onReadyCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NepaliDictionaryLoader(
          onReady: (_) => onReadyCalls++,
          builder: (context, dictionary) =>
              Text('ready: ${dictionary.size} keys'),
        ),
      ),
    );

    // Before the asset resolves, the default loading UI is shown.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pumpUntil(tester, find.textContaining('ready:'));

    expect(find.textContaining('ready:'), findsOneWidget);
    expect(onReadyCalls, 1);

    // Rebuilding the tree (e.g. parent setState) must not re-fire onReady or
    // re-show the loading spinner — the same completed future is reused.
    await tester.pumpWidget(
      MaterialApp(
        home: NepaliDictionaryLoader(
          onReady: (_) => onReadyCalls++,
          builder: (context, dictionary) =>
              Text('ready: ${dictionary.size} keys'),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('ready:'), findsOneWidget);
  });

  testWidgets('custom loadingBuilder overrides the default spinner', (
    tester,
  ) async {
    await tester.runAsync(() => NepaliDictionary.load());

    await tester.pumpWidget(
      MaterialApp(
        home: NepaliDictionaryLoader(
          loadingBuilder: (context) => const Text('custom loading'),
          builder: (context, dictionary) => const Text('ready'),
        ),
      ),
    );

    expect(find.text('custom loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await pumpUntil(tester, find.text('ready'));
    expect(find.text('ready'), findsOneWidget);
  });
}
