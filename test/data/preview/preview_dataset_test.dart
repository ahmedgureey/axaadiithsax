import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/data/models/hadith.dart';
import 'package:xadiithapp/data/preview/preview_dataset.dart';

// TEST ONLY fixture — not hadith.
Map<String, dynamic> _file() => {
  'format': 'xadiith-import/1',
  'provenance': {'source_name': 'TEST source', 'source_edition': 'v1'},
  'collection': {'id': 'testcol', 'name_ar': 'مجموعة', 'name_en': 'Test Collection'},
  'hadiths': [
    {'hadith_number': '2', 'source_position': 2, 'arabic_text': 'نَصٌّ ٢'},
    {'hadith_number': '1', 'source_position': 1, 'arabic_text': 'نَصٌّ ١', 'source_url': 'https://x.test/1'},
    {'hadith_number': '3', 'source_position': 3, 'arabic_text': '   '},
  ],
};

void main() {
  test('parses records unchanged, in order, marked unverified, nothing invented', () {
    final d = PreviewDataset.parse(_file())!;
    expect(d.hadiths.map((h) => h.arabicText), ['نَصٌّ ١', 'نَصٌّ ٢'], reason: 'empty text skipped, Arabic untouched');
    expect(d.hadiths.every((h) => h.sourceStatus == SourceStatus.demo), isTrue);
    expect(d.hadiths.every((h) => h.somaliText == null && h.gradings.isEmpty && h.grade == null), isTrue);
    expect(d.hadiths.first.id, 'testcol-1');
    expect(d.hadiths.first.chapterId, d.chapter.id);
    expect(d.hadiths.first.source, 'TEST source — v1');
    expect(d.book.isVerified, isFalse);
  });

  test('unknown format is rejected', () {
    expect(PreviewDataset.parse({..._file(), 'format': 'other'}), isNull);
  });

  test('loader returns null on missing file or bad JSON', () async {
    expect(await loadPreviewDataset((_) async => null, base: Uri.parse('http://localhost/')), isNull);
    expect(await loadPreviewDataset((_) async => '{oops', base: Uri.parse('http://localhost/')), isNull);
  });

  test('preview is off unless explicitly enabled', () => expect(PreviewDataset.enabled, isFalse));
}
