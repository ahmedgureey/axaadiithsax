import '../../core/utils/arabic_normalizer.dart';
import '../mock_data/mock_library.dart';
import '../models/chapter.dart';
import '../models/hadith.dart';
import '../models/hadith_book.dart';
import '../models/hadith_category.dart';

/// Read-only access to books, chapters, hadith and categories.
///
/// Backed by local mock data in this phase. Lookups return `null` for unknown
/// IDs so screens can show a not-found state instead of crashing. Methods are
/// synchronous for now; when a real data source arrives they can become async
/// without changing call sites' validation logic.
class HadithRepository {
  HadithRepository({
    List<HadithBook>? books,
    List<Chapter>? chapters,
    List<Hadith>? hadiths,
    List<HadithCategory>? categories,
  }) : books = books ?? MockLibrary.books,
       _chapters = chapters ?? MockLibrary.chapters,
       _hadiths = hadiths ?? MockLibrary.hadiths,
       categories = categories ?? MockLibrary.categories;

  final List<HadithBook> books;
  final List<Chapter> _chapters;
  final List<Hadith> _hadiths;
  final List<HadithCategory> categories;

  List<Hadith> get allHadiths => _hadiths;

  HadithBook? bookById(String? id) => _firstOrNull(books, (b) => b.id == id);

  Chapter? chapterById(String? id) => _firstOrNull(_chapters, (c) => c.id == id);

  Hadith? hadithById(String? id) => _firstOrNull(_hadiths, (h) => h.id == id);

  HadithCategory? categoryById(String? id) => _firstOrNull(categories, (c) => c.id == id);

  List<Chapter> chaptersOf(String bookId) =>
      _chapters.where((c) => c.bookId == bookId).toList()..sort((a, b) => a.number.compareTo(b.number));

  List<Hadith> hadithsOf(String chapterId) =>
      _hadiths.where((h) => h.chapterId == chapterId).toList()..sort((a, b) => a.number.compareTo(b.number));

  int hadithCountOfBook(String bookId) => _hadiths.where((h) => h.bookId == bookId).length;

  int hadithCountOfCategory(String categoryId) =>
      _hadiths.where((h) => h.categoryIds.contains(categoryId)).length;

  /// Reference shown to users. Verified hadith use their real reference;
  /// demo hadith only get their position in the demo dataset, labelled as
  /// such, so nothing looks like an official hadith number.
  String referenceLabel(Hadith hadith) {
    if (hadith.isVerified && hadith.reference != null) return hadith.reference!;
    final chapter = chapterById(hadith.chapterId);
    return "${chapter?.titleSomali ?? 'Cutub'}, #${hadith.number} (tusaale)";
  }

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
          ArabicNormalizer.normalize(h.somaliText).contains(q) ||
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
