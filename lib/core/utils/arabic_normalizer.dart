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

  /// Character ranges `(start, end)` of [text] (the ORIGINAL, unchanged
  /// text) that match any of the normalised [tokens], using the same rules
  /// as [normalize]. Diacritics after a matched letter are included so the
  /// whole written word is highlighted. Ranges are sorted and merged.
  static List<(int, int)> matchRanges(String text, List<String> tokens) {
    if (text.isEmpty || tokens.isEmpty) return const [];
    final norm = StringBuffer();
    final source = <int>[]; // index in [text] of each char of [norm]
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_diacritics.hasMatch(ch)) continue;
      String out;
      if (_spaces.hasMatch(ch)) {
        if (norm.isEmpty || norm.toString().endsWith(' ')) continue;
        out = ' ';
      } else {
        out = _mapChar(ch);
      }
      norm.write(out);
      source.add(i);
    }
    final n = norm.toString();
    final ranges = <(int, int)>[];
    for (final t in tokens) {
      if (t.isEmpty) continue;
      var from = 0;
      while (true) {
        final at = n.indexOf(t, from);
        if (at < 0) break;
        var end = source[at + t.length - 1] + 1;
        while (end < text.length && _diacritics.hasMatch(text[end])) {
          end++;
        }
        ranges.add((source[at], end));
        from = at + t.length;
      }
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final r in ranges) {
      if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
        final last = merged.removeLast();
        merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
      } else {
        merged.add(r);
      }
    }
    return merged;
  }

  /// One character through the same mapping as [normalize] (never longer
  /// than one character, so indexes stay aligned).
  static String _mapChar(String ch) {
    final lower = ch.toLowerCase();
    final c = lower.length == 1 ? lower : ch;
    if (_alef.hasMatch(c)) return 'ا';
    switch (c) {
      case 'ى' || 'ئ' || 'ی':
        return 'ي';
      case 'ؤ':
        return 'و';
      case 'ة':
        return 'ه';
      case 'ک':
        return 'ك';
    }
    if (_apostrophes.hasMatch(c)) return "'";
    var d = _arabicIndicDigits.indexOf(c);
    if (d < 0) d = _easternDigits.indexOf(c);
    return d >= 0 ? '$d' : c;
  }

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
