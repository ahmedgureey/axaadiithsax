/// Hadith import dataset (`xadiith-import/1`) — parsing and validation.
///
/// Pure Dart (no Flutter), so it runs in the CLI and in unit tests. The
/// validator never changes text: Arabic is kept byte-for-byte; normalization
/// is used only to *report* possible duplicates.
library;

import 'dart:convert';

import 'package:xadiithapp/core/utils/arabic_normalizer.dart';

const datasetFormat = 'xadiith-import/1';

const gradeKinds = {'sahih', 'hasan', 'hasan_sahih', 'daif', 'daif_jiddan', 'mawdu', 'other'};

/// Same rules as the database's `public.normalize_arabic` (migration 0009)
/// and the app's search: one shared implementation. Used for duplicate
/// detection only — text is never changed.
String normalizeArabic(String input) => ArabicNormalizer.normalize(input);

class Issue {
  const Issue(this.path, this.message);
  final String path;
  final String message;

  Map<String, String> toJson() => {'path': path, 'message': message};

  @override
  String toString() => '$path: $message';
}

class ValidationReport {
  final errors = <Issue>[];
  final warnings = <Issue>[];
  int books = 0, chapters = 0, hadiths = 0, translations = 0, gradings = 0;

  /// Records that will need extra editorial attention (reported, not errors).
  int withoutTranslation = 0, withoutGrading = 0, withoutSourceReference = 0;

  bool get ok => errors.isEmpty;

  Map<String, Object> toJson() => {
    'ok': ok,
    'counts': {
      'books': books,
      'chapters': chapters,
      'hadiths': hadiths,
      'translations': translations,
      'gradings': gradings,
      'hadiths_without_translation': withoutTranslation,
      'hadiths_without_grading': withoutGrading,
      'hadiths_without_source_reference': withoutSourceReference,
    },
    'errors': [for (final e in errors) e.toJson()],
    'warnings': [for (final w in warnings) w.toJson()],
  };
}

/// Parsed, validated dataset. Only constructed when validation passes.
class Dataset {
  Dataset._(this.json);

  final Map<String, dynamic> json;

  Map<String, dynamic> get provenance => json['provenance'] as Map<String, dynamic>;
  Map<String, dynamic> get collection => json['collection'] as Map<String, dynamic>;
  String get numberingScheme => json['numbering_scheme'] as String;
  List<Map<String, dynamic>> get books => _list('books');
  List<Map<String, dynamic>> get chapters => _list('chapters');
  List<Map<String, dynamic>> get hadiths => _list('hadiths');

  List<Map<String, dynamic>> _list(String key) => [
    for (final e in (json[key] as List? ?? const [])) e as Map<String, dynamic>,
  ];

  /// Validates [source] (the raw file text). Returns the report and, when it
  /// has no errors, the dataset.
  static (ValidationReport, Dataset?) parse(String source) {
    final report = ValidationReport();
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      report.errors.add(Issue(r'$', 'Not valid JSON: ${e.message}'));
      return (report, null);
    }
    if (decoded is! Map<String, dynamic>) {
      report.errors.add(const Issue(r'$', 'Top level must be an object'));
      return (report, null);
    }
    _Validator(decoded, report).run();
    return (report, report.ok ? Dataset._(decoded) : null);
  }
}

class _Validator {
  _Validator(this.root, this.r);

  final Map<String, dynamic> root;
  final ValidationReport r;

  static final _slug = RegExp(r'^[a-z0-9][a-z0-9_-]*$');
  static final _url = RegExp(r'^https?://\S+$');
  static final _lang = RegExp(r'^[a-z]{2,3}$');

  void err(String path, String msg) => r.errors.add(Issue(path, msg));
  void warn(String path, String msg) => r.warnings.add(Issue(path, msg));

  /// Required non-empty string. Rejects template placeholders like `<<…>>`.
  String? req(Map<String, dynamic> m, String key, String path) {
    final v = m[key];
    if (v is! String || v.trim().isEmpty) {
      err('$path.$key', 'required text is missing');
      return null;
    }
    if (v.contains('<<') || v.contains('>>')) {
      err('$path.$key', 'still contains a template placeholder');
      return null;
    }
    return v;
  }

