import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_transliteration/src/converter/nepali_unicode_converter.dart';

void main() {
  group('convertToNepali', () {
    test('empty string returns empty', () {
      expect(convertToNepali(''), '');
    });

    group('standalone vowels', () {
      test('single short vowels', () {
        expect(convertToNepali('a'), 'अ');
        expect(convertToNepali('i'), 'इ');
        expect(convertToNepali('u'), 'उ');
        expect(convertToNepali('e'), 'ए');
        expect(convertToNepali('o'), 'ओ');
      });

      test('long vowels win over their prefixes (longest-first)', () {
        expect(convertToNepali('aa'), 'आ');
        expect(convertToNepali('ii'), 'ई');
        expect(convertToNepali('ee'), 'ई');
        expect(convertToNepali('uu'), 'ऊ');
        expect(convertToNepali('oo'), 'ऊ');
      });

      test('diphthongs ai/au are not split into a+i / a+u (BUG FIX)', () {
        expect(convertToNepali('ai'), 'ऐ');
        expect(convertToNepali('au'), 'औ');
        expect(convertToNepali('aw'), 'औ');
      });
    });

    group('consonants', () {
      test('single consonant carries the inherent vowel', () {
        expect(convertToNepali('k'), 'क');
        expect(convertToNepali('ka'), 'क');
      });

      test('consonant + explicit matra', () {
        expect(convertToNepali('kaa'), 'का');
        expect(convertToNepali('ki'), 'कि');
        expect(convertToNepali('kii'), 'की');
        expect(convertToNepali('ku'), 'कु');
        expect(convertToNepali('ke'), 'के');
        expect(convertToNepali('ko'), 'को');
      });

      test('diphthong matra is applied (BUG FIX)', () {
        expect(convertToNepali('kai'), 'कै');
        expect(convertToNepali('kau'), 'कौ');
      });

      test('two-letter consonants', () {
        expect(convertToNepali('kha'), 'ख');
        expect(convertToNepali('tha'), 'थ');
        expect(convertToNepali('sha'), 'श');
      });

      test('chh resolves to छ, not ch + h (BUG FIX)', () {
        expect(convertToNepali('cha'), 'च');
        expect(convertToNepali('chha'), 'छ');
      });

      test('three-letter conjunct consonants', () {
        expect(convertToNepali('ksha'), 'क्ष');
        expect(convertToNepali('gya'), 'ज्ञ');
        expect(convertToNepali('tra'), 'त्र');
      });

      test('case-sensitive retroflex variants', () {
        expect(convertToNepali('Tha'), 'ठ');
        expect(convertToNepali('Sha'), 'ष');
        expect(convertToNepali('Na'), 'ण');
        expect(convertToNepali('Da'), 'ड');
        expect(convertToNepali('Ta'), 'ट');
      });
    });

    group('conjuncts (halant joining)', () {
      test('adjacent consonants join with halant', () {
        expect(convertToNepali('kk'), 'क्क');
        expect(convertToNepali('kya'), 'क्य');
      });

      test('slash forces a syllable break, suppressing the conjunct', () {
        expect(convertToNepali('k/h'), 'कह');
        // contrast: without the slash, "kh" is a single consonant
        expect(convertToNepali('kh'), 'ख');
      });
    });

    group('nasal markers', () {
      test('single star is anusvara', () {
        expect(convertToNepali('a*'), 'अं');
      });

      test('double star is chandrabindu', () {
        expect(convertToNepali('a**'), 'अँ');
      });
    });

    group('pass-through', () {
      test('digits and punctuation are untouched', () {
        expect(convertToNepali('123'), '123');
        expect(convertToNepali('k123'), 'क123');
      });

      test('{...} escapes ASCII verbatim', () {
        expect(convertToNepali('{ABC}'), 'ABC');
        expect(convertToNepali('{Hi} ka'), 'Hi क');
      });

      test('unterminated brace dumps the rest', () {
        expect(convertToNepali('{ABC'), 'ABC');
      });
    });

    test('yna maps to the palatal nasal ञ', () {
      expect(convertToNepali('yna'), 'ञ');
    });

    group('case folding', () {
      test('non-retroflex capitals fold to lowercase (auto-capitalize fix)', () {
        // The "Pratham → Pरथम" bug: capital P used to pass through literally.
        expect(convertToNepali('Pratham'), 'प्रथम');
        expect(convertToNepali('Pratham'), convertToNepali('pratham'));
        expect(convertToNepali('Hari'), convertToNepali('hari'));
      });

      test('retroflex capitals T/D/N/Sh are still significant', () {
        // Leading T stays retroflex (ट), so it differs from lowercase त.
        expect(convertToNepali('Tara'), 'टर');
        expect(convertToNepali('tara'), 'तर');
        expect(convertToNepali('Tara') == convertToNepali('tara'), isFalse);
      });
    });

    group('whole words — correct PHONETIC spellings', () {
      // This is a phonetic engine, not a dictionary. Real Nepali words are
      // typed by sound, with every inherent "a" written and long vowels
      // doubled ("aa"/"ii"/"uu"). The English exonyms (Kathmandu, sarkar) are
      // NOT phonetic and are covered separately below.
      test('produces real Nepali words', () {
        expect(convertToNepali('nepaal'), 'नेपाल');
        expect(convertToNepali('sarakaar'), 'सरकार');
        expect(convertToNepali('kaaThamaaDau*'), 'काठमाडौं');
        expect(convertToNepali('hari'), 'हरि');
        expect(convertToNepali('pratham'), 'प्रथम');
        expect(convertToNepali('namaste'), 'नमस्ते');
      });
    });

    group('documented gotchas (intended behaviour, not bugs)', () {
      test('inherent "a" must be typed — omitting it forms a conjunct', () {
        // 'sarkar' drops the inherent 'a' after र, so र+क join: सर्कर ≠ सरकार.
        expect(convertToNepali('sarkar'), 'सर्कर');
        // The slash forces a syllable break, restoring the full consonant.
        expect(convertToNepali('sarakar'), 'सरकर');
      });

      test('anglicized English spelling is not phonetic Nepali', () {
        // 'kathmandu' as-typed is gibberish to a phonetic engine.
        expect(convertToNepali('kathmandu'), 'कथ्मन्दु');
      });

      test('leading "r" is read as a consonant, never the vowel ऋ', () {
        // 'r' matches as a consonant before the vowel keys 'ri'/'rri', so
        // standalone ऋ is unreachable from a leading r.
        expect(convertToNepali('ri'), 'रि');
        expect(convertToNepali('rii'), 'री');
      });

      test('words with spaces preserve the space', () {
        expect(convertToNepali('hari ka'), 'हरि क');
      });
    });
  });
}
