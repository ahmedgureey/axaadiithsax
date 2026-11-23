import 'package:flutter/foundation.dart';

import '../../core/utils/arabic_normalizer.dart';
import '../mock_data/mock_library.dart';
import '../models/chapter.dart';
import '../models/hadith.dart';
import '../models/hadith_book.dart';
import '../models/hadith_category.dart';

/// Synchronous access to books, chapters, hadith and categories.
///
/// Without a backend it holds the bundled catalogue. With Supabase it is the
/// app's **cache**: `CatalogService` fills it on demand (metadata at start,
/// chapters page by page, records by id) and listeners rebuild when data
/// arrives. Lookups return `null` for unknown IDs so screens can show a
/// loading or not-found state instead of crashing. It only ever holds
/// published records (see migration 0007).
class HadithRepository extends ChangeNotifier {
  HadithRepository({
    List<HadithBook>? books,
    List<Chapter>? chapters,
    List<Hadith>? hadiths,
    List<HadithCategory>? categories,
  }) : _books = List.of(books ?? MockLibrary.books),
       _chapters = List.of(chapters ?? MockLibrary.chapters),
       _hadiths = List.of(hadiths ?? MockLibrary.hadiths),
       _categories = List.of(categories ?? MockLibrary.categories);

  final List<HadithBook> _books;
  final List<Chapter> _chapters;
  final List<Hadith> _hadiths;
  final List<HadithCategory> _categories;

  /// Published counts from the backend (collection id / chapter id → count),
  /// so counts are right before records are downloaded.
  final Map<String, int> _bookCounts = {};
  final Map<String, int> _chapterCounts = {};

  List<HadithBook> get books => List.unmodifiable(_books);
  List<HadithCategory> get categories => List.unmodifiable(_categories);

  /// Replaces the catalogue metadata (backend start-up). Records already in
  /// the cache are kept only if their chapter still exists.
  void replaceCatalog({
    required List<HadithBook> books,
    required List<Chapter> chapters,
    List<HadithCategory>? categories,
    Map<String, int> bookCounts = const {},
    Map<String, int> chapterCounts = const {},
  }) {
    _books
      ..clear()
      ..addAll(books);
    _chapters
      ..clear()
      ..addAll(chapters);
    if (categories != null && categories.isNotEmpty) {
      _categories
        ..clear()
        ..addAll(categories);
    }
    _bookCounts
      ..clear()
      ..addAll(bookCounts);
    _chapterCounts
      ..clear()
      ..addAll(chapterCounts);
    final bookIds = {for (final b in books) b.id};
    _hadiths.removeWhere((h) => !bookIds.contains(h.bookId));
    notifyListeners();
  }

  /// Adds or replaces records by id (backend pages / details).
  void mergeHadiths(Iterable<Hadith> records) {
    var changed = false;
    for (final h in records) {
      final i = _hadiths.indexWhere((x) => x.id == h.id);
      if (i >= 0) {
        _hadiths[i] = h;
      } else {
        _hadiths.add(h);
      }
      changed = true;
    }
    if (changed) notifyListeners();
  }

  List<Hadith> get allHadiths => _hadiths;

  /// Total records available: backend published count when known, else
  /// what is held locally.
  int get totalHadithCount => _bookCounts.isEmpty ? _hadiths.length : _bookCounts.values.fold(0, (a, b) => a + b);

  HadithBook? bookById(String? id) => _firstOrNull(_books, (b) => b.id == id);

  Chapter? chapterById(String? id) => _firstOrNull(_chapters, (c) => c.id == id);

  Hadith? hadithById(String? id) => _firstOrNull(_hadiths, (h) => h.id == id);

  HadithCategory? categoryById(String? id) => _firstOrNull(_categories, (c) => c.id == id);

  List<Chapter> chaptersOf(String bookId) =>
      _chapters.where((c) => c.bookId == bookId).toList()..sort((a, b) => a.number.compareTo(b.number));

  List<Hadith> hadithsOf(String chapterId) =>
      _hadiths.where((h) => h.chapterId == chapterId).toList()..sort((a, b) => a.number.compareTo(b.number));

  int hadithCountOfBook(String bookId) => _bookCounts[bookId] ?? _hadiths.where((h) => h.bookId == bookId).length;

  int hadithCountOfCategory(String categoryId) => _hadiths.where((h) => h.categoryIds.contains(categoryId)).length;

  /// Reference shown to users. Real (verified or sourced) hadith use their reference;
  /// demo hadith only get their position in the demo dataset, labelled as
  /// such, so nothing looks like an official hadith number.
  String referenceLabel(Hadith hadith) {
    if (!hadith.isDemo && hadith.reference != null) return hadith.reference!;
    final chapter = chapterById(hadith.chapterId);
    return "${chapter?.titleSomali ?? 'Cutub'}, #${hadith.displayNumber} (tusaale)";
  }

  int hadithCountOfChapter(String chapterId) =>
      _chapterCounts[chapterId] ?? _hadiths.where((h) => h.chapterId == chapterId).length;

  /// Records of [chapterId] currently in the cache (may be fewer than
  /// [hadithCountOfChapter] while pages are still loading).
  int loadedCountOfChapter(String chapterId) => _hadiths.where((h) => h.chapterId == chapterId).length;

  /// All hadith of a book in reading order (chapter number, then hadith
  /// number). Used for previous / next navigation.
  List<Hadith> readingOrderOf(String bookId) => [for (final c in chaptersOf(bookId)) ...hadithsOf(c.id)];

  /// Previous and next records in the same book (crossing chapters), or null
  /// at either end.
  ({Hadith? previous, Hadith? next}) neighboursOf(Hadith hadith) {
    final order = readingOrderOf(hadith.bookId);
    final i = order.indexWhere((h) => h.id == hadith.id);
    if (i < 0) return (previous: null, next: null);
    return (previous: i > 0 ? order[i - 1] : null, next: i < order.length - 1 ? order[i + 1] : null);
  }

  /// Other records sharing a topic with [hadith] (deterministic order).
  List<Hadith> relatedTo(Hadith hadith, {int limit = 3}) =>
      _hadiths.where((h) => h.id != hadith.id && h.categoryIds.any(hadith.categoryIds.contains)).take(limit).toList();

  /// Deterministic "hadith of the day" from the local dataset.
  Hadith? dailyHadith(DateTime date) {
    if (_hadiths.isEmpty) return null;
    final dayIndex = DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/ 86400000;
    return _hadiths[dayIndex % _hadiths.length];
  }

  /// Searches Arabic text, Somali translation and narrator.
  /// Empty query returns all hadith matching the filters.
  List<Hadith> search(String query, {String? bookId, String? categoryId}) {
    final q = ArabicNormalizer.normalize(query);
    return _hadiths.where((h) {
      if (bookId != null && h.bookId != bookId) return false;
      if (categoryId != null && !h.categoryIds.contains(categoryId)) return false;
      if (q.isEmpty) return true;
      return ArabicNormalizer.normalize(h.arabicText).contains(q) ||
          ArabicNormalizer.normalize(h.somaliText ?? "").contains(q) ||
          ArabicNormalizer.normalize(h.narrator ?? '').contains(q);
    }).toList();
  }

  static T? _firstOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}
