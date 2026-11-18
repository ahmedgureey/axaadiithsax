import '../../data/models/hadith.dart';
import '../../data/models/hadith_book.dart';
import '../../data/models/hadith_category.dart';
import '../../data/repositories/hadith_repository.dart';

class FeaturedBook {
  const FeaturedBook(this.book, this.hadithCount);
  final HadithBook book;

  /// Number of (demo) hadith actually present in the local dataset.
  final int hadithCount;
  bool get hasContent => hadithCount > 0;
}

class CategorySummary {
  const CategorySummary(this.category, this.hadithCount);
  final HadithCategory category;
  final int hadithCount;
}

/// Everything the Home screen shows, computed once from the repository so
/// widgets stay presentational and no transformation repeats on rebuild.
class HomeFeed {
  const HomeFeed({
    required this.daily,
    required this.books,
    required this.categories,
    required this.featuredHadiths,
  });

  final Hadith? daily;
  final List<FeaturedBook> books;
  final List<CategorySummary> categories;

  /// Deterministic fallback for "recent" when there is no reading history:
  /// the first hadith of each book that has content (max 3).
  final List<Hadith> featuredHadiths;

  factory HomeFeed.build(HadithRepository repo, DateTime today) {
    final books = [for (final b in repo.books) FeaturedBook(b, repo.hadithCountOfBook(b.id))];
    final categories = [
      for (final c in repo.categories) CategorySummary(c, repo.hadithCountOfCategory(c.id)),
    ];
    final featured = <Hadith>[];
    for (final b in books.where((b) => b.hasContent)) {
      final chapters = repo.chaptersOf(b.book.id);
      if (chapters.isEmpty) continue;
      final hadiths = repo.hadithsOf(chapters.first.id);
      if (hadiths.isNotEmpty) featured.add(hadiths.first);
      if (featured.length == 3) break;
    }
    return HomeFeed(
      daily: repo.dailyHadith(today),
      books: List.unmodifiable(books),
      categories: List.unmodifiable(categories),
      featuredHadiths: List.unmodifiable(featured),
    );
  }
}
