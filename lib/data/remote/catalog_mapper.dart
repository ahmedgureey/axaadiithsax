import '../models/chapter.dart';
import '../models/hadith.dart';
import '../models/hadith_book.dart';
import '../models/hadith_category.dart';

/// Maps v2 rows to app models.
///
/// App vocabulary vs v2 tables: app "book" = v2 **collection**; app
/// "chapter" = v2 **book** (kitab). Records that reach the app are published
/// (RLS + views + explicit filters), so they map to [SourceStatus.verified].
/// Arabic text is passed through untouched. Rows missing required fields are
/// dropped rather than shown half-empty.
abstract final class CatalogMapper {
  static String? _s(Map<String, dynamic> r, String k) {
    final v = r[k];
    return v is String && v.trim().isNotEmpty ? v : null;
  }

  static int? _i(Map<String, dynamic> r, String k) {
    final v = r[k];
    return v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
  }

  static List<HadithBook> collections(List<Map<String, dynamic>> rows) => [
    for (final r in rows)
      if (_s(r, 'id') != null && _s(r, 'name_ar') != null && _s(r, 'name_en') != null)
        HadithBook(
          id: _s(r, 'id')!,
          // Somali name only when it was verified; otherwise the English name.
          nameSomali: (r['name_so_verified'] == true ? _s(r, 'name_so') : null) ?? _s(r, 'name_en')!,
          nameArabic: _s(r, 'name_ar')!,
          author: _s(r, 'compiler_en') ?? _s(r, 'compiler_ar') ?? '',
          description: _s(r, 'description_so') ?? _s(r, 'description_en') ?? '',
          isVerified: true,
        ),
  ];

  static List<Chapter> books(List<Map<String, dynamic>> rows, Set<String> collectionIds) => [
    for (final r in rows)
      if (_s(r, 'id') != null && collectionIds.contains(r['collection_id']) && _s(r, 'title_ar') != null)
        Chapter(
          id: _s(r, 'id')!,
          bookId: r['collection_id'] as String,
          number: _i(r, 'sort_order') ?? 0,
          titleSomali: _s(r, 'title_so') ?? _s(r, 'title_en') ?? _s(r, 'title_ar')!,
          titleArabic: _s(r, 'title_ar')!,
        ),
  ];

  static List<HadithCategory> categories(List<Map<String, dynamic>> rows) => [
    for (final r in rows)
      if (_s(r, 'id') != null && _s(r, 'name_so') != null)
        HadithCategory(
          id: _s(r, 'id')!,
          nameSomali: _s(r, 'name_so')!,
          nameArabic: _s(r, 'name_ar') ?? '',
          iconKey: _s(r, 'icon_key') ?? 'topic',
          description: _s(r, 'description') ?? '',
        ),
  ];

  /// (collection counts, book counts) from `catalog_counts`.
  static (Map<String, int>, Map<String, int>) counts(List<Map<String, dynamic>> rows) {
    final byCollection = <String, int>{};
    final byBook = <String, int>{};
    for (final r in rows) {
      final n = _i(r, 'published_count') ?? 0;
      final c = _s(r, 'collection_id');
      final b = _s(r, 'book_id');
      if (c != null) byCollection[c] = (byCollection[c] ?? 0) + n;
      if (b != null) byBook[b] = (byBook[b] ?? 0) + n;
    }
    return (byCollection, byBook);
  }

  static String _reference(String? collectionName, String number) =>
      collectionName == null ? 'Xadiiska $number' : '$collectionName, xadiiska $number';

  /// `hadith_list_items` row → [Hadith] (no gradings/narrators yet).
  static Hadith? listItem(Map<String, dynamic> r, {String? collectionName}) {
    final id = _s(r, 'id');
    final collection = _s(r, 'collection_id');
    final number = _s(r, 'hadith_number');
    final arabic = r['arabic_display'];
    final position = _i(r, 'source_position');
    if (id == null || collection == null || number == null || arabic is! String || arabic.trim().isEmpty) {
      return null;
    }
    return Hadith(
      id: id,
      bookId: collection,
      chapterId: _s(r, 'book_id') ?? '',
      number: position ?? 0,
      numberLabel: number,
      arabicText: arabic,
      somaliText: _s(r, 'somali_text'),
      translator: _s(r, 'translator'),
      narrator: _s(r, 'narrator_text_ar'),
      reference: _reference(collectionName, number),
      sourceStatus: SourceStatus.verified,
    );
  }

