import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_transliteration/nepali_transliteration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NepaliDictionary learned corrections', () {
    test('remember() ranks the picked candidate first on future lookups', () async {
      final dict = await NepaliDictionary.load();
      dict.clearLearned();

      final before = dict.candidates('kathmandu');
      expect(before.first, isNot('कथ्मन्दु')); // dictionary hit ranks first

      dict.remember('kathmandu', 'कथ्मन्दु');
      final after = dict.candidates('kathmandu');
      expect(after.first, 'कथ्मन्दु');

      dict.clearLearned();
    });

    test('remember() matches any casing/spelling that normalizes the same', () async {
      final dict = await NepaliDictionary.load();
      dict.clearLearned();

      dict.remember('Kaathmaandu', 'टेस्ट'); // deliberately odd casing/spelling
      expect(dict.candidates('kathmandu').first, 'टेस्ट');
      expect(dict.candidates('KATHMANDU').first, 'टेस्ट');

      dict.clearLearned();
    });

    test('learnedSnapshot / loadLearned round-trip', () async {
      final dict = await NepaliDictionary.load();
      dict.clearLearned();

      dict.remember('sunil', 'कस्टम'); // a value that isn't already top-ranked
      final snapshot = dict.learnedSnapshot();
      dict.clearLearned();
      expect(dict.candidates('sunil').first, isNot('कस्टम'));

      dict.loadLearned(snapshot);
      expect(dict.candidates('sunil').first, 'कस्टम');

      dict.clearLearned();
    });

    test('forget() removes a single learned correction', () async {
      final dict = await NepaliDictionary.load();
      dict.clearLearned();

      dict.remember('ram', 'रामकुमार');
      expect(dict.candidates('ram').first, 'रामकुमार');

      dict.forget('ram');
      expect(dict.candidates('ram').first, isNot('रामकुमार'));
    });

    test('explicit learned param passed to candidates() overrides remember()', () async {
      final dict = await NepaliDictionary.load();
      dict.clearLearned();

      dict.remember('ram', 'रामकुमार');
      final overridden = dict.candidates('ram', learned: {'ram': 'अर्को'});
      expect(overridden.first, 'अर्को');

      dict.clearLearned();
    });
  });
}
