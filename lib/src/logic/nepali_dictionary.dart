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

  /// Ranked Devanagari candidates for a single typed [token].
  List<String> candidates(
    String token, {
    Map<String, String> learned = const {},
  }) => transliterationCandidates(
    token,
    dictionary: _map,
    learned: learned,
    fuzzy: _fuzzy,
  );

  /// Best-guess transliteration of a whole [input] (phrase-aware).
  String sentence(String input, {Map<String, String> learned = const {}}) =>
      transliterateSentence(
        input,
        dictionary: _map,
        learned: learned,
        fuzzy: _fuzzy,
      );
}