  String? opt(Map<String, dynamic> m, String key, String path) {
    final v = m[key];
    if (v == null) return null;
    if (v is! String) {
      err('$path.$key', 'must be text');
      return null;
    }
    if (v.contains('<<') || v.contains('>>')) err('$path.$key', 'still contains a template placeholder');
    return v.trim().isEmpty ? null : v;
  }

  static final _markup = RegExp(r'<\s*/?\s*[a-zA-Z][^>]*>');
  static final _entity = RegExp(r'&(#\d+|#x[0-9a-fA-F]+|[a-zA-Z]{2,8});');
  static final _control = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');
  // Arabic UTF-8 bytes read as Latin-1 show up as "Ø§", "Ù„", …
  static final _mojibake = RegExp('[ØÙÃ][\u0080-¿]');
  static final _arabicLetter = RegExp('[ء-ي]');

  /// Content checks for Arabic text and translations. They only REPORT
  /// problems; text is never changed. Passing them proves nothing about
  /// authenticity — that is the reviewers' job.
  void checkText(String text, String path, {required bool arabicScript, bool somali = false}) {
    if (_markup.hasMatch(text)) err(path, 'contains HTML/markup');
    if (_entity.hasMatch(text)) err(path, 'contains an HTML entity such as &nbsp;');
    if (text.contains('�')) err(path, 'contains the replacement character (broken encoding)');
    if (_control.hasMatch(text)) err(path, 'contains control characters');
    if (_mojibake.hasMatch(text)) err(path, 'looks like mis-decoded UTF-8 (mojibake)');
    if (arabicScript) {
      final letters = _arabicLetter.allMatches(text).length;
      if (letters == 0) {
        err(path, 'contains no Arabic letters');
      } else if (letters < 10) {
        warn(path, 'very short — check that the text is not truncated');
      }
    }
    if (somali) {
      if (!RegExp('[A-Za-z]').hasMatch(text)) {
        warn(path, 'Somali translation has no Latin letters — check language/encoding');
      }
      if (_arabicLetter.hasMatch(text)) {
        warn(path, 'contains Arabic script — keep the Arabic and the translation in separate fields');
      }
    }
    final end = text.trimRight();
    if (end.endsWith('...') || end.endsWith('…')) warn(path, 'ends with an ellipsis — possibly truncated');
  }

  void url(Map<String, dynamic> m, String key, String path) {
    final v = opt(m, key, path);
    if (v != null && !_url.hasMatch(v)) err('$path.$key', 'must be an http(s) URL');
  }

  int? posInt(Map<String, dynamic> m, String key, String path, {bool required = true}) {
    final v = m[key];
    if (v == null && !required) return null;
    if (v is! int || v <= 0) {
      err('$path.$key', 'must be a positive whole number');
      return null;
    }
    return v;
  }

