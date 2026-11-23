import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/data/bundled/bundled_dataset.dart';
import 'package:xadiithapp/data/models/hadith.dart';

// TEST ONLY fixture — not hadith.
Map<String, dynamic> _file() => {
  'format': 'xadiith-import/1',
  'provenance': {'source_name': 'TEST source', 'source_edition': 'v1'},
  'collection': {'id': 'testcol', 'name_ar': 'مجموعة', 'name_en': 'Test Collection'},
  'hadiths': [
    {'hadith_number': '2', 'source_position': 2, 'arabic_text': 'نَصٌّ ٢'},
    {
      'hadith_number': '1',
      'source_position': 1,
      'arabic_text': 'نَصٌّ ١',
      'translations': [
        {'language': 'en', 'text': 'EN', 'translator': 'x', 'translation_source': 'x', 'is_primary': true},
        {
          'language': 'so',
          'text': 'TEST ONLY Soomaali',
          'translator': 'T',
          'translation_source': 'S',
          'is_primary': true,
        },
      ],
    },
    {'hadith_number': '3', 'source_position': 3, 'arabic_text': '   '},
  ],
};

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);
  final Map<String, String> files;
  @override
  Future<ByteData> load(String key) async {
    final v = files[key];
    if (v == null) throw StateError('missing $key');
    return ByteData.sublistView(utf8.encode(v));
  }
}

void main() {
  test('parses records unchanged and in order, as real sourced content (no "Tusaale")', () {
    final d = BundledDataset.parse(_file())!;
    expect(d.hadiths.map((h) => h.arabicText), ['نَصٌّ ١', 'نَصٌّ ٢'], reason: 'empty text skipped, Arabic untouched');
    expect(d.hadiths.every((h) => h.sourceStatus == SourceStatus.sourced && !h.isDemo), isTrue);
    expect(d.hadiths.every((h) => !h.isVerified), isTrue, reason: 'never claims scholarly verification');
    expect(d.book.isDemo, isFalse);
    expect(d.book.description, isNot(contains('localhost')));
    expect(d.hadiths.first.somaliText, 'TEST ONLY Soomaali');
    expect(d.hadiths.first.translator, 'T');
    expect(d.hadiths[1].somaliText, isNull, reason: 'no translation → none invented');
    expect(d.hadiths.every((h) => h.gradings.isEmpty && h.grade == null), isTrue);
  });

  test('unknown format is rejected; missing or broken asset → null', () async {
    expect(BundledDataset.parse({..._file(), 'format': 'other'}), isNull);
    expect(await loadBundledDataset(_MapBundle({})), isNull);
    expect(await loadBundledDataset(_MapBundle({BundledDataset.asset: '{oops'})), isNull);
  });

  test('the shipped asset: 42 an-Nawawi hadith, each with Arabic and Somali, declared in pubspec', () async {
    final text = File(BundledDataset.asset).readAsStringSync();
    final d = (await loadBundledDataset(_MapBundle({BundledDataset.asset: text})))!;
    expect(d.hadiths, hasLength(42));
    expect(d.hadiths.map((h) => h.numberLabel), [for (var i = 1; i <= 42; i++) '$i']);
    expect(d.hadiths.every((h) => h.arabicText.trim().isNotEmpty && h.hasTranslation), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('- ${BundledDataset.asset}'));
  });
}
