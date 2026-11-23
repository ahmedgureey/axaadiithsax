/// Converts one edition of fawazahmed0/hadith-api (JSON as served by
/// jsDelivr) into the `xadiith-import/1` format.
///
/// Rules:
/// * Arabic text is copied byte-for-byte. Nothing is added or "fixed".
/// * Gradings are created ONLY from the edition's structured `grades`
///   entries (scholar + grade). Phrases inside the text such as "رواه
///   الترمذي وقال حسن صحيح" belong to the text and are never turned into
///   grading records.
/// * No translation is produced (the dataset has no Somali edition).
/// * Each record keeps its source identifier, number and a commit-pinned URL.
/// Records without text are skipped and reported.
library;

import '../dataset.dart';

class AdapterResult {
  AdapterResult(this.dataset, this.skipped);

  final Map<String, dynamic> dataset;

  /// (hadithnumber, reason) of records left out.
  final List<(String, String)> skipped;
}

/// Maps dataset grade words to the database enum. Unknown wording → `other`
/// with the original kept in `grade_label_ar`.
String gradeKind(String raw) {
  final g = raw.toLowerCase().replaceAll(RegExp(r"[^a-z ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (g.contains('mawdu') || g.contains('fabricat')) return 'mawdu';
  if (g.contains('daif jiddan') || g.contains('very weak')) return 'daif_jiddan';
  if (g.startsWith('hasan sahih')) return 'hasan_sahih';
  if (g == 'sahih' || g.startsWith('sahih ')) return 'sahih';
  if (g == 'hasan' || g.startsWith('hasan ')) return 'hasan';
  if (g == 'daif' || g.startsWith('daif ') || g.contains('da if') || g == 'weak') return 'daif';
  return 'other';
}

AdapterResult convertFawazahmed0({
  required Map<String, dynamic> edition,
  required String editionKey, // e.g. 'ara-nawawi'
  required String commit, // full git sha the file was taken from
  required String collectionId, // e.g. 'nawawi40'
  required String collectionNameAr, // supplied by the operator
  String? collectionNameEn,
  String? compilerEn,
  required String retrievedAt, // ISO date
  /// Opt-in, documented formatting fix: HTML `<br>` line breaks in the
  /// source become new lines; each affected record gets normalization_notes.
  bool brToNewline = false,
}) {
  final base = 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@$commit/editions/$editionKey';
  final meta = (edition['metadata'] as Map?) ?? const {};
  final records = (edition['hadiths'] as List?) ?? const [];
  final skipped = <(String, String)>[];
  final hadiths = <Map<String, dynamic>>[];

  for (final raw in records) {
    if (raw is! Map) continue;
    final number = raw['hadithnumber'];
    final text = raw['text'];
    final label = '$number';
    if (number is! num || number <= 0) {
      skipped.add((label, 'no positive hadithnumber'));
      continue;
    }
    if (text is! String || text.trim().isEmpty) {
      skipped.add((label, 'empty text'));
      continue;
    }
    final n = number % 1 == 0 ? number.toInt().toString() : number.toString();
    var arabic = text;
    String? note;
    final br = RegExp(r'<br\s*/?>', caseSensitive: false);
    final breaks = br.allMatches(text).length;
    if (brToNewline && breaks > 0) {
      arabic = text.replaceAll(br, '\n');
      note = 'Source text contained $breaks HTML <br> line break(s); converted to new lines. No other change.';
    }
    final arabicNumber = raw['arabicnumber'];
    final grades = [
      for (final g in (raw['grades'] as List? ?? const []))
        if (g is Map && g['name'] is String && g['grade'] is String && (g['grade'] as String).trim().isNotEmpty)
          {
            'grade': gradeKind(g['grade'] as String),
            'grade_label_ar': g['grade'],
            'scholar': g['name'],
            'source_reference':
                'fawazahmed0/hadith-api $editionKey (commit ${commit.substring(0, 7)}), grade by ${g['name']} '
                '— see the dataset References.md for the original book',
          },
    ];
    hadiths.add({
      'source_identifier':
          '$editionKey/$n${arabicNumber != null && '$arabicNumber' != n ? ' (arabicnumber $arabicNumber)' : ''}',
      'hadith_number': n,
      'source_position': hadiths.length + 1,
      'arabic_text': arabic, // as in the source file (see normalization_notes)
      'normalization_notes': ?note,
      'source_url': '$base/$n.json',
      'gradings': grades,
    });
  }

  return AdapterResult({
    'format': datasetFormat,
    'provenance': {
      'source_name': 'fawazahmed0/hadith-api — edition $editionKey',
      'source_edition': 'git $commit (branch 1)',
      'source_url': '$base.json',
      'license':
          'Unlicense (as stated by the repository). The dataset does not document which printed edition the '
          'Arabic text comes from: every record requires source verification against a printed edition.',
      'source_language': 'ar',
      'retrieved_at': retrievedAt,
    },
    'collection': {
      'id': collectionId,
      'name_ar': collectionNameAr,
      'name_en': collectionNameEn ?? (meta['name'] as String? ?? collectionId),
      'compiler_en': ?compilerEn,
      'source_reference': 'fawazahmed0/hadith-api, edition $editionKey',
      'source_url': 'https://github.com/fawazahmed0/hadith-api',
    },
    'numbering_scheme': 'fawazahmed0:$editionKey:hadithnumber',
    'books': const <Map<String, dynamic>>[],
    'hadiths': hadiths,
  }, skipped);
}
