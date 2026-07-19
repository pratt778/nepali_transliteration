import 'package:flutter/material.dart';
import 'package:nepali_transliteration/src/keyboard/nepali_key_button.dart';
import 'package:nepali_transliteration/src/keyboard/nepali_key_grid.dart';
import 'package:nepali_transliteration/src/keyboard/nepali_keyboard_layout.dart';


/// On-screen Devanagari keyboard. Drives a [controller] whose field should be
/// `readOnly: true, showCursor: true` so the system keyboard never opens — every
/// key inserts its Unicode string at the cursor, and the text shaper combines
/// consonants with matras automatically (क + ि → कि).
class NepaliKeyboard extends StatefulWidget {
  const NepaliKeyboard({super.key, required this.controller, this.onDone});

  final TextEditingController controller;

  /// Optional "done" action — when provided, a ✓ key is shown.
  final VoidCallback? onDone;

  @override
  State<NepaliKeyboard> createState() => _NepaliKeyboardState();
}

enum _KbMode { consonants, vowels, numbers }

/// Keys that insert more than one Unicode code point as a single keypress
/// (conjuncts and the anusvara-vowel), longest first so a longer unit is
/// matched before a shorter one that happens to be its suffix.
final List<String> _atomicMultiCharKeys =
    [...kNepaliConsonants, ...kNepaliVowels].where((k) => k.length > 1).toList()
      ..sort((a, b) => b.length - a.length);

class _NepaliKeyboardState extends State<NepaliKeyboard> {
  _KbMode _mode = _KbMode.consonants;

  /// Inserts [s] at the cursor (or end if unfocused), replacing any selection.
  void _insert(String s) {
    final TextEditingValue v = widget.controller.value;
    final int start = v.selection.isValid ? v.selection.start : v.text.length;
    final int end = v.selection.isValid ? v.selection.end : v.text.length;
    widget.controller.value = v.copyWith(
      text: v.text.replaceRange(start, end, s),
      selection: TextSelection.collapsed(offset: start + s.length),
      composing: TextRange.empty,
    );
  }

  /// Deletes the selection, or the character(s) before the cursor. A conjunct
  /// key (क्ष, त्र, ज्ञ, अं) inserts multiple code points in one keypress, so
  /// if the text immediately before the cursor is one of those units, the
  /// whole unit is removed — otherwise a single keypress leaves a dangling
  /// half-glyph (e.g. क्ष → क् after removing only the trailing ष).
  void _backspace() {
    final TextEditingValue v = widget.controller.value;
    final int start = v.selection.isValid ? v.selection.start : v.text.length;
    final int end = v.selection.isValid ? v.selection.end : v.text.length;
    if (start != end) {
      widget.controller.value = v.copyWith(
        text: v.text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
      return;
    }
    if (start == 0) return;

    int deleteLen = 1;
    for (final String unit in _atomicMultiCharKeys) {
      if (start - unit.length >= 0 &&
          v.text.startsWith(unit, start - unit.length)) {
        deleteLen = unit.length;
        break;
      }
    }

    widget.controller.value = v.copyWith(
      text: v.text.replaceRange(start - deleteLen, start, ''),
      selection: TextSelection.collapsed(offset: start - deleteLen),
      composing: TextRange.empty,
    );
  }

  /// Matras render alone as floating marks — prefix a dotted circle for clarity.
  String _matraLabel(String m) => '◌$m';

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mode switches.
              Row(
                children: [
                  Expanded(
                    child: NepaliKeyButton(
                      label: 'क ख',
                      accent: _mode == _KbMode.consonants,
                      onTap: () => setState(() => _mode = _KbMode.consonants),
                    ),
                  ),
                  Expanded(
                    child: NepaliKeyButton(
                      label: 'अ आ',
                      accent: _mode == _KbMode.vowels,
                      onTap: () => setState(() => _mode = _KbMode.vowels),
                    ),
                  ),
                  Expanded(
                    child: NepaliKeyButton(
                      label: '१ २ ३',
                      accent: _mode == _KbMode.numbers,
                      onTap: () => setState(() => _mode = _KbMode.numbers),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),

              // Keys for the active mode.
              if (_mode == _KbMode.consonants) ...[
                NepaliKeyGrid(
                  keys: kNepaliCommonMatras,
                  perRow: 8,
                  display: _matraLabel,
                  onKey: _insert,
                ),
                const SizedBox(height: 2),
                NepaliKeyGrid(
                  keys: kNepaliConsonants,
                  perRow: 9,
                  onKey: _insert,
                ),
              ] else if (_mode == _KbMode.vowels) ...[
                NepaliKeyGrid(keys: kNepaliVowels, onKey: _insert),
                const SizedBox(height: 2),
                NepaliKeyGrid(
                  keys: kNepaliAllMatras,
                  perRow: 7,
                  display: _matraLabel,
                  onKey: _insert,
                ),
              ] else ...[
                NepaliKeyGrid(keys: kNepaliDigits, perRow: 10, onKey: _insert),
                const SizedBox(height: 2),
                NepaliKeyGrid(keys: kNepaliPunctuation, onKey: _insert),
              ],

              const SizedBox(height: 2),

              // Bottom block: punctuation + wide space on the left; backspace
              // stacked over the done (✓) key on the right, like Gboard.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: NepaliKeyButton(
                                label: '।',
                                onTap: () => _insert('।'),
                              ),
                            ),
                            Expanded(
                              child: NepaliKeyButton(
                                label: ',',
                                onTap: () => _insert(','),
                              ),
                            ),
                            Expanded(
                              child: NepaliKeyButton(
                                label: '.',
                                onTap: () => _insert('.'),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: NepaliKeyButton(
                                label: 'space',
                                onTap: () => _insert(' '),
                              ),
                            ),
                            Expanded(
                              child: NepaliKeyButton(
                                icon: Icons.keyboard_return,
                                accent: true,
                                onTap: () => _insert('\n'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NepaliKeyButton(
                          icon: Icons.backspace_outlined,
                          accent: true,
                          onTap: _backspace,
                        ),
                        if (widget.onDone != null)
                          NepaliKeyButton(
                            icon: Icons.check,
                            accent: true,
                            onTap: widget.onDone!,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
