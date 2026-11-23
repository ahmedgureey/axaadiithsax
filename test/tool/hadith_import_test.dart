import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/hadith_import/dataset.dart';
import '../../tool/hadith_import/importer.dart';

// Neutral test strings — NOT hadith text.
const _arabic = 'نَصٌّ لِلِاخْتِبَارِ فَقَطْ';

Map<String, dynamic> _valid({List<Map<String, dynamic>>? hadiths}) => {
  'format': datasetFormat,
  'provenance': {'source_name': 'TEST SOURCE', 'license': 'TEST LICENCE', 'source_url': 'https://example.test/data'},
  'collection': {'id': 'test-col', 'name_ar': 'اختبار', 'name_en': 'Test'},
  'numbering_scheme': 'test-scheme',
  'books': [
    {'book_number': '1', 'title_ar': 'كتاب', 'sort_order': 1},
  ],
  'chapters': [
    {'book_number': '1', 'sort_order': 1, 'title_ar': 'باب'},
  ],
  'hadiths':
      hadiths ??
      [
        {
          'source_identifier': 'src-1',
          'hadith_number': '1',
          'source_position': 1,
          'book_number': '1',
          'chapter_sort': 1,
          'arabic_text': _arabic,
          'categories': ['iman'],
          'translations': [
            {'text': 'TEST ONLY', 'translator': 'T', 'translation_source': 'S', 'is_primary': true},
          ],
          'gradings': [
            {'grade': 'sahih', 'scholar': 'TEST SCHOLAR', 'source_reference': 'TEST REF'},
          ],
        },
        {'source_identifier': 'src-2', 'hadith_number': '2a', 'source_position': 2, 'arabic_text': 'نص آخر'},
      ],
};

(ValidationReport, Dataset?) _parse(Map<String, dynamic> json) => Dataset.parse(jsonEncode(json));

List<String> _paths(ValidationReport r) => [for (final e in r.errors) e.path];

class FakeRest implements RestClient {
  FakeRest({this.existingNumbers = const {}, this.failHadithBatchAt});

