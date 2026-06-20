import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_transliteration/src/logic/nepali_transliteration.dart';

void main() {
  // Stand-in for the built asset (key → ranked candidates). Keys are already
  // normalized (lowercase, vowel-runs collapsed) exactly as the importer emits.
  final Map<String, List<String>> dict = {
    'kathmandu': ['काठमाडौं'],
    'sarkar': ['सरकार'],
    'nepal': ['नेपाल'],
    'ghas': ['घाँस'],
    'ram': ['राम'],
    'rana': ['राणा', 'राना'], // genuine collision → two candidates
    // phrase entries: joined-then-normalized roman → multi-word value
    'jepsafari': ['जिप सफारी'],
    'jep': ['जिप'],
    'safari': ['सफारी'],
  };

  group('normalizeDictKey', () {
    test('lowercases and strips non-letters', () {
      expect(normalizeDictKey('Kathmandu!'), 'kathmandu');
      expect(normalizeDictKey('hari-123'), 'hari');
    });

    test('collapses repeated vowels but keeps doubled consonants', () {
      expect(normalizeDictKey('kaathmaandu'), 'kathmandu');
      expect(normalizeDictKey('nepaal'), 'nepal');
      expect(normalizeDictKey('patta'), 'patta');
    });

    test('strips whitespace so a phrase collapses to one key', () {
      expect(normalizeDictKey('jeep safari'), 'jepsafari');
    });
  });

  group('transliterationCandidates', () {
    test('empty token yields no candidates', () {
      expect(transliterationCandidates('', dictionary: dict), isEmpty);
    });

    test('dictionary hit ranks first', () {
      expect(
        transliterationCandidates('kathmandu', dictionary: dict).first,
        'काठमाडौं',
      );
      expect(
        transliterationCandidates('sarkar', dictionary: dict).first,
        'सरकार',
      );
    });

    test('loose vowel spellings still hit via normalization', () {
      expect(
        transliterationCandidates('kaathmaandu', dictionary: dict).first,
        'काठमाडौं',
      );
      expect(
        transliterationCandidates('Kathmandu', dictionary: dict).first,
        'काठमाडौं',
      );
    });

    test('collision exposes both candidates, dictionary order preserved', () {
      final c = transliterationCandidates('rana', dictionary: dict);
      expect(c[0], 'राणा');
      expect(c[1], 'राना');
    });

    test('phonetic fallback is always appended after dictionary hits', () {
      final c = transliterationCandidates('nepal', dictionary: dict);
      expect(c.first, 'नेपाल'); // dictionary
      expect(c, contains('नेपल')); // phonetic (inherent-a)
    });

    test('unknown word falls back to phonetic only', () {
      expect(transliterationCandidates('namaste', dictionary: dict), [
        'नमस्ते',
      ]);
    });

    test('learned map overrides and ranks above the dictionary', () {
      final c = transliterationCandidates(
        'ram',
        dictionary: dict,
        learned: {'ram': 'रामकुमार'},
      );
      expect(c.first, 'रामकुमार');
      expect(c, contains('राम'));
    });

    test('with no dictionary it degrades to pure phonetic', () {
      expect(transliterationCandidates('hari'), ['हरि']);
    });
  });

  group('deschwaKey / fuzzy fallback', () {
    test('deschwaKey drops interior short-a, keeps the first letter', () {
      expect(deschwaKey('kathmandu'), 'kthmndu');
      expect(deschwaKey('kathamandu'), 'kthmndu'); // extra schwa collapses too
    });

    test('schwa-sprinkled spelling resolves via the fuzzy index', () {
      final fuzzy = {'kthmndu': ['काठमाडौं']};
      // "kathamandu" misses the exact dictionary but hits fuzzy.
      final c = transliterationCandidates(
        'kathamandu',
        dictionary: dict,
        fuzzy: fuzzy,
      );
      expect(c.first, 'काठमाडौं');
    });

    test('exact dictionary hit is preferred over fuzzy', () {
      final fuzzy = {'kthmndu': ['गलत']};
      final c = transliterationCandidates(
        'kathmandu',
        dictionary: dict,
        fuzzy: fuzzy,
      );
      expect(c.first, 'काठमाडौं'); // exact wins; fuzzy not consulted
      expect(c, isNot(contains('गलत')));
    });
  });

  group('transliterateSentence', () {
    test('transliterates word by word, dictionary-first', () {
      expect(
        transliterateSentence('hari kathmandu', dictionary: dict),
        'हरि काठमाडौं',
      );
    });

    test('greedy phrase match beats word-by-word', () {
      // "jeep safari" hits the phrase entry जिप सफारी as a single unit.
      expect(
        transliterateSentence('jeep safari', dictionary: dict),
        'जिप सफारी',
      );
    });

    test('empty input passes through', () {
      expect(transliterateSentence('', dictionary: dict), '');
    });
  });
}
