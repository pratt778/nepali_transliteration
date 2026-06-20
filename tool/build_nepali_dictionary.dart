// Offline builder: turns the raw AI-generated dictionary files in
// `tool/nepali_raw/*.json` into one clean, deduped, validated asset at
// `assets/nepali/dictionary.json`.
//
// Run:  dart run tool/build_nepali_dictionary.dart
//
// Accepts both schemas the data came in:
//   - places file: { "places": [ { "nepali": "...", "roman": [...] }, ... ] }
//   - all others:  [ { "devanagari": "...", "roman": [...] }, ... ]
//
// What it does, in order:
//   1. Reads devanagari from "devanagari" or "nepali".
//   2. Strips place admin suffixes (जिल्ला / नगरपालिका / …).
//   3. Rejects any value containing non-Devanagari characters (logged).
//   4. Drops roman keys < 3 chars and an English function-word stoplist.
//   5. Normalizes every roman → key; multi-word entries are stored BOTH as a
//      joined phrase key AND split into per-word keys when token counts align.
//   6. Dedups candidates per key; flags collisions and matra-only near-dups.
//   7. Writes the asset + prints a report.

import 'dart:convert';
import 'dart:io';

import 'package:nepali_transliteration/src/logic/nepali_transliteration.dart';


const String _rawDir = 'tool/nepali_raw';
const String _outPath = 'assets/nepali/dictionary.json';

const List<String> _adminSuffixes = [
  'महानगरपालिका',
  'उपमहानगरपालिका',
  'नगरपालिका',
  'गाउँपालिका',
  'जिल्ला',
];

/// English function words that crept in as glosses and would hijack typing.
const Set<String> _englishStoplist = {
  'you',
  'and',
  'but',
  'also',
  'our',
  'for',
  'from',
  'with',
  'the',
  'was',
  'are',
  'his',
  'her',
  'they',
  'this',
  'that',
  'who',
};

/// Devanagari block + space + danda. Used to reject ASCII-contaminated values.
final RegExp _devanagariOnly = RegExp(r'^[ऀ-ॿ\s।]+$');
final RegExp _parenthetical = RegExp(r'\s*\(.*?\)');

/// Strips a trailing admin suffix (जिल्ला / नगरपालिका / …) and any
/// parenthetical qualifier (`नवलपरासी (… पूर्व)` → नवलपरासी).
String _cleanValue(String value) {
  String v = value.replaceAll(_parenthetical, '').trim();
  for (final String suffix in _adminSuffixes) {
    if (v.endsWith(' $suffix')) {
      v = v.substring(0, v.length - suffix.length).trim();
      break;
    }
  }
  return v;
}

/// Folds long vowel matras onto their short forms (ी→ि, ू→ु) so that two
/// spellings differing ONLY by vowel length — the classic misspelling axis
/// (दीपक vs दिपक) — collapse together. Genuinely different words (चार vs चारा)
/// do not, keeping the review list actionable.
String _vowelFold(String devanagari) =>
    devanagari.replaceAll('ी', 'ि').replaceAll('ू', 'ु');

void main() {
  final Directory dir = Directory(_rawDir);
  if (!dir.existsSync()) {
    stderr.writeln(
      'Missing $_rawDir/ — save the 5 raw JSON files there first.',
    );
    exit(1);
  }

  final Map<String, Set<String>> entries = {}; // key → candidate set
  final List<String> rejected = [];
  final List<String> droppedKeys = [];
  int rawCount = 0;

  for (final FileSystemEntity f in dir.listSync()) {
    if (f is! File || !f.path.endsWith('.json')) continue;
    final dynamic parsed = jsonDecode(f.readAsStringSync());
    final List<dynamic> list = parsed is Map<String, dynamic>
        ? (parsed['places'] as List<dynamic>)
        : parsed as List<dynamic>;

    for (final dynamic raw in list) {
      final Map<String, dynamic> e = raw as Map<String, dynamic>;
      rawCount++;
      final String devanagari = _cleanValue(
        (e['devanagari'] ?? e['nepali'] ?? '') as String,
      );
      final List<String> romans = (e['roman'] as List<dynamic>).cast<String>();

      if (devanagari.isEmpty || !_devanagariOnly.hasMatch(devanagari)) {
        rejected.add('$devanagari  ←  ${romans.join(", ")}');
        continue;
      }

      void register(String roman, String value) {
        final String key = normalizeDictKey(roman);
        if (key.length < 3 || _englishStoplist.contains(roman.toLowerCase())) {
          droppedKeys.add('$roman → $value');
          return;
        }
        entries.putIfAbsent(key, () => <String>{}).add(value);
      }

      final List<String> devWords = devanagari.split(RegExp(r'\s+'));
      for (final String roman in romans) {
        register(roman, devanagari); // joined / whole-phrase key
        final List<String> romanWords = roman.trim().split(RegExp(r'\s+'));
        // Split aligned multi-word entries into per-word mappings.
        if (devWords.length > 1 && romanWords.length == devWords.length) {
          for (int i = 0; i < devWords.length; i++) {
            register(romanWords[i], devWords[i]);
          }
        }
      }
    }
  }

  // Report: collisions and matra-only near-duplicates.
  final List<String> collisions = [];
  for (final MapEntry<String, Set<String>> e in entries.entries) {
    if (e.value.length > 1) {
      collisions.add('${e.key} → ${e.value.join(" | ")}');
    }
  }

  final Map<String, Set<String>> byFold = {};
  for (final Set<String> cands in entries.values) {
    for (final String d in cands) {
      byFold.putIfAbsent(_vowelFold(d), () => <String>{}).add(d);
    }
  }
  final List<String> nearDups = byFold.values
      .where((s) => s.length > 1)
      .map((s) => s.join(' / '))
      .toList();

  // Write asset (sorted for stable diffs).
  final Map<String, List<String>> out = {
    for (final String k in entries.keys.toList()..sort())
      k: entries[k]!.toList(),
  };
  final File outFile = File(_outPath)..createSync(recursive: true);
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));

  stdout.writeln('── Nepali dictionary build ─────────────────');
  stdout.writeln('raw entries read     : $rawCount');
  stdout.writeln('unique keys written  : ${out.length}  →  $_outPath');
  stdout.writeln('multi-candidate keys : ${collisions.length}');
  stdout.writeln('rejected (non-Deva)  : ${rejected.length}');
  stdout.writeln(
    'dropped roman keys   : ${droppedKeys.length} (short / stoplist)',
  );
  stdout.writeln('matra near-dup groups: ${nearDups.length} (review these)');
  if (rejected.isNotEmpty) {
    stdout.writeln('\n‼️  REJECTED (fix or remove in raw files):');
    for (final r in rejected) {
      stdout.writeln('   $r');
    }
  }
  if (nearDups.isNotEmpty) {
    stdout.writeln('\n⚠️  NEAR-DUPLICATES (likely one is a misspelling):');
    nearDups.take(40).forEach((d) => stdout.writeln('   $d'));
    if (nearDups.length > 40) {
      stdout.writeln('   … ${nearDups.length - 40} more');
    }
  }
}
