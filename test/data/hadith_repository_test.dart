import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/utils/arabic_normalizer.dart';

import '../support/test_library.dart';

void main() {
  final repo = testRepository();

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
    expect(repo.search('tusaale'), hasLength(repo.allHadiths.where((h) => h.hasTranslation).length));
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

  test('chapter counts and reading order', () {
    expect(repo.hadithCountOfChapter('bukhari-c1'), repo.hadithsOf('bukhari-c1').length);
    expect(repo.hadithCountOfChapter('nope'), 0);
    final order = repo.readingOrderOf('bukhari');
    expect(order.length, repo.hadithCountOfBook('bukhari'));
    expect(order.first.id, 'bukhari-c1-h1');
    expect(repo.readingOrderOf('abudawud'), isEmpty);
  });

  test('neighbours cross chapters and stop at the ends', () {
    final first = repo.hadithById('bukhari-c1-h1')!;
    expect(repo.neighboursOf(first).previous, isNull);
    expect(repo.neighboursOf(first).next!.id, 'bukhari-c1-h2');
    final endOfChapter = repo.hadithById('bukhari-c1-h3')!;
    expect(repo.neighboursOf(endOfChapter).next!.id, 'bukhari-c2-h1');
    final last = repo.readingOrderOf('bukhari').last;
    expect(repo.neighboursOf(last).next, isNull, reason: 'never jumps to another book');
  });

  test('related hadith share a topic and exclude the record itself', () {
    final h = repo.hadithById('muslim-c2-h1')!;
    final related = repo.relatedTo(h);
    expect(related, isNotEmpty);
    expect(related.length, lessThanOrEqualTo(3));
    expect(related.any((r) => r.id == h.id), isFalse);
    expect(related.every((r) => r.categoryIds.any(h.categoryIds.contains)), isTrue);
  });

  test('one demo record has no translation or narrator (missing-state demo)', () {
    final incomplete = repo.allHadiths.where((h) => !h.hasTranslation).toList();
    expect(incomplete, hasLength(1));
    expect(incomplete.single.narrator, isNull);
    expect(repo.search('tusaale').any((h) => h.id == incomplete.single.id), isFalse);
  });

  test('record IDs are unique even though numbers repeat', () {
    final ids = repo.allHadiths.map((h) => h.id).toSet();
    expect(ids.length, repo.allHadiths.length);
    expect(repo.allHadiths.where((h) => h.number == 1).length, greaterThan(1));
  });
}
