import 'package:flutter/foundation.dart';

/// Bookmark-based filter (uses the shared favourites state).
enum BookmarkFilter {
  all('Dhammaan'),
  bookmarked('La keydiyay'),
  notBookmarked('Aan la keydin');

  const BookmarkFilter(this.label);
  final String label;
}

/// Deterministic sort orders. "dataset" is simply the order of the local
/// data (book → chapter → number) — it is NOT chronological.
enum SearchSort {
  dataset('Sida xogta u kala horreyso'),
  book('Magaca kitaabka'),
  reference('Lambarka xadiiska'),
  somali('Tarjumaadda (A–Z)');

  const SearchSort(this.label);
  final String label;
}

/// Documented grade kinds a user can filter by (only gradings that are
/// published with a scholar and reference ever match).
const searchableGrades = <String, String>{
  'sahih': 'Saxiix',
  'hasan': 'Xasan',
  'hasan_sahih': 'Xasan Saxiix',
  'daif': 'Daciif',
};

/// Filters that work with the data that actually exists. With a backend,
/// collections, chapters, topics, grades and "has translation" are evaluated
/// by the database; the bookmark filter is applied on the device (bookmarks
/// are private to the device/account).
@immutable
class SearchFilters {
  const SearchFilters({
    this.bookIds = const {},
    this.chapterIds = const {},
    this.categoryIds = const {},
    this.grades = const {},
    this.translatedOnly = false,
    this.bookmark = BookmarkFilter.all,
  });

  static const none = SearchFilters();

  /// Collections (app "books").
  final Set<String> bookIds;

  /// Chapters (v2 books) — only meaningful within the selected collections.
  final Set<String> chapterIds;
  final Set<String> categoryIds;

  /// Documented grade kinds (`sahih`, `hasan`, …). Empty = any.
  final Set<String> grades;

  /// Only records with a (published) Somali translation.
  final bool translatedOnly;
  final BookmarkFilter bookmark;

  bool get isEmpty =>
      bookIds.isEmpty &&
      chapterIds.isEmpty &&
      categoryIds.isEmpty &&
      grades.isEmpty &&
      !translatedOnly &&
      bookmark == BookmarkFilter.all;

  int get activeCount =>
      bookIds.length +
      chapterIds.length +
      categoryIds.length +
      grades.length +
      (translatedOnly ? 1 : 0) +
      (bookmark == BookmarkFilter.all ? 0 : 1);

  SearchFilters copyWith({
    Set<String>? bookIds,
    Set<String>? chapterIds,
    Set<String>? categoryIds,
    Set<String>? grades,
    bool? translatedOnly,
    BookmarkFilter? bookmark,
  }) => SearchFilters(
    bookIds: bookIds ?? this.bookIds,
    chapterIds: chapterIds ?? this.chapterIds,
    categoryIds: categoryIds ?? this.categoryIds,
    grades: grades ?? this.grades,
    translatedOnly: translatedOnly ?? this.translatedOnly,
    bookmark: bookmark ?? this.bookmark,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      setEquals(other.bookIds, bookIds) &&
      setEquals(other.chapterIds, chapterIds) &&
      setEquals(other.categoryIds, categoryIds) &&
      setEquals(other.grades, grades) &&
      other.translatedOnly == translatedOnly &&
      other.bookmark == bookmark;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(bookIds),
    Object.hashAllUnordered(chapterIds),
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(grades),
    translatedOnly,
    bookmark,
  );
}
