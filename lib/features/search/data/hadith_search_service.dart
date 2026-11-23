import '../../../core/utils/arabic_normalizer.dart';
import '../../../data/models/hadith.dart';
import '../../../data/models/hadith_book.dart';
import '../../../data/models/hadith_category.dart';
import '../../../data/repositories/hadith_repository.dart';
import '../domain/search_options.dart';

class _Entry {
  _Entry(this.hadith, this.order, this.haystack, this.bookName, this.somaliKey);
  final Hadith hadith;

  /// Position in the dataset (book → chapter → number).
  final int order;

  /// Pre-normalised searchable text of every available field.
  final String haystack;
  final String bookName;

  /// Normalised translation for A–Z sorting; null when missing.
  final String? somaliKey;
}

/// Local hadith search. The index is built once from the repository, so
/// typing never re-normalises the dataset. Matching, filtering and sorting
/// are independent, deterministic steps.
class HadithSearchService {
  HadithSearchService(this._repo) : _entries = _buildIndex(_repo);

  final HadithRepository _repo;
  final List<_Entry> _entries;

  /// Books that have records (the only ones worth filtering by).
  List<HadithBook> get filterableBooks => [
    for (final b in _repo.books)
      if (_repo.hadithCountOfBook(b.id) > 0) b,
  ];

  List<HadithCategory> get categories => _repo.categories;

  static List<_Entry> _buildIndex(HadithRepository repo) {
    final result = <_Entry>[];
    var order = 0;
    for (final book in repo.books) {
      for (final chapter in repo.chaptersOf(book.id)) {
        for (final h in repo.hadithsOf(chapter.id)) {
          final topics = [for (final id in h.categoryIds) ?repo.categoryById(id)];
          final fields = [
            h.arabicText,
            h.somaliText ?? '',
            book.nameSomali,
            book.nameArabic,
            chapter.titleSomali,
            chapter.titleArabic,
            h.narrator ?? '',
            '#${h.displayNumber}',
            repo.referenceLabel(h),
            for (final t in topics) ...[t.nameSomali, t.nameArabic],
          ];
          result.add(
            _Entry(
              h,
              order++,
              ArabicNormalizer.normalize(fields.join(' \u0001 ')),
              // Case-insensitive key so "al-Bukhaari" sorts before "Muslim".
              ArabicNormalizer.normalize(book.nameSomali),
              h.hasTranslation ? ArabicNormalizer.normalize(h.somaliText!) : null,
            ),
          );
        }
      }
    }
    return List.unmodifiable(result);
  }

  /// Removes filter values that reference data that no longer exists.
  SearchFilters sanitize(SearchFilters filters) => filters.copyWith(
    bookIds: {
      for (final id in filters.bookIds)
        if (_repo.bookById(id) != null) id,
    },
    categoryIds: {
      for (final id in filters.categoryIds)
        if (_repo.categoryById(id) != null) id,
    },
    grades: {
      for (final g in filters.grades)
        if (searchableGrades.containsKey(g)) g,
    },
  );

  /// Every query token must appear (partial words allowed). An empty query
  /// matches everything, so filters alone can be used to browse.
  List<Hadith> search({
    String query = '',
    SearchFilters filters = SearchFilters.none,
    SearchSort sort = SearchSort.dataset,
    Set<String> favoriteIds = const {},
  }) {
    final tokens = ArabicNormalizer.tokens(query);
    final f = sanitize(filters);
    final matches = _entries.where((e) {
      final h = e.hadith;
      if (f.bookIds.isNotEmpty && !f.bookIds.contains(h.bookId)) return false;
      if (f.chapterIds.isNotEmpty && !f.chapterIds.contains(h.chapterId)) return false;
      if (f.categoryIds.isNotEmpty && !h.categoryIds.any(f.categoryIds.contains)) return false;
      if (f.translatedOnly && !h.hasTranslation) return false;
      if (f.grades.isNotEmpty && !h.gradings.any((g) => f.grades.contains(g.grade))) return false;
      switch (f.bookmark) {
        case BookmarkFilter.bookmarked when !favoriteIds.contains(h.id):
        case BookmarkFilter.notBookmarked when favoriteIds.contains(h.id):
          return false;
        default:
      }
      return tokens.every(e.haystack.contains);
    }).toList();
    return [for (final e in _sortEntries(matches, sort)) e.hadith];
  }

  /// Number of records in a topic (from the data, never estimated).
  int countForCategory(String categoryId) => _repo.hadithCountOfCategory(categoryId);

  static List<_Entry> _sortEntries(List<_Entry> entries, SearchSort sort) {
    final sorted = [...entries];
    int byOrder(_Entry a, _Entry b) => a.order.compareTo(b.order);
    switch (sort) {
      case SearchSort.dataset:
        sorted.sort(byOrder);
      case SearchSort.book:
        sorted.sort((a, b) {
          final c = a.bookName.compareTo(b.bookName);
          return c != 0 ? c : byOrder(a, b);
        });
      case SearchSort.reference:
        sorted.sort((a, b) {
          final c = a.hadith.number.compareTo(b.hadith.number);
          return c != 0 ? c : byOrder(a, b);
        });
      case SearchSort.somali:
        sorted.sort((a, b) {
          // Records without a translation go last.
          if (a.somaliKey == null || b.somaliKey == null) {
            if (a.somaliKey == b.somaliKey) return byOrder(a, b);
            return a.somaliKey == null ? 1 : -1;
          }
          final c = a.somaliKey!.compareTo(b.somaliKey!);
          return c != 0 ? c : byOrder(a, b);
        });
    }
    return sorted;
  }
}
