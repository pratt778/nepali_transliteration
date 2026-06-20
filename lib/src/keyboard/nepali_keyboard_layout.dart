// Character layout data for the on-screen Devanagari keyboard.
// Each entry is the exact Unicode string a key inserts at the cursor.
// Matras are combining marks — inserting one after a consonant renders the
// joined glyph automatically (क + ि → कि), so no positioning logic is needed.

/// Consonants (व्यञ्जन), including the three common conjuncts. 36 keys → 6×6.
const List<String> kNepaliConsonants = [
  'क', 'ख', 'ग', 'घ', 'ङ', 'च', //
  'छ', 'ज', 'झ', 'ञ', 'ट', 'ठ', //
  'ड', 'ढ', 'ण', 'त', 'थ', 'द', //
  'ध', 'न', 'प', 'फ', 'ब', 'भ', //
  'म', 'य', 'र', 'ल', 'व', 'श', //
  'ष', 'स', 'ह', 'क्ष', 'त्र', 'ज्ञ', //
];

/// Common vowel matras shown as a quick strip in consonant mode.
/// `्` (halant) is included to build conjuncts manually.
const List<String> kNepaliCommonMatras = [
  'ा', 'ि', 'ी', 'ु', 'ू', 'े', 'ो', '्', //
];

/// Standalone vowels (स्वर) for word-initial positions.
const List<String> kNepaliVowels = [
  'अ', 'आ', 'इ', 'ई', 'उ', 'ऊ', //
  'ए', 'ऐ', 'ओ', 'औ', 'ऋ', 'अं', //
];

/// Full matra set (combining), including the less common ones.
const List<String> kNepaliAllMatras = [
  'ा', 'ि', 'ी', 'ु', 'ू', 'ृ', //
  'े', 'ै', 'ो', 'ौ', 'ं', 'ँ', //
  'ः', '्', //
];

/// Devanagari digits (अंक) ० – ९.
const List<String> kNepaliDigits = [
  '१', '२', '३', '४', '५', //
  '६', '७', '८', '९', '०', //
];

/// Punctuation commonly needed alongside Nepali text.
const List<String> kNepaliPunctuation = [
  '।', ',', '.', '-', '/', '?', //
];
