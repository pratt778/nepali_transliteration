## 0.1.1

* Added `NepaliDictionaryLoader` widget to handle asynchronous loading states and customize progress or error screens.
* Implemented a session-level learned corrections system in `NepaliDictionary` (`remember`, `forget`, `learnedSnapshot`, `loadLearned`) to prioritize user-selected suggestions.
* Improved `NepaliKeyboard` backspace behavior to delete multi-character conjunct keys (e.g. क्ष, त्र, ज्ञ, अं) as single atomic units.
* Added `canRequestFocus: false` to virtual keyboard buttons to avoid stealing focus from the active text field.
* Updated the dictionary builder script to sort input files alphabetically for deterministic compiled assets.
* Added comprehensive unit and widget tests for dictionary loading, learning, and keyboard interactions.

## 0.1.0

* Initial release of the `nepali_transliteration` package.
* Added offline Romanized-to-Nepali phonetic transliteration engine (`convertToNepali`).
* Added dictionary-based transliteration candidate suggestions (`NepaliDictionary`) with fuzzy matching support.
* Added custom on-screen Devanagari keyboard widget (`NepaliKeyboard`) with text-shaping helper integration.
* Added command-line dictionary pre-builder script (`build_nepali_dictionary.dart`) to process raw input files.
