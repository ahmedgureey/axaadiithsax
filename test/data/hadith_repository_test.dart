import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/utils/arabic_normalizer.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';

void main() {
  final repo = HadithRepository();

  test('unknown IDs return null instead of throwing', () {
    expect(repo.bookById('nope'), isNull);
    expect(repo.chapterById(null), isNull);
    expect(repo.hadithById(''), isNull);
    expect(repo.categoryById('x'), isNull);
  });

  test('chapters and hadith are linked and ordered', () {
    for (final book in repo.books) {
      final chapters = repo.chaptersOf(book.id);
      if (repo.hadithCountOfBook(book.id) == 0) {
        expect(chapters, isEmpty, reason: "${book.id} is listed without content");
        continue;
      }
      expect(chapters, isNotEmpty);
      expect(chapters.every((c) => c.bookId == book.id), isTrue);
      for (final c in chapters) {
        final hadiths = repo.hadithsOf(c.id);
        expect(hadiths.every((h) => h.chapterId == c.id && h.bookId == book.id), isTrue);
      }
    }
  });

  test('all mock hadith are marked unverified (demo content)', () {
    expect(repo.allHadiths.every((h) => !h.isVerified), isTrue);
    expect(repo.allHadiths.every((h) => h.grade == null), isTrue);
  });

  test('every category used by hadith exists', () {
    for (final h in repo.allHadiths) {
      for (final id in h.categoryIds) {
        expect(repo.categoryById(id), isNotNull);
      }
    }
  });

  test('daily hadith is deterministic per day', () {
    final d = DateTime(2026, 11, 18, 8);
    expect(repo.dailyHadith(d)!.id, repo.dailyHadith(DateTime(2026, 11, 18, 23))!.id);
  });

  test('search filters by book and category and matches Somali text', () {
    expect(repo.search('tusaale'), hasLength(repo.allHadiths.length));
    final bukhari = repo.search('', bookId: 'bukhari');
    expect(bukhari.every((h) => h.bookId == 'bukhari'), isTrue);
    final salah = repo.search('', categoryId: 'salah');
    expect(salah, isNotEmpty);
    expect(salah.every((h) => h.categoryIds.contains('salah')), isTrue);
    expect(repo.search('zzzz-not-found'), isEmpty);
  });

  test('Arabic search ignores diacritics and letter variants', () {
    expect(ArabicNormalizer.normalize('الصَّلَاةُ'), ArabicNormalizer.normalize('الصلاه'));
    expect(ArabicNormalizer.normalize('إِيمَان'), 'ايمان');
    // Placeholder Arabic text is searchable with tashkeel added.
    expect(repo.search('تَجْرِيبِي'), isNotEmpty);
  });

  test('books without content are clearly empty; counts match data', () {
    for (final id in ['abudawud', 'tirmidhi', 'nasai', 'ibnmajah']) {
      expect(repo.bookById(id), isNotNull);
      expect(repo.hadithCountOfBook(id), 0);
    }
    expect(repo.hadithCountOfBook('bukhari'), repo.search('', bookId: 'bukhari').length);
    for (final c in repo.categories) {
      expect(repo.hadithCountOfCategory(c.id), repo.search('', categoryId: c.id).length);
    }
  });

  test('demo reference labels never look like official numbers', () {
    final h = repo.allHadiths.first;
    expect(repo.referenceLabel(h), contains('(tusaale)'));
  });
}
