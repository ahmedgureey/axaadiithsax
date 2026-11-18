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

/// Filters that work with the data that actually exists. Narrator and grade
/// filters are intentionally absent: the demo dataset has no real narrator
/// names and no verified grades.
@immutable
class SearchFilters {
  const SearchFilters({this.bookIds = const {}, this.categoryIds = const {}, this.bookmark = BookmarkFilter.all});

  static const none = SearchFilters();

  final Set<String> bookIds;
  final Set<String> categoryIds;
  final BookmarkFilter bookmark;

  bool get isEmpty => bookIds.isEmpty && categoryIds.isEmpty && bookmark == BookmarkFilter.all;
  int get activeCount => bookIds.length + categoryIds.length + (bookmark == BookmarkFilter.all ? 0 : 1);

  SearchFilters copyWith({Set<String>? bookIds, Set<String>? categoryIds, BookmarkFilter? bookmark}) => SearchFilters(
    bookIds: bookIds ?? this.bookIds,
    categoryIds: categoryIds ?? this.categoryIds,
    bookmark: bookmark ?? this.bookmark,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      setEquals(other.bookIds, bookIds) &&
      setEquals(other.categoryIds, categoryIds) &&
      other.bookmark == bookmark;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(bookIds), Object.hashAllUnordered(categoryIds), bookmark);
}