  /// `search_hadiths_v2` row → [Hadith] with its published gradings (each
  /// with scholar + reference, never merged into one grade).
  static Hadith? searchRow(Map<String, dynamic> r, {String? collectionName}) {
    final base = listItem(r, collectionName: collectionName);
    if (base == null) return null;
    final gradings = [
      for (final g in (r['grades'] as List? ?? const []))
        if (g is Map && g['grade'] is String && g['scholar'] is String)
          HadithGrading(
            grade: g['grade'] as String,
            label: g['label'] as String?,
            scholar: g['scholar'] as String,
            sourceReference: (g['reference'] as String?) ?? '',
          ),
    ];
    return Hadith(
      id: base.id,
      bookId: base.bookId,
      chapterId: base.chapterId,
      number: base.number,
      numberLabel: base.numberLabel,
      arabicText: base.arabicText,
      somaliText: base.somaliText,
      translator: base.translator,
      narrator: base.narrator,
      reference: base.reference,
      gradings: gradings,
      sourceStatus: SourceStatus.verified,
    );
  }

  /// `hadiths` detail row (with embeds) → [Hadith]; null if not published.
  static Hadith? detail(Map<String, dynamic> r, {String? collectionName}) {
    if (r['status'] != 'published') return null;
    final id = _s(r, 'id');
    final collection = _s(r, 'collection_id');
    final number = _s(r, 'hadith_number');
    final original = r['arabic_text'];
    if (id == null || collection == null || number == null || original is! String || original.trim().isEmpty) {
      return null;
    }
    final vowelized = r['vowelized_verified'] == true ? _s(r, 'arabic_text_vowelized') : null;

    final translations = [
      for (final t in (r['translations'] as List? ?? const []))
        if (t is Map && t['status'] == 'published' && (t['language'] ?? 'so') == 'so') Map<String, dynamic>.from(t),
    ]..sort((a, b) => (b['is_primary'] == true ? 1 : 0).compareTo(a['is_primary'] == true ? 1 : 0));
    final primary = translations.isEmpty ? null : translations.first;

    final gradings = [
      for (final g in (r['gradings'] as List? ?? const []))
        if (g is Map && g['status'] == 'published' && g['grade'] is String && g['scholar'] is String)
          HadithGrading(
            grade: g['grade'] as String,
            label: g['grade_label_ar'] as String?,
            scholar: g['scholar'] as String,
            sourceReference: (g['source_reference'] as String?) ?? '',
            sourceUrl: g['source_url'] as String?,
            notes: g['disagreement_notes'] as String?,
          ),
    ];

    final links = [
      for (final n in (r['hadith_narrators'] as List? ?? const []))
        if (n is Map && n['narrators'] is Map && (n['narrators'] as Map)['status'] == 'published')
          (position: (n['position'] as num?)?.toInt() ?? 0, name: (n['narrators'] as Map)['name_ar'] as String),
    ]..sort((a, b) => a.position.compareTo(b.position));

    final sourceName = _s(r, 'source_name');
    final edition = _s(r, 'source_edition');

    return Hadith(
      id: id,
      bookId: collection,
      chapterId: _s(r, 'book_id') ?? '',
      number: _i(r, 'source_position') ?? 0,
      numberLabel: number,
      arabicText: vowelized ?? original,
      somaliText: primary == null ? null : primary['text'] as String?,
      translator: primary == null ? null : primary['translator'] as String?,
      translationSource: primary == null ? null : primary['translation_source'] as String?,
      narrator: _s(r, 'narrator_text_ar'),
      narrators: [for (final l in links) l.name],
      gradings: gradings,
      categoryIds: [
        for (final c in (r['hadith_categories'] as List? ?? const []))
          if (c is Map && c['category_id'] is String) c['category_id'] as String,
      ],
      reference: _reference(collectionName, number),
      source: sourceName == null ? null : (edition == null ? sourceName : '$sourceName — $edition'),
      sourceUrl: _s(r, 'source_url'),
      sourceStatus: SourceStatus.verified,
      audio: audio(r['hadith_audio']),
    );
  }

