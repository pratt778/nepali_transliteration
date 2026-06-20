// ─────────────────────────────────────────────
//  Ashesh-compatible Nepali Unicode Converter
//  Pure Dart — no package needed, fully offline.
//  Romanized input → Devanagari (Unicode).
// ─────────────────────────────────────────────

/// Halant (virama) — joins consonants into conjuncts.
const String _halant = '्';

/// Anusvara (ं) and chandrabindu (ँ).
const String _anusvara = 'ं';
const String _chandrabindu = 'ँ';

/// Standalone vowels.
const Map<String, String> _vowels = {
  'a': 'अ',
  'aa': 'आ',
  'i': 'इ',
  'ii': 'ई',
  'ee': 'ई',
  'u': 'उ',
  'uu': 'ऊ',
  'oo': 'ऊ',
  'e': 'ए',
  'ai': 'ऐ',
  'o': 'ओ',
  'au': 'औ',
  'aw': 'औ',
  'ri': 'ऋ',
  'rri': 'ऋ',
};

/// Vowel matras (applied after a consonant). Keys MUST match [_vowels] exactly,
/// otherwise a vowel detected via [_vowelKeys] would have no matra to write.
const Map<String, String> _matras = {
  'a': '', // inherent vowel — no glyph
  'aa': 'ा',
  'i': 'ि',
  'ii': 'ी',
  'ee': 'ी',
  'u': 'ु',
  'uu': 'ू',
  'oo': 'ू',
  'e': 'े',
  'ai': 'ै',
  'o': 'ो',
  'au': 'ौ',
  'aw': 'ौ',
  'ri': 'ृ',
  'rri': 'ृ',
};

/// Consonants.
const Map<String, String> _consonants = {
  'ksh': 'क्ष',
  'gya': 'ज्ञ',
  'tra': 'त्र',
  'yna': 'ञ',
  'kh': 'ख',
  'gh': 'घ',
  'ng': 'ङ',
  'ch': 'च',
  'chh': 'छ',
  'jh': 'झ',
  'Th': 'ठ',
  'Dh': 'ढ',
  'Sh': 'ष',
  'th': 'थ',
  'dh': 'ध',
  'sh': 'श',
  'ph': 'फ',
  'bh': 'भ',
  'k': 'क',
  'g': 'ग',
  'c': 'च',
  'j': 'ज',
  'T': 'ट',
  'D': 'ड',
  'N': 'ण',
  't': 'त',
  'd': 'द',
  'n': 'न',
  'p': 'प',
  'b': 'ब',
  'm': 'म',
  'y': 'य',
  'r': 'र',
  'l': 'ल',
  'v': 'व',
  'w': 'व',
  'h': 'ह',
  's': 'स',
  'f': 'फ',
  'z': 'ज',
};

/// Keys sorted longest-first so multi-char tokens (`chh`, `ai`, `ksh`) win over
/// their own prefixes (`ch`, `a`, `k`). Map literal order does NOT guarantee
/// this, which is the bug the explicit sort fixes.
final List<String> _consonantKeys = _consonants.keys.toList()
  ..sort((a, b) => b.length - a.length);
final List<String> _vowelKeys = _vowels.keys.toList()
  ..sort((a, b) => b.length - a.length);

final RegExp _asciiLetter = RegExp(r'[a-zA-Z]');

/// Returns the longest key in [keys] that matches [text] starting at [i],
/// or `null`. Uses [String.startsWith] with an offset to avoid substring
/// allocations on every position.
String? _matchLongest(List<String> keys, String text, int i) {
  for (final key in keys) {
    if (text.startsWith(key, i)) return key;
  }
  return null;
}

/// Romanized typing reserves UPPERCASE only for retroflex sounds
/// (`T`=ट, `D`=ड, `N`=ण, `Sh`=ष). Every other capital — including an
/// auto-capitalized first letter like the `P` in "Pratham" — is folded to
/// lowercase so it converts instead of passing through as a stray Latin letter.
String _foldCase(String s) {
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final String c = s[i];
    final int u = c.codeUnitAt(0);
    final bool isUpper = u >= 0x41 && u <= 0x5A; // A–Z
    final bool isRetroflex = c == 'T' ||
        c == 'D' ||
        c == 'N' ||
        (c == 'S' && i + 1 < s.length && s[i + 1] == 'h');
    buf.write(isUpper && !isRetroflex ? c.toLowerCase() : c);
  }
  return buf.toString();
}

/// Converts a romanized [input] to Nepali Devanagari.
///
/// Conventions:
/// * `{...}` passes the inner text through verbatim (escape ASCII).
/// * `/` or `\` is a syllable break — suppresses the conjunct halant
///   (`k/h` → कह, vs `kh` → ख).
/// * `*` → anusvara (ं), `**` → chandrabindu (ँ).
/// * Digits, punctuation and whitespace pass through untouched.
String convertToNepali(String input) {
  final String text = _foldCase(input);
  final StringBuffer result = StringBuffer();
  int i = 0;
  bool lastWasConsonant = false;

  while (i < text.length) {
    final String ch = text[i];

    // {ASCII} pass-through (original case preserved).
    if (ch == '{') {
      final int end = text.indexOf('}', i);
      if (end == -1) {
        result.write(input.substring(i + 1));
        break;
      }
      result.write(input.substring(i + 1, end));
      i = end + 1;
      lastWasConsonant = false;
      continue;
    }

    // Explicit syllable break — no conjunct.
    if (ch == '/' || ch == '\\') {
      lastWasConsonant = false;
      i++;
      continue;
    }

    // Anusvara / chandrabindu.
    if (ch == '*') {
      if (i + 1 < input.length && input[i + 1] == '*') {
        result.write(_chandrabindu);
        i += 2;
      } else {
        result.write(_anusvara);
        i++;
      }
      lastWasConsonant = false;
      continue;
    }

    // Non-letters pass through.
    if (!_asciiLetter.hasMatch(ch)) {
      result.write(ch);
      i++;
      lastWasConsonant = false;
      continue;
    }

    // Consonant (+ optional following matra).
    final String? consKey = _matchLongest(_consonantKeys, text, i);
    if (consKey != null) {
      if (lastWasConsonant) result.write(_halant); // conjunct
      result.write(_consonants[consKey]!);
      i += consKey.length;
      lastWasConsonant = true;

      final String? vowKey = _matchLongest(_vowelKeys, text, i);
      if (vowKey != null) {
        result.write(_matras[vowKey]!); // '' for inherent 'a'
        i += vowKey.length;
        lastWasConsonant = false;
      }
      continue;
    }

    // Standalone vowel.
    final String? vowKey = _matchLongest(_vowelKeys, text, i);
    if (vowKey != null) {
      result.write(lastWasConsonant ? _matras[vowKey]! : _vowels[vowKey]!);
      i += vowKey.length;
      lastWasConsonant = false;
      continue;
    }

    // Unmatched letter — pass through.
    result.write(ch);
    i++;
    lastWasConsonant = false;
  }

  return result.toString();
}