  final Set<String> existingNumbers;
  final int? failHadithBatchAt;
  final inserts = <(String, List<Map<String, dynamic>>, String?, bool)>[];
  final batchUpdates = <Map<String, dynamic>>[];
  int _ids = 0;
  int _hadithCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> insert(
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
    bool ignoreDuplicates = false,
  }) async {
    inserts.add((table, rows, onConflict, ignoreDuplicates));
    if (table == 'hadiths') {
      if (failHadithBatchAt == _hadithCalls++) throw Exception('network');
      return [
        for (final r in rows)
          if (!existingNumbers.contains(r['hadith_number'])) {...r, 'id': 'h${_ids++}'},
      ];
    }
    return [
      for (final r in rows) {...r, 'id': '${table}_${_ids++}'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> select(String table, Map<String, String> query) async => switch (table) {
    'books' => [
      {'id': 'book-1', 'book_number': '1'},
    ],
    'chapters' => [
      {'id': 'chap-1', 'sort_order': 1},
    ],
    'categories' => [
      {'id': 'iman'},
    ],
    _ => [],
  };

  @override
  Future<void> updateBatch(String batchId, Map<String, dynamic> values) async => batchUpdates.add(values);

  List<Map<String, dynamic>> rowsFor(String table) => [
    for (final i in inserts)
      if (i.$1 == table) ...i.$2,
  ];
}

void main() {
  group('Validator', () {
    test('a complete dataset passes', () {
      final (r, d) = _parse(_valid());
      expect(r.errors, isEmpty);
      expect(d, isNotNull);
      expect(r.hadiths, 2);
      expect(r.translations, 1);
      expect(r.gradings, 1);
    });

    test('invalid JSON and wrong format are rejected', () {
      expect(Dataset.parse('{not json').$1.ok, isFalse);
      final (r, _) = _parse({..._valid(), 'format': 'other'});
      expect(_paths(r), contains(r'$.format'));
    });

    test('provenance and licence are required', () {
      final (r, d) = _parse({
        ..._valid(),
        'provenance': {'source_name': 'X'},
      });
      expect(d, isNull);
      expect(_paths(r), contains(r'$.provenance.license'));
    });

    test('template placeholders are rejected', () {
      final json = _valid();
      (json['collection'] as Map)['name_ar'] = '<<Arabic name of the collection>>';
      expect(_paths(_parse(json).$1), contains(r'$.collection.name_ar'));
    });

    test('duplicate numbers, positions and identifiers are errors', () {
      final (r, _) = _parse(
        _valid(
          hadiths: [
            {'source_identifier': 'a', 'hadith_number': '1', 'source_position': 1, 'arabic_text': 'نص'},
            {'source_identifier': 'a', 'hadith_number': '1', 'source_position': 1, 'arabic_text': 'نص ب'},
          ],
        ),
      );
      expect(
        _paths(r),
        containsAll([
          r'$.hadiths[1].hadith_number',
          r'$.hadiths[1].source_position',
          r'$.hadiths[1].source_identifier',
        ]),
      );
    });

    test('references must exist: unknown book / chapter, chapter without book', () {
      final (r, _) = _parse(
        _valid(
          hadiths: [
            {'hadith_number': '1', 'source_position': 1, 'arabic_text': 'نص', 'book_number': '9'},
            {'hadith_number': '2', 'source_position': 2, 'arabic_text': 'نص ب', 'book_number': '1', 'chapter_sort': 5},
            {'hadith_number': '3', 'source_position': 3, 'arabic_text': 'نص ج', 'chapter_sort': 1},
          ],
        ),
      );
      expect(
        _paths(r),
        containsAll([r'$.hadiths[0].book_number', r'$.hadiths[1].chapter_sort', r'$.hadiths[2].chapter_sort']),
      );
    });

    test('required fields: empty Arabic, missing numbers', () {
      final (r, _) = _parse(
        _valid(
          hadiths: [
            {'hadith_number': '1', 'source_position': 1, 'arabic_text': '   '},
            {'source_position': 0, 'arabic_text': 'نص'},
          ],
        ),
      );
      expect(
        _paths(r),
        containsAll([r'$.hadiths[0].arabic_text', r'$.hadiths[1].hadith_number', r'$.hadiths[1].source_position']),
      );
    });

    test('imports cannot claim verification', () {
      final (r, _) = _parse(
        _valid(
          hadiths: [
            {'hadith_number': '1', 'source_position': 1, 'arabic_text': 'نص', 'status': 'published'},
            {
              'hadith_number': '2',
              'source_position': 2,
              'arabic_text': 'نص ب',
              'gradings': [
                {'grade': 'sahih', 'scholar': 'S', 'source_reference': 'R', 'status': 'verified'},
              ],
            },
          ],
        ),
      );
      expect(_paths(r), containsAll([r'$.hadiths[0]', r'$.hadiths[1].gradings[0]']));
    });

    test('gradings: allowed kinds, "other" needs label, no duplicate scholar+reference', () {
      final (r, _) = _parse(
        _valid(
          hadiths: [
            {
              'hadith_number': '1',
              'source_position': 1,
              'arabic_text': 'نص',
              'gradings': [
                {'grade': 'strong', 'scholar': 'A', 'source_reference': 'R'},
                {'grade': 'other', 'scholar': 'B', 'source_reference': 'R'},
                {'grade': 'hasan', 'scholar': 'C', 'source_reference': 'R'},
                {'grade': 'daif', 'scholar': 'C', 'source_reference': 'R'},
              ],
            },
          ],
        ),
      );
      expect(
        _paths(r),
        containsAll([
          r'$.hadiths[0].gradings[0].grade',
          r'$.hadiths[0].gradings[1].grade_label_ar',
          r'$.hadiths[0].gradings[3]',
        ]),
      );
    });

    test('translations: one primary per language, required translator/source', () {
      final (r, _) = _parse(
        _valid(
          hadiths: [
            {
              'hadith_number': '1',
              'source_position': 1,
              'arabic_text': 'نص',
              'translations': [
                {'text': 'a', 'translator': 'T', 'translation_source': 'S', 'is_primary': true},
                {'text': 'b', 'translator': 'U', 'translation_source': 'S', 'is_primary': true},
                {'text': 'c', 'translation_source': 'S'},
              ],
            },
          ],
        ),
      );
      expect(
        _paths(r),
        containsAll([r'$.hadiths[0].translations[1].is_primary', r'$.hadiths[0].translations[2].translator']),
      );
    });

    test('identical texts (ignoring tashkeel) are reported as possible duplicates', () {
      final (r, d) = _parse(
        _valid(
          hadiths: [
            {'source_identifier': 'a', 'hadith_number': '1', 'source_position': 1, 'arabic_text': 'إِنَّمَا نَصٌّ'},
            {'source_identifier': 'b', 'hadith_number': '2', 'source_position': 2, 'arabic_text': 'انما نص'},
          ],
        ),
      );
      expect(d, isNotNull); // a warning, not an error: editions may repeat texts
      expect([for (final w in r.warnings) w.path], contains(r'$.hadiths[1].arabic_text'));
    });

    test('normalizeArabic matches the database rule', () {
      expect(normalizeArabic('إِنَّمَا الْأَعْمَالُ'), 'انما الاعمال');
      expect(normalizeArabic('مُصْطَفَىٰ'), 'مصطفي');
      expect(normalizeArabic('رَحْمَةٌ'), 'رحمه');
    });
  });

  group('Importer', () {
    test('inserts with ignore-duplicates, tags provenance, keeps Arabic exact', () async {
      final (_, d) = _parse(_valid());
      final rest = FakeRest();
      final res = await Importer(rest).run(d!, fileName: 'f.json', fileSha256: 'a' * 64);

      final batch = rest.rowsFor('import_batches').single;
      expect(batch['license'], 'TEST LICENCE');
      expect(batch['file_sha256'], 'a' * 64);

      final hadiths = rest.rowsFor('hadiths');
      expect(hadiths.first['arabic_text'], _arabic);
      expect(utf8.encode(hadiths.first['arabic_text'] as String), utf8.encode(_arabic));
      expect(hadiths.every((h) => h['import_batch_id'] == res.batchId), isTrue);
      expect(hadiths.every((h) => h['vowelized_verified'] == false && !h.containsKey('status')), isTrue);
      expect(hadiths.first['chapter_id'], 'chap-1');
      expect(hadiths.first['book_id'], 'book-1');

      final hadithCall = rest.inserts.firstWhere((i) => i.$1 == 'hadiths');
      expect(hadithCall.$3, 'collection_id,numbering_scheme,hadith_number');
      expect(hadithCall.$4, isTrue);
      expect(rest.inserts.every((i) => i.$4 || i.$1 == 'import_batches'), isTrue, reason: 'never overwrite');

      expect(res.counts['hadiths_inserted'], 2);
      expect(res.counts['translations_inserted'], 1);
      expect(res.counts['gradings_inserted'], 1);
      expect(res.counts['categories_linked'], 1);
      expect(rest.rowsFor('translations').single['import_batch_id'], res.batchId);
      expect(rest.batchUpdates.last['state'], 'completed');
    });

    test('bulk rows share one key set (PostgREST takes columns from the first row)', () async {
      final (_, d) = _parse(_valid());
      final rest = FakeRest();
      await Importer(rest).run(d!, fileName: 'f.json', fileSha256: 'b' * 64);
      for (final table in ['hadiths', 'books', 'chapters', 'translations', 'gradings']) {
        final rows = rest.rowsFor(table);
        final keys = rows.first.keys.toSet();
        expect(rows.every((r) => r.keys.toSet().containsAll(keys) && keys.containsAll(r.keys)), isTrue, reason: table);
      }
    });

    test('existing records are skipped and their children untouched (resume)', () async {
      final (_, d) = _parse(_valid());
      final rest = FakeRest(existingNumbers: {'1'});
      final res = await Importer(rest).run(d!, fileName: 'f.json', fileSha256: 'c' * 64);
      expect(res.counts['hadiths_inserted'], 1);
      expect(res.counts['hadiths_skipped_existing'], 1);
      expect(rest.rowsFor('translations'), isEmpty);
      expect(rest.rowsFor('gradings'), isEmpty);
    });

    test('batches, failed batch is recorded and the run continues', () async {
      final many = [
        for (var i = 1; i <= 5; i++)
          {'source_identifier': 's$i', 'hadith_number': '$i', 'source_position': i, 'arabic_text': 'نص $i'},
      ];
      final (_, d) = _parse(_valid(hadiths: many));
      final rest = FakeRest(failHadithBatchAt: 1);
      final res = await Importer(rest, batchSize: 2).run(d!, fileName: 'f.json', fileSha256: 'd' * 64);
      expect(rest.inserts.where((i) => i.$1 == 'hadiths'), hasLength(3));
      expect(res.counts['hadiths_inserted'], 3);
      expect(res.errors.single['stage'], 'hadiths');
      expect(rest.batchUpdates.last['state'], 'failed');
    });

    test('unknown category is reported, not created', () async {
      final json = _valid();
      ((json['hadiths'] as List).first as Map)['categories'] = ['nope'];
      final (_, d) = _parse(json);
      final rest = FakeRest();
      final res = await Importer(rest).run(d!, fileName: 'f.json', fileSha256: 'e' * 64);
      expect(rest.rowsFor('hadith_categories'), isEmpty);
      expect(res.errors.single['message'], contains('nope'));
    });
  });

  group('Content checks (STEP 05)', () {
    Map<String, dynamic> one(Map<String, dynamic> h) => _valid(
      hadiths: [
        {'source_identifier': 's1', 'hadith_number': '1', 'source_position': 1, ...h},
      ],
    );
    List<String> errs(Map<String, dynamic> json) => [for (final e in _parse(json).$1.errors) '${e.path}: ${e.message}'];
    List<String> warns(Map<String, dynamic> json) => [
      for (final w in _parse(json).$1.warnings) '${w.path}: ${w.message}',
    ];

    test('HTML markup and entities are rejected', () {
      expect(errs(one({'arabic_text': '<p>نص للاختبار فقط هنا</p>'})).join(), contains('markup'));
      expect(errs(one({'arabic_text': 'نص للاختبار&nbsp;فقط هنا'})).join(), contains('entity'));
    });

    test('broken encoding is rejected: replacement char, control chars, mojibake', () {
      expect(errs(one({'arabic_text': 'نص للاختبار � فقط'})).join(), contains('replacement'));
      expect(errs(one({'arabic_text': 'نص للاختبار\u0007 فقط هنا'})).join(), contains('control'));
      // "نص" encoded as UTF-8 and wrongly decoded as Latin-1
      expect(errs(one({'arabic_text': 'Ù†Øµ Ù„Ù„Ø§Ø®ØªØ¨Ø§Ø±'})).join(), contains('mojibake'));
    });

    test('Arabic field must contain Arabic letters; very short text is flagged', () {
      expect(errs(one({'arabic_text': 'only latin text here'})).join(), contains('no Arabic letters'));
      expect(warns(one({'arabic_text': 'نص'})).join(), contains('truncated'));
    });

    test('ellipsis at the end is flagged as possible truncation', () {
      expect(warns(one({'arabic_text': 'نص للاختبار فقط هنا وهناك…'})).join(), contains('ellipsis'));
    });

    test('Somali translation checks: script and markup', () {
      final json = one({
        'arabic_text': 'نص للاختبار فقط هنا وهناك',
        'translations': [
          {'text': 'نص عربي', 'translator': 'T', 'translation_source': 'S'},
        ],
      });
      final w = warns(json).join('\n');
      expect(w, contains('no Latin letters'));
      expect(w, contains('Arabic script'));
      final bad = one({
        'arabic_text': 'نص للاختبار فقط هنا وهناك',
        'translations': [
          {'text': '<b>TEST ONLY</b>', 'translator': 'T', 'translation_source': 'S'},
        ],
      });
      expect(errs(bad).join(), contains('markup'));
    });

    test('Somali text with Somali letters (dh, kh, apostrophe) is preserved and accepted', () {
      const somali = "TEST ONLY: Dhammaan khayr, su'aal iyo ka'aan.";
      final (r, d) = _parse(
        one({
          'arabic_text': 'نص للاختبار فقط هنا وهناك',
          'translations': [
            {'text': somali, 'translator': 'T', 'translation_source': 'S'},
          ],
        }),
      );
      expect(r.errors, isEmpty);
      expect(((d!.hadiths.single['translations'] as List).single as Map)['text'], somali);
    });

    test('tashkeel survives validation byte-for-byte', () {
      const withTashkeel = 'نَصٌّ لِلِاخْتِبَارِ فَقَطْ هُنَا';
      final (_, d) = _parse(one({'arabic_text': withTashkeel, 'arabic_text_vowelized': withTashkeel}));
      expect(d!.hadiths.single['arabic_text'], withTashkeel);
      expect(utf8.encode(d.hadiths.single['arabic_text_vowelized'] as String), utf8.encode(withTashkeel));
    });

    test('missing translation / grading / source reference are counted and flagged for review', () {
      final (r, _) = _parse(
        _valid(
          hadiths: [
            {'hadith_number': '1', 'source_position': 1, 'arabic_text': 'نص للاختبار فقط هنا وهناك'},
          ],
        ),
      );
      expect(r.withoutTranslation, 1);
      expect(r.withoutGrading, 1);
      expect(r.withoutSourceReference, 1);
      expect([for (final w in r.warnings) w.message].join(), contains('source verification'));
      expect(r.toJson()['counts'], containsPair('hadiths_without_translation', 1));
    });

    test('provenance: language code and retrieval date are validated', () {
      final json = _valid();
      (json['provenance'] as Map)
        ..['source_language'] = 'Arabic'
        ..['retrieved_at'] = 'yesterday';
      final e = errs(json).join('\n');
      expect(e, contains('source_language'));
      expect(e, contains('retrieved_at'));
    });

    test('re-running an import never overwrites: only INSERT with ignore-duplicates is used', () async {
      final (_, d) = _parse(_valid());
      final first = FakeRest();
      await Importer(first).run(d!, fileName: 'f.json', fileSha256: 'f' * 64);
      // Second run: every hadith already exists (e.g. reviewed/published).
      final second = FakeRest(existingNumbers: {'1', '2a'});
      final res = await Importer(second).run(d, fileName: 'f.json', fileSha256: 'f' * 64);
      expect(res.counts['hadiths_inserted'], 0);
      expect(res.counts['hadiths_skipped_existing'], 2);
      expect(second.rowsFor('translations'), isEmpty);
      expect(second.rowsFor('gradings'), isEmpty);
      expect(second.inserts.where((i) => i.$1 != 'import_batches').every((i) => i.$4), isTrue);
    });
  });
}
