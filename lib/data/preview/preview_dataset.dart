import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/chapter.dart';
import '../models/hadith.dart';
import '../models/hadith_book.dart';

/// LOCAL PREVIEW ONLY: shows a checked import file (`xadiith-import/1`, see
/// `tool/hadith_import/`) in the web preview before the database exists.
///
/// * Enabled only with `--dart-define=XADIITH_PREVIEW_DATA=true` on a web
///   build without Supabase; the file is served from `web/preview/`
///   (git-ignored), so it never reaches an APK or production build.
/// * Every record is [SourceStatus.demo]: the UI marks it "lama xaqiijin".
///   Nothing here is verified or published.
/// * Arabic text is shown exactly as in the file. No translation and no grade
///   is added (the file has none).
abstract final class PreviewDataset {
  static const enabled = bool.fromEnvironment('XADIITH_PREVIEW_DATA');

  /// Path relative to the web app's base URL.
  static const path = 'preview/nawawi40.json';

  /// Parses an import file. Returns null when the format is not recognised;
  /// records without an id/number/Arabic text are skipped.
  static ({HadithBook book, Chapter chapter, List<Hadith> hadiths})? parse(Map<String, dynamic> json) {
    if (json['format'] != 'xadiith-import/1') return null;
    final collection = json['collection'];
    final provenance = json['provenance'];
    final records = json['hadiths'];
    if (collection is! Map || records is! List) return null;
    final id = collection['id'];
    final nameAr = collection['name_ar'];
    final nameEn = collection['name_en'];
    if (id is! String || nameAr is! String || nameEn is! String) return null;

    final sourceName = provenance is Map ? provenance['source_name'] as String? : null;
    final edition = provenance is Map ? provenance['source_edition'] as String? : null;
    final source = sourceName == null ? null : (edition == null ? sourceName : '$sourceName — $edition');

    final book = HadithBook(
      id: id,
      nameSomali: nameEn,
      nameArabic: nameAr,
      author: (collection['compiler_en'] as String?) ?? '',
      description:
          'Tijaabo localhost oo keliya: qoraalka Carabiga ah waxaa laga soo qaaday ${sourceName ?? 'isha'}, '
          'lamana xaqiijin. Tarjumaad Soomaali iyo darajo lama hayo.',
    );
    final chapter = Chapter(
      id: '$id-all',
      bookId: id,
      number: 1,
      titleSomali: 'Dhammaan xadiisyada',
      titleArabic: nameAr,
    );
    final hadiths = <Hadith>[];
    for (final r in records) {
      if (r is! Map) continue;
      final number = r['hadith_number'];
      final arabic = r['arabic_text'];
      final position = r['source_position'];
      if (number is! String || arabic is! String || arabic.trim().isEmpty || position is! num) continue;
      hadiths.add(
        Hadith(
          id: '$id-$number',
          bookId: id,
          chapterId: chapter.id,
          number: position.toInt(),
          numberLabel: number,
          arabicText: arabic,
          reference: '$nameEn, xadiiska $number',
          source: source,
          sourceUrl: r['source_url'] as String?,
          sourceStatus: SourceStatus.demo,
        ),
      );
    }
    hadiths.sort((a, b) => a.number.compareTo(b.number));
    return (book: book, chapter: chapter, hadiths: hadiths);
  }
}

/// Fetches and parses the preview file; null when disabled or unavailable.
typedef PreviewFetcher = Future<String?> Function(Uri uri);

Future<({HadithBook book, Chapter chapter, List<Hadith> hadiths})?> loadPreviewDataset(
  PreviewFetcher fetch, {
  required Uri base,
}) async {
  try {
    final text = await fetch(base.resolve(PreviewDataset.path));
    if (text == null) return null;
    final decoded = _decode(text);
    return decoded == null ? null : PreviewDataset.parse(decoded);
  } catch (e) {
    debugPrint('Preview dataset not loaded: $e');
    return null;
  }
}

Map<String, dynamic>? _decode(String text) {
  final v = jsonDecode(text);
  return v is Map<String, dynamic> ? v : null;
}
