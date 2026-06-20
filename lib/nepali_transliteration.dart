/// Offline Romanized-to-Nepali transliteration and on-screen Devanagari keyboard.
library;

export 'src/converter/nepali_unicode_converter.dart' show convertToNepali;
export 'src/logic/nepali_transliteration.dart'
    show
        normalizeDictKey,
        deschwaKey,
        transliterationCandidates,
        transliterateSentence;
export 'src/logic/nepali_dictionary.dart' show NepaliDictionary;
export 'src/keyboard/nepali_keyboard.dart' show NepaliKeyboard;
