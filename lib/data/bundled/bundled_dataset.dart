import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/chapter.dart';
import '../models/hadith.dart';
import '../models/hadith_book.dart';
import '../models/study_notes.dart';

/// Hadith collections that ship inside the app (assets), so they work online
/// and offline without any database.
///
/// The file format is the import format (`xadiith-import/1`, see
/// `tool/hadith_import/`). Arabic text is shown exactly as in the file. A
/// Somali translation is used when the record has one (`translations[]`,
/// language `so`), with its translator and source. No grade is added (the
/// file has none). Records are [SourceStatus.sourced]: real text from a
/// documented source, not placeholder content.
abstract final class BundledDataset {
  /// Asset path of the bundled an-Nawawi collection.
  static const asset = 'assets/data/nawawi40.json';

  /// Parses an import file. Returns null when the format is not recognised;
  /// records without a number/Arabic text are skipped.
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
      final somali = _somaliTranslation(r['translations']);
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
          somaliText: somali?['text'] as String?,
          translator: somali?['translator'] as String?,
          translationSource: somali?['translation_source'] as String?,
          sourceStatus: SourceStatus.sourced,
        ),
      );
    }
    hadiths.sort((a, b) => a.number.compareTo(b.number));
    final translated = hadiths.where((h) => h.hasTranslation).length;
    final book = HadithBook(
      id: id,
      nameSomali: nameEn,
      nameArabic: nameAr,
      author: (collection['compiler_en'] as String?) ?? '',
      description: translated == hadiths.length
          ? 'Kitaabka Imaam an-Nawawi: ${hadiths.length} xadiis oo Carabi ah iyo tarjumaaddooda Af-Soomaaliga.'
          : 'Kitaabka Imaam an-Nawawi: ${hadiths.length} xadiis oo Carabi ah.',
      isSourced: true,
    );
    return (book: book, chapter: chapter, hadiths: hadiths);
  }
}

/// Loads and parses the bundled collection; null when it is missing or invalid.
Future<({HadithBook book, Chapter chapter, List<Hadith> hadiths})?> loadBundledDataset(AssetBundle bundle) async {
  try {
    final decoded = jsonDecode(await bundle.loadString(BundledDataset.asset));
    return decoded is Map<String, dynamic> ? BundledDataset.parse(decoded) : null;
  } catch (e) {
    debugPrint('Bundled dataset not loaded: $e');
    return null;
  }
}

/// Asset with quiz/study notes for the bundled collection.
const bundledStudyAsset = 'assets/data/nawawi40_study.json';

/// Parses study notes (`xadiith-study/1`) into a map keyed by hadith id
/// (`<collection>-<number>`, the ids [BundledDataset.parse] creates).
Map<String, StudyNotes> parseStudyNotes(Map<String, dynamic> json) {
  if (json['format'] != 'xadiith-study/1') return const {};
  final collection = json['collection'];
  final hadiths = json['hadiths'];
  if (collection is! String || hadiths is! Map) return const {};
  final result = <String, StudyNotes>{};
  hadiths.forEach((number, value) {
    if (value is! Map) return;
    final companion = value['companion'];
    final topic = value['topic'];
    if (companion is! String || companion.trim().isEmpty || topic is! String || topic.trim().isEmpty) return;
    final c = value['collection'];
    result['$collection-$number'] = StudyNotes(
      companion: companion,
      topic: topic,
      collection: c is String && c.trim().isNotEmpty ? c : null,
      words: [
        for (final w in (value['words'] as List? ?? const []))
          if (w is Map && w['ar'] is String && w['so'] is String)
            StudyWord(arabic: w['ar'] as String, somali: w['so'] as String),
      ],
    );
  });
  return result;
}

/// Loads the study notes; empty when the asset is missing or invalid.
Future<Map<String, StudyNotes>> loadBundledStudy(AssetBundle bundle) async {
  try {
    final decoded = jsonDecode(await bundle.loadString(bundledStudyAsset));
    return decoded is Map<String, dynamic> ? parseStudyNotes(decoded) : const {};
  } catch (e) {
    debugPrint('Study notes not loaded: $e');
    return const {};
  }
}

/// The primary Somali translation of a record (or the first one), if any.
Map<String, dynamic>? _somaliTranslation(Object? translations) {
  if (translations is! List) return null;
  final somali = [
    for (final t in translations)
      if (t is Map<String, dynamic> &&
          t['language'] == 'so' &&
          t['text'] is String &&
          (t['text'] as String).trim().isNotEmpty)
        t,
  ];
  if (somali.isEmpty) return null;
  return somali.firstWhere((t) => t['is_primary'] == true, orElse: () => somali.first);
}