  /// First published `hadith_audio` row → [HadithAudio]. Only https URLs with
  /// a reciter, source and licence are accepted; anything else is dropped.
  static HadithAudio? audio(Object? rows) {
    if (rows is! List) return null;
    for (final r in rows) {
      if (r is! Map || r['status'] != 'published') continue;
      final url = Uri.tryParse('${r['audio_url'] ?? ''}');
      final reciter = r['reciter'];
      final source = r['source_name'];
      final license = r['license'];
      if (url == null || url.scheme != 'https' || url.host.isEmpty) continue;
      if (reciter is! String || source is! String || license is! String) continue;
      if (reciter.trim().isEmpty || source.trim().isEmpty || license.trim().isEmpty) continue;
      final seconds = r['duration_seconds'];
      return HadithAudio(
        url: url,
        reciter: reciter,
        sourceName: source,
        sourceUrl: r['source_url'] as String?,
        license: license,
        duration: seconds is num && seconds > 0 ? Duration(milliseconds: (seconds * 1000).round()) : null,
        language: (r['language'] as String?) ?? 'ar',
        verified: r['verified_at'] != null,
      );
    }
    return null;
  }
  // ---- offline cache (published records only) ----

  static Map<String, dynamic> hadithToJson(Hadith h) => {
    'id': h.id,
    'bookId': h.bookId,
    'chapterId': h.chapterId,
    'number': h.number,
    'numberLabel': h.numberLabel,
    'arabicText': h.arabicText,
    'somaliText': h.somaliText,
    'translator': h.translator,
    'translationSource': h.translationSource,
    'narrator': h.narrator,
    'narrators': h.narrators,
    'reference': h.reference,
    'source': h.source,
    'sourceUrl': h.sourceUrl,
    'categoryIds': h.categoryIds,
    'gradings': [
      for (final g in h.gradings)
        {
          'grade': g.grade,
          'label': g.label,
          'scholar': g.scholar,
          'sourceReference': g.sourceReference,
          'sourceUrl': g.sourceUrl,
          'notes': g.notes,
        },
    ],
    if (h.audio case final a?)
      'audio': {
        'url': a.url.toString(),
        'reciter': a.reciter,
        'sourceName': a.sourceName,
        'sourceUrl': a.sourceUrl,
        'license': a.license,
        'durationMs': a.duration?.inMilliseconds,
        'language': a.language,
        'verified': a.verified,
      },
  };

  static Hadith? hadithFromJson(Map<String, dynamic> j) {
    try {
      return Hadith(
        id: j['id'] as String,
        bookId: j['bookId'] as String,
        chapterId: j['chapterId'] as String,
        number: j['number'] as int,
        numberLabel: j['numberLabel'] as String?,
        arabicText: j['arabicText'] as String,
        somaliText: j['somaliText'] as String?,
        translator: j['translator'] as String?,
        translationSource: j['translationSource'] as String?,
        narrator: j['narrator'] as String?,
        narrators: [for (final n in (j['narrators'] as List? ?? const [])) n as String],
        reference: j['reference'] as String?,
        source: j['source'] as String?,
        sourceUrl: j['sourceUrl'] as String?,
        categoryIds: [for (final c in (j['categoryIds'] as List? ?? const [])) c as String],
        gradings: [
          for (final g in (j['gradings'] as List? ?? const []))
            HadithGrading(
              grade: (g as Map)['grade'] as String,
              label: g['label'] as String?,
              scholar: g['scholar'] as String,
              sourceReference: g['sourceReference'] as String,
              sourceUrl: g['sourceUrl'] as String?,
              notes: g['notes'] as String?,
            ),
        ],
        audio: switch (j['audio']) {
          final Map<String, dynamic> a => HadithAudio(
            url: Uri.parse(a['url'] as String),
            reciter: a['reciter'] as String,
            sourceName: a['sourceName'] as String,
            sourceUrl: a['sourceUrl'] as String?,
            license: a['license'] as String,
            duration: a['durationMs'] is int ? Duration(milliseconds: a['durationMs'] as int) : null,
            language: (a['language'] as String?) ?? 'ar',
            verified: a['verified'] == true,
          ),
          _ => null,
        },
        sourceStatus: SourceStatus.verified,
      );
    } catch (_) {
      return null; // corrupted cache entry → ignored
    }
  }
}
