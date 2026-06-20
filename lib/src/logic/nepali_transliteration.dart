
// ─────────────────────────────────────────────
//  Offline Romanized → Nepali transliteration with a dictionary.
//
//  A pure phonetic engine ([convertToNepali]) forces precise input
//  (`kaaThamaaDau*`). Real operators type loose forms (`kathmandu`). This
//  layer sits on top: it looks a token up in a dictionary of how people
//  actually type, and only falls back to the phonetic engine for unknowns.
//
//  The dictionary is built offline from raw data files by
//  `tool/build_nepali_dictionary.dart` into `assets/nepali/dictionary.json`,
//  loaded at runtime as `Map<String, List<String>>` (normalized key →
//  ranked Devanagari candidates). Pair it with a persisted `learned` map
//  (operator-picked corrections) and offline coverage compounds with use.
// ─────────────────────────────────────────────

import 'package:nepali_transliteration/src/converter/nepali_unicode_converter.dart';

/// Vowels collapsed during normalization so `kaathmaandu` and `kathmandu`
/// produce the same dictionary key.
const String _vowelLetters = 'aeiou';

/// Max number of typed words a single dictionary phrase may span
/// (`jeep safari` → जिप सफारी). Keeps greedy phrase lookup bounded.
const int kMaxPhraseWords = 4;

final RegExp _asciiLetterLower = RegExp(r'[a-z]');

/// Canonical lookup key for a romanized [token]: lowercased, letters only,
/// with runs of the same vowel collapsed (`Kaathmaandu` → `kathmandu`).
/// Whitespace is stripped, so a multi-word phrase collapses to one key
/// (`jeep safari` → `jepsafari`), which is how phrase entries are stored.
String normalizeDictKey(String token) {
  final String lower = token.toLowerCase();
  final StringBuffer buf = StringBuffer();
  String? prev;
  for (int i = 0; i < lower.length; i++) {
    final String c = lower[i];
    if (!_asciiLetterLower.hasMatch(c)) continue;
    // Collapse only repeated vowels — keep doubled consonants intact.
    if (c == prev && _vowelLetters.contains(c)) continue;
    buf.write(c);
    prev = c;
  }
  return buf.toString();
}

/// Drops interior schwa (short `a`) from a normalized [key], keeping the first
/// letter, so loosely-sprinkled vowels collapse onto a canonical form:
/// `kathmandu` and `kathamandu` both → `kthmndu`. Used only as a fuzzy
/// fallback for longer words, since short words over-collapse (`ram` → `rm`).
String deschwaKey(String key) {
  if (key.length < 2) return key;
  final StringBuffer buf = StringBuffer(key[0]);
  for (int i = 1; i < key.length; i++) {
    if (key[i] != 'a') buf.write(key[i]);
  }
  return buf.toString();
}

/// Ranked, de-duplicated Devanagari candidates for a single [token].
///
/// Order: learned mapping → exact dictionary → fuzzy (schwa-tolerant) match
/// when there's no exact hit → phonetic fallback. The phonetic result is
/// always appended, so there is never a dead end.
List<String> transliterationCandidates(
  String token, {
  Map<String, List<String>> dictionary = const {},
  Map<String, String> learned = const {},
  Map<String, List<String>> fuzzy = const {},
}) {
  if (token.isEmpty) return const [];

  final List<String> out = [];
  final String key = normalizeDictKey(token);

  void add(String? value) {
    if (value != null && value.isNotEmpty && !out.contains(value)) {
      out.add(value);
    }
  }

  add(learned[key]);
  final List<String>? hits = dictionary[key];
  if (hits != null) {
    for (final String h in hits) {
      add(h);
    }
  } else {
    // No exact hit — try a schwa-tolerant match before sounding it out.
    final List<String>? fuzzyHits = fuzzy[deschwaKey(key)];
    if (fuzzyHits != null) {
      for (final String h in fuzzyHits) {
        add(h);
      }
    }
  }
  add(convertToNepali(token));
  return out;
}

/// Best-guess transliteration of a whole [input] string for non-interactive
/// use (no suggestion bar). Greedy: at each position it tries the longest run
/// of words (up to [kMaxPhraseWords]) that hits a dictionary phrase, else
/// falls back to a single token's top candidate. Words are rejoined with a
/// single space.
String transliterateSentence(
  String input, {
  Map<String, List<String>> dictionary = const {},
  Map<String, String> learned = const {},
  Map<String, List<String>> fuzzy = const {},
}) {
  if (input.trim().isEmpty) return input;

  final List<String> words = input.trim().split(RegExp(r'\s+'));
  final List<String> out = [];
  int i = 0;

  while (i < words.length) {
    String? matched;
    int span = 1;

    // Greedy longest phrase first.
    final int maxSpan = (words.length - i).clamp(1, kMaxPhraseWords);
    for (int w = maxSpan; w >= 2; w--) {
      final String key = normalizeDictKey(words.sublist(i, i + w).join());
      final List<String>? hits = learned.containsKey(key)
          ? [learned[key]!]
          : dictionary[key];
      if (hits != null && hits.isNotEmpty) {
        matched = hits.first;
        span = w;
        break;
      }
    }

    matched ??= () {
      final List<String> c = transliterationCandidates(
        words[i],
        dictionary: dictionary,
        learned: learned,
        fuzzy: fuzzy,
      );
      return c.isEmpty ? words[i] : c.first;
    }();

    out.add(matched);
    i += span;
  }

  return out.join(' ');
}
