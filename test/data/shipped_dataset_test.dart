import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';

/// The app must not ship placeholder hadith. Until a verified dataset is
/// added, the default repository holds only the book and topic catalogue.
void main() {
  test('default repository ships no hadith or placeholder chapters', () {
    final repo = HadithRepository();
    expect(repo.allHadiths, isEmpty);
    for (final b in repo.books) {
      expect(repo.chaptersOf(b.id), isEmpty, reason: b.id);
    }
    expect(repo.dailyHadith(DateTime(2026, 11, 19)), isNull);
    expect(repo.search(''), isEmpty);
  });

  test('book and topic catalogue is preserved', () {
    final repo = HadithRepository();
    expect(repo.books.map((b) => b.id), containsAll(['bukhari', 'muslim', 'nawawi40']));
    expect(repo.categories, isNotEmpty);
  });

  test('no book description claims to contain sample data', () {
    for (final b in HadithRepository().books) {
      expect(b.description, isNot(contains('tusaale')), reason: b.id);
      expect(b.description, isNot(contains('tijaab')), reason: b.id);
    }
  });
}
