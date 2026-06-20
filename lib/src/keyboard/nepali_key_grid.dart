import 'package:flutter/material.dart';
import 'package:nepali_transliteration/src/keyboard/nepali_key_button.dart';

/// Lays out a list of character [keys] into rows of [perRow], each key an
/// [Expanded] [NepaliKeyButton] so widths fill the screen. [display] optionally
/// transforms the label (e.g. prefixing a dotted circle to a matra) while the
/// raw key string is still what gets inserted via [onKey].
class NepaliKeyGrid extends StatelessWidget {
  const NepaliKeyGrid({
    super.key,
    required this.keys,
    required this.onKey,
    this.perRow = 6,
    this.display,
  });

  final List<String> keys;
  final ValueChanged<String> onKey;
  final int perRow;
  final String Function(String key)? display;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];
    for (int i = 0; i < keys.length; i += perRow) {
      final int end = (i + perRow) > keys.length ? keys.length : i + perRow;
      final List<String> slice = keys.sublist(i, end);
      rows.add(
        Row(
          children: [
            for (final String k in slice)
              Expanded(
                child: NepaliKeyButton(
                  label: display?.call(k) ?? k,
                  onTap: () => onKey(k),
                ),
              ),
            // Pad a short final row so keys keep a consistent width.
            for (int p = slice.length; p < perRow; p++)
              const Expanded(child: SizedBox()),
          ],
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
