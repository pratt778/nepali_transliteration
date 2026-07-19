import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:nepali_transliteration/src/logic/nepali_transliteration.dart';

/// (`packages/nepali_transliteration/assets/nepali/dictionary.json`
/// at runtime, built from `assets/nepali/dictionary.json` by
/// `tool/build_nepali_dictionary.dart`) and answers transliteration queries
/// against it, with the phonetic engine as a built-in fallback.
///
/// Lazily loaded singleton — call [load] once (e.g. at app start or on first
/// use) and reuse [instance] afterwards.
class NepaliDictionary {
  NepaliDictionary._(this._map) : _fuzzy = _buildFuzzyIndex(_map);

  final Map<String, List<String>> _map;

  /// Schwa-tolerant fallback index: deschwa(key) → candidates, built only for
  /// longer keys so loose spellings (`kathamandu`) still resolve.
  final Map<String, List<String>> _fuzzy;

  /// Operator-picked corrections for this session: normalized key → the
  /// Devanagari value the operator chose over the top-ranked suggestion.
  /// Merged ahead of dictionary/fuzzy hits by [candidates] and [sentence].
  /// This is in-memory only — see [learnedSnapshot] / [loadLearned] to
  /// persist it across app restarts.
  final Map<String, String> _learned = {};

  static Map<String, List<String>> _buildFuzzyIndex(
    Map<String, List<String>> map,
  ) {
    final Map<String, Set<String>> index = {};
    for (final MapEntry<String, List<String>> e in map.entries) {
      if (e.key.length < 5) continue; // short words over-collapse
      index.putIfAbsent(deschwaKey(e.key), () => <String>{}).addAll(e.value);
    }
    return index.map((String k, Set<String> v) => MapEntry(k, v.toList()));
  }

  static NepaliDictionary? _instance;

  /// True once [load] has completed.
  static bool get isLoaded => _instance != null;

  /// The loaded singleton. Throws if [load] hasn't completed yet.
  static NepaliDictionary get instance {
    final NepaliDictionary? i = _instance;
    if (i == null) {
      throw StateError('NepaliDictionary.load() must complete before use.');
    }
    return i;
  }

  /// Reads and parses the asset once; subsequent calls return the cache.
  static Future<NepaliDictionary> load() async {
    final NepaliDictionary? existing = _instance;
    if (existing != null) return existing;

    final String raw = await rootBundle.loadString(
      'packages/nepali_transliteration/assets/nepali/dictionary.json',
    );
    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, List<String>> map = decoded.map(
      (String k, dynamic v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
    );
    return _instance = NepaliDictionary._(map);
  }

  /// Number of keys loaded — handy for diagnostics.
  int get size => _map.length;

  /// Number of corrections learned so far this session.
  int get learnedCount => _learned.length;

  /// Records that the operator picked [candidate] for [word] over whatever
  /// ranked first, so future lookups of the same word — in any casing or
  /// loose spelling that normalizes the same way — rank it first instead.
  ///
  /// This only updates the in-memory session map. To keep corrections across
  /// app restarts, persist [learnedSnapshot] yourself (e.g. to
  /// `shared_preferences`) and restore it with [loadLearned] at next launch.
  void remember(String word, String candidate) {
    final String key = normalizeDictKey(word);
    if (key.isEmpty || candidate.isEmpty) return;
    _learned[key] = candidate;
  }

  /// Forgets a previously [remember]ed correction for [word], if any.
  void forget(String word) => _learned.remove(normalizeDictKey(word));

  /// Clears every correction learned this session.
  void clearLearned() => _learned.clear();

  /// A serializable snapshot of everything learned so far — hand this to
  /// your own storage (e.g. `jsonEncode` it into `shared_preferences`) to
  /// persist corrections across app restarts.
  Map<String, String> learnedSnapshot() => Map.unmodifiable(_learned);

  /// Restores corrections previously saved via [learnedSnapshot] (e.g. loaded
  /// back from `shared_preferences` at app start). Keys are expected to
  /// already be normalized, exactly as [learnedSnapshot] produced them.
  void loadLearned(Map<String, String> saved) => _learned.addAll(saved);

  /// Ranked Devanagari candidates for a single typed [token]. Corrections
  /// [remember]ed this session are always considered first; an explicit
  /// [learned] map (if passed) takes priority over those.
  List<String> candidates(
    String token, {
    Map<String, String> learned = const {},
  }) => transliterationCandidates(
    token,
    dictionary: _map,
    learned: {..._learned, ...learned},
    fuzzy: _fuzzy,
  );

  /// Best-guess transliteration of a whole [input] (phrase-aware). Same
  /// [learned]-merging rule as [candidates].
  String sentence(String input, {Map<String, String> learned = const {}}) =>
      transliterateSentence(
        input,
        dictionary: _map,
        learned: {..._learned, ...learned},
        fuzzy: _fuzzy,
      );
}
