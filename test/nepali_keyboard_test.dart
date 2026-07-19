import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_transliteration/nepali_transliteration.dart';

void main() {
  Future<TextEditingController> pump(
    WidgetTester tester, {
    VoidCallback? onDone,
  }) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NepaliKeyboard(controller: controller, onDone: onDone),
        ),
      ),
    );
    return controller;
  }

  group('NepaliKeyboard backspace', () {
    testWidgets('removes a whole conjunct key in one press', (tester) async {
      final controller = await pump(tester);

      await tester.tap(find.text('क्ष'));
      await tester.pump();
      expect(controller.text, 'क्ष');

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(controller.text, ''); // not the dangling 'क्' half-glyph
    });

    testWidgets('still removes a single ordinary character', (tester) async {
      final controller = await pump(tester);

      await tester.tap(find.text('क'));
      await tester.pump();
      expect(controller.text, 'क');

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(controller.text, '');
    });
  });

  group('NepaliKeyboard newline key', () {
    testWidgets('inserts a newline character', (tester) async {
      final controller = await pump(tester);

      await tester.tap(find.text('क'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pump();

      expect(controller.text, 'क\n');
    });
  });
}
