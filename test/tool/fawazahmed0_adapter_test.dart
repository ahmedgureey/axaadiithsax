import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/hadith_import/adapters/fawazahmed0.dart';
import '../../tool/hadith_import/dataset.dart';

// Fixture in the dataset's shape. Text is TEST ONLY — not hadith.
const _sha = 'df57907be35291c91ad6a6691180e22ca9920784';
const _t1 = 'نَصٌّ لِلِاخْتِبَارِ فَقَطْ هُنَا وَهُنَاكَ ١';
const _t2 = 'نَصٌّ لِلِاخْتِبَارِ<br>سَطْرٌ ثَانٍ هُنَا وَهُنَاكَ';

Map<String, dynamic> _edition({List<Map<String, dynamic>>? hadiths}) => {
  'metadata': {'name': 'Test Collection'},
  'hadiths':
      hadiths ??
      [
        {
          'hadithnumber': 1,
          'arabicnumber': 1,
          'text': _t1,
          'grades': <Object>[],
          'reference': {'book': 1, 'hadith': 1},
        },
        {
          'hadithnumber': 2,
          'arabicnumber': 2,
          'text': _t2,
          'grades': [
            {'name': 'Scholar A', 'grade': 'Sahih'},
            {'name': 'Scholar B', 'grade': "Da'if"},
            {'name': 'Scholar C', 'grade': 'Hasan Sahih'},
            {'name': 'Scholar D', 'grade': 'Something unusual'},
          ],
          'reference': {'book': 1, 'hadith': 2},
        },
        {'hadithnumber': 3, 'arabicnumber': 3, 'text': '   ', 'grades': <Object>[]},
        {'hadithnumber': 0, 'text': 'x'},
      ],
};

AdapterResult _convert({bool br = false, Map<String, dynamic>? edition}) => convertFawazahmed0(
  edition: edition ?? _edition(),
  editionKey: 'ara-test',
  commit: _sha,
  collectionId: 'test-col',
  collectionNameAr: 'مجموعة اختبار',
  retrievedAt: '2026-11-23',
  brToNewline: br,
);

void main() {
  test('records keep number, identifier and a commit-pinned URL; empty/invalid skipped', () {
    final r = _convert(br: true);
    final h = r.dataset['hadiths'] as List;
    expect(h, hasLength(2));
    expect(h.first['hadith_number'], '1');
    expect(h.first['source_identifier'], 'ara-test/1');
    expect(h.first['source_url'], 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@$_sha/editions/ara-test/1.json');
    expect(r.skipped.map((s) => s.$1), ['3', '0']);
    final prov = r.dataset['provenance'] as Map;
    expect(prov['source_edition'], contains(_sha));
    expect(prov['license'], contains('requires source verification'));
    expect(r.dataset['numbering_scheme'], 'fawazahmed0:ara-test:hadithnumber');
  });

  test('Arabic is copied byte-for-byte when no fix is requested', () {
    final h = (_convert().dataset['hadiths'] as List);
    expect(utf8.encode(h.first['arabic_text'] as String), utf8.encode(_t1));
    expect(h[1]['arabic_text'], _t2); // <br> kept → the validator will reject it
    expect((h[1] as Map).containsKey('normalization_notes'), isFalse);
    final (report, _) = Dataset.parse(jsonEncode(_convert().dataset));
    expect(report.errors.map((e) => e.message), contains('contains HTML/markup'));
  });

  test('--br-to-newline changes only <br> and documents it', () {
    final h = (_convert(br: true).dataset['hadiths'] as List);
    expect(h[1]['arabic_text'], _t2.replaceAll('<br>', '\n'));
    expect(h[1]['normalization_notes'], contains('1 HTML <br>'));
    expect((h.first as Map).containsKey('normalization_notes'), isFalse);
    final (report, dataset) = Dataset.parse(jsonEncode(_convert(br: true).dataset));
    expect(report.errors, isEmpty);
    expect(dataset, isNotNull);
  });

  test('only structured grades become gradings, with scholar and reference; nothing inferred', () {
    final h = (_convert(br: true).dataset['hadiths'] as List);
    expect(h.first['gradings'], isEmpty); // no structured grade → none created
    final g = (h[1]['gradings'] as List).cast<Map>();
    expect(g.map((x) => '${x['scholar']}:${x['grade']}'), [
      'Scholar A:sahih',
      'Scholar B:daif',
      'Scholar C:hasan_sahih',
      'Scholar D:other',
    ]);
    expect(g.last['grade_label_ar'], 'Something unusual');
    expect(g.every((x) => (x['source_reference'] as String).contains('ara-test')), isTrue);
  });

  test('a grade phrase inside the text is NOT turned into a grading', () {
    final r = _convert(
      edition: _edition(
        hadiths: [
          {'hadithnumber': 1, 'text': 'نص للاختبار فقط رواه فلان وقال حديث حسن صحيح', 'grades': <Object>[]},
        ],
      ),
    );
    expect(((r.dataset['hadiths'] as List).single as Map)['gradings'], isEmpty);
  });

  test('no translation is ever produced', () {
    final h = (_convert(br: true).dataset['hadiths'] as List).cast<Map>();
    expect(h.every((x) => !x.containsKey('translations')), isTrue);
  });

  test('gradeKind mapping', () {
    expect(gradeKind('Sahih'), 'sahih');
    expect(gradeKind('Hasan'), 'hasan');
    expect(gradeKind("Da'if"), 'daif');
    expect(gradeKind('Daif Jiddan'), 'daif_jiddan');
    expect(gradeKind('Maudu'), 'other'); // unknown spelling stays "other" with its label
    expect(gradeKind('Mawdu'), 'mawdu');
  });
}
