/// Normalises text for *matching only* — displayed text is never changed.
///
/// Arabic (justified, widely used search equivalences):
/// * removes tashkeel / Quranic marks and tatweel (ـ),
/// * unifies alef forms (إ أ آ ٱ → ا), alef maqsura (ى → ي),
///   hamza carriers (ؤ → و, ئ → ي) and taa marbuta (ة → ه),
/// * maps Persian/Urdu look-alikes that keyboards often produce
///   (ک → ك, ی → ي),
/// * maps Arabic-Indic digits to ASCII so "٣" matches "3".
///
/// Somali / Latin:
/// * lower-cases (case-insensitive),
/// * unifies apostrophe variants (’ ‘ ` ´ → ') used for the glottal stop,
/// * does NOT merge distinct Somali letters (c, x, q, kh, dh, sh stay
///   distinct — "xasan" must not match "hasan").
///
/// Whitespace is collapsed and trimmed.
abstract final class ArabicNormalizer {
  static final _diacritics = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');
  static final _alef = RegExp('[إأآٱ]');
  static final _apostrophes = RegExp('[’‘`´]');
  static final _spaces = RegExp(r'\s+');

  static const _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _easternDigits = '۰۱۲۳۴۵۶۷۸۹';

  static String normalize(String input) {
    var s = input.toLowerCase().replaceAll(_diacritics, '');
    s = s
        .replaceAll(_alef, 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ک', 'ك')
        .replaceAll('ی', 'ي')
        .replaceAll(_apostrophes, "'");
    s = _asciiDigits(s);
    return s.replaceAll(_spaces, ' ').trim();
  }

  /// Splits a normalised query into search tokens (empty → no tokens).
  static List<String> tokens(String query) =>
      normalize(query).split(' ').where((t) => t.isNotEmpty).toList(growable: false);

  static String _asciiDigits(String s) {
    final buffer = StringBuffer();
    for (final rune in s.runes) {
      final char = String.fromCharCode(rune);
      var i = _arabicIndicDigits.indexOf(char);
      if (i < 0) i = _easternDigits.indexOf(char);
      buffer.write(i >= 0 ? '$i' : char);
    }
    return buffer.toString();
  }
}
