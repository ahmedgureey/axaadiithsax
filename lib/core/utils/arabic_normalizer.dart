/// Normalises text so searches match regardless of diacritics and common
/// letter variants (Arabic) or case (Somali/Latin).
abstract final class ArabicNormalizer {
  // Tashkeel + Quranic marks + tatweel.
  static final _diacritics = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

  static String normalize(String input) {
    var s = input.toLowerCase().replaceAll(_diacritics, '');
    s = s
        .replaceAll(RegExp('[إأآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