  List<Map<String, dynamic>> list(String key, String path, {bool required = true}) {
    final v = root[key];
    if (v == null && !required) return const [];
    if (v is! List) {
      err('$path.$key', 'must be a list');
      return const [];
    }
    final out = <Map<String, dynamic>>[];
    for (final (i, e) in v.indexed) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else {
        err('$path.$key[$i]', 'must be an object');
      }
    }
    return out;
  }

  void run() {
    if (root['format'] != datasetFormat) err(r'$.format', 'must be "$datasetFormat"');

    final prov = root['provenance'];
    if (prov is! Map<String, dynamic>) {
      err(r'$.provenance', 'required: where the data comes from and under which licence');
    } else {
      req(prov, 'source_name', r'$.provenance');
      req(prov, 'license', r'$.provenance');
      opt(prov, 'source_edition', r'$.provenance');
      url(prov, 'source_url', r'$.provenance');
      final lang = opt(prov, 'source_language', r'$.provenance');
      if (lang != null && !_lang.hasMatch(lang)) err(r'$.provenance.source_language', 'must be an ISO code like "ar"');
      final retrieved = opt(prov, 'retrieved_at', r'$.provenance');
      if (retrieved != null && DateTime.tryParse(retrieved) == null) {
        err(r'$.provenance.retrieved_at', 'must be an ISO date, e.g. 2026-11-23');
      }
      if (prov['source_url'] == null) {
        warn(r'$.provenance.source_url', 'missing: the dataset origin cannot be checked online');
      }
    }

    final col = root['collection'];
    if (col is! Map<String, dynamic>) {
      err(r'$.collection', 'required');
    } else {
      final id = req(col, 'id', r'$.collection');
      if (id != null && !_slug.hasMatch(id)) err(r'$.collection.id', 'must be a lowercase slug, e.g. "bukhari"');
      req(col, 'name_ar', r'$.collection');
      req(col, 'name_en', r'$.collection');
      for (final k in ['name_so', 'compiler_ar', 'compiler_en', 'edition', 'publisher', 'source_reference']) {
        opt(col, k, r'$.collection');
      }
      url(col, 'source_url', r'$.collection');
    }

    final scheme = root['numbering_scheme'];
    if (scheme is! String || scheme.trim().isEmpty) {
      err(r'$.numbering_scheme', 'required: which numbering the hadith numbers follow');
    }

    // Books
    final bookNumbers = <String>{};
    final bookOrders = <int>{};
    for (final (i, b) in list('books', r'$').indexed) {
      final p = '\$.books[$i]';
      final n = req(b, 'book_number', p);
      if (n != null && !bookNumbers.add(n)) err('$p.book_number', 'duplicate book_number "$n"');
      req(b, 'title_ar', p);
      opt(b, 'title_en', p);
      opt(b, 'title_so', p);
      final o = posInt(b, 'sort_order', p);
      if (o != null && !bookOrders.add(o)) err('$p.sort_order', 'duplicate sort_order $o');
      r.books++;
    }

    // Chapters
    final chapterKeys = <String>{};
    for (final (i, c) in list('chapters', r'$', required: false).indexed) {
      final p = '\$.chapters[$i]';
      final b = req(c, 'book_number', p);
      if (b != null && !bookNumbers.contains(b)) err('$p.book_number', 'unknown book "$b"');
      final o = posInt(c, 'sort_order', p);
      if (b != null && o != null && !chapterKeys.add('$b|$o')) {
        err('$p.sort_order', 'duplicate chapter $o in book "$b"');
      }
      opt(c, 'chapter_number', p);
      req(c, 'title_ar', p);
      opt(c, 'title_en', p);
      opt(c, 'title_so', p);
      r.chapters++;
    }

    // Hadiths
    final numbers = <String>{};
    final positions = <int>{};
    final identifiers = <String>{};
    final textIndex = <String, String>{};
    final hadiths = list('hadiths', r'$');
    if (hadiths.isEmpty) err(r'$.hadiths', 'no records');
    for (final (i, h) in hadiths.indexed) {
      final p = '\$.hadiths[$i]';
      final number = req(h, 'hadith_number', p);
      if (number != null && !numbers.add(number)) err('$p.hadith_number', 'duplicate hadith_number "$number"');
      final pos = posInt(h, 'source_position', p);
      if (pos != null && !positions.add(pos)) err('$p.source_position', 'duplicate source_position $pos');
      final ident = opt(h, 'source_identifier', p);
      if (ident == null) {
        warn('$p.source_identifier', 'missing: the record cannot be traced back to its source row');
      } else if (!identifiers.add(ident)) {
        err('$p.source_identifier', 'duplicate source_identifier "$ident"');
      }

      final book = opt(h, 'book_number', p);
      final chapterSort = posInt(h, 'chapter_sort', p, required: false);
      if (book != null && !bookNumbers.contains(book)) err('$p.book_number', 'unknown book "$book"');
      if (chapterSort != null) {
        if (book == null) {
          err('$p.chapter_sort', 'a chapter needs book_number');
        } else if (!chapterKeys.contains('$book|$chapterSort')) {
          err('$p.chapter_sort', 'unknown chapter $chapterSort in book "$book"');
        }
      }

      final arabic = req(h, 'arabic_text', p);
      if (arabic != null) checkText(arabic, '$p.arabic_text', arabicScript: true);
      final vowelized = opt(h, 'arabic_text_vowelized', p);
      if (vowelized != null) checkText(vowelized, '$p.arabic_text_vowelized', arabicScript: true);

      opt(h, 'narrator_text_ar', p);
      opt(h, 'normalization_notes', p);
      url(h, 'source_url', p);
      if (h.containsKey('vowelized_verified') || h.containsKey('status')) {
        err(p, 'imports may not set status or vowelized_verified; verification happens in review');
      }
      if (arabic != null) {
        final key = normalizeArabic(arabic).replaceAll(RegExp(r'\s+'), ' ').trim();
        final first = textIndex[key];
        if (first != null) {
          warn('$p.arabic_text', 'same text as $first (possible duplicate — check before review)');
        } else {
          textIndex[key] = p;
        }
      }

      final cats = h['categories'];
      if (cats != null) {
        if (cats is! List || cats.any((c) => c is! String || !_slug.hasMatch(c))) {
          err('$p.categories', 'must be a list of category slugs');
        }
      }

      final primaryLangs = <String>{};
      final transKeys = <String>{};
      final trans = h['translations'];
      if (trans != null && trans is! List) err('$p.translations', 'must be a list');
      for (final (j, t) in (trans is List ? trans : const []).indexed) {
        final tp = '$p.translations[$j]';
        if (t is! Map<String, dynamic>) {
          err(tp, 'must be an object');
          continue;
        }
        final lang = (t['language'] as String?) ?? 'so';
        if (!_lang.hasMatch(lang)) err('$tp.language', 'must be an ISO code like "so"');
        final text = req(t, 'text', tp);
        if (text != null) checkText(text, '$tp.text', arabicScript: false, somali: lang == 'so');
        final translator = req(t, 'translator', tp);
        final source = req(t, 'translation_source', tp);
        url(t, 'source_url', tp);
        if (t['is_primary'] == true && !primaryLangs.add(lang)) err('$tp.is_primary', 'only one primary per language');
        if (translator != null && source != null && !transKeys.add('$lang|$translator|$source')) {
          err(tp, 'duplicate translation (same language, translator and source)');
        }
        if (t.containsKey('status')) err(tp, 'imports may not set status');
        r.translations++;
      }

      final gradeKeys = <String>{};
      final grads = h['gradings'];
      if (grads != null && grads is! List) err('$p.gradings', 'must be a list');
      for (final (j, g) in (grads is List ? grads : const []).indexed) {
        final gp = '$p.gradings[$j]';
        if (g is! Map<String, dynamic>) {
          err(gp, 'must be an object');
          continue;
        }
        final grade = g['grade'];
        if (grade is! String || !gradeKinds.contains(grade)) {
          err('$gp.grade', 'must be one of ${gradeKinds.join(', ')}');
        }
        final label = opt(g, 'grade_label_ar', gp);
        if (grade == 'other' && label == null) err('$gp.grade_label_ar', 'required when grade is "other"');
        final scholar = req(g, 'scholar', gp);
        final ref = req(g, 'source_reference', gp);
        url(g, 'source_url', gp);
        opt(g, 'disagreement_notes', gp);
        if (scholar != null && ref != null && !gradeKeys.add('$scholar|$ref')) {
          err(gp, 'duplicate grading (same scholar and reference)');
        }
        if (g.containsKey('status')) err(gp, 'imports may not set status');
        r.gradings++;
      }
      if (trans is! List || trans.isEmpty) r.withoutTranslation++;
      if (grads is! List || grads.isEmpty) r.withoutGrading++;
      if (h["source_url"] == null && h["source_identifier"] == null) {
        r.withoutSourceReference++;
        warn(p, "no source_url or source_identifier: the record will need source verification");
      }
      r.hadiths++;
    }
  }
}
