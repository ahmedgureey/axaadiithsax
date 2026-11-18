import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';
import 'package:xadiithapp/features/search/data/hadith_search_service.dart';
import 'package:xadiithapp/features/search/domain/search_options.dart';
import 'package:xadiithapp/features/search/search_history_controller.dart';

void main() {
  final repo = HadithRepository();
  final service = HadithSearchService(repo);
  final all = repo.allHadiths;

  group('Matching', () {
    test('empty query returns every record in dataset order', () {
      final r = service.search();
      expect(r.length, all.length);
      expect(r.first.id, 'bukhari-c1-h1');
    });

    test('Arabic text with diacritics matches undiacritised data', () {
      expect(service.search(query: 'تَجْرِيبِي').length, all.length);
      expect(service.search(query: 'المعتمدة'), isNotEmpty);
    });

    test('Somali translation, partial words, case-insensitive', () {
      final r = service.search(query: 'TARJUMAAD');
      expect(r, isNotEmpty);
      expect(r.every((h) => h.hasTranslation), isTrue);
      expect(service.search(query: 'tarj'), hasLength(r.length));
    });

    test('book names (Somali and Arabic) are searchable', () {
      final muslim = service.search(query: 'Saxiix Muslim');
      expect(muslim, isNotEmpty);
      expect(muslim.every((h) => h.bookId == 'muslim'), isTrue);
      expect(service.search(query: 'صحيح مسلم').map((h) => h.id), muslim.map((h) => h.id));
    });

    test('chapter titles and narrator are searchable', () {
      final c2 = service.search(query: 'باب تجريبي ٢');
      expect(c2, isNotEmpty);
      final c2Ids = c2.map((h) => h.id).toSet();
      for (final h in all.where((h) => h.chapterId.endsWith('-c2'))) {
        expect(c2Ids, contains(h.id), reason: 'every chapter-2 record is found');
      }
      final withNarrator = all.where((h) => h.narrator != null).length;
      expect(service.search(query: 'الراوي'), hasLength(withNarrator));
    });

    test('reference number "#2" finds every record numbered 2', () {
      final ids = service.search(query: '#2').map((h) => h.id).toSet();
      for (final h in all.where((h) => h.number == 2)) {
        expect(ids, contains(h.id));
      }
    });

    test('topic names are searchable', () {
      final r = service.search(query: 'Dulqaadka');
      expect(r, isNotEmpty);
      expect(r.every((h) => h.categoryIds.contains('sabr')), isTrue);
    });

    test('all tokens must match (AND)', () {
      final r = service.search(query: 'Muslim tusaale 2');
      expect(r.every((h) => h.bookId == 'muslim'), isTrue);
      expect(service.search(query: 'Muslim zzzz'), isEmpty);
    });
  });

  group('Filters', () {
    test('book and category filters combine', () {
      final r = service.search(
        filters: const SearchFilters(bookIds: {'bukhari'}, categoryIds: {'salah'}),
      );
      expect(r, isNotEmpty);
      expect(r.every((h) => h.bookId == 'bukhari' && h.categoryIds.contains('salah')), isTrue);
    });

    test('bookmark filter uses the favourites set', () {
      const favs = {'muslim-c1-h1', 'bukhari-c2-h3'};
      final saved = service.search(
        filters: const SearchFilters(bookmark: BookmarkFilter.bookmarked),
        favoriteIds: favs,
      );
      expect(saved.map((h) => h.id).toSet(), favs);
      final notSaved = service.search(
        filters: const SearchFilters(bookmark: BookmarkFilter.notBookmarked),
        favoriteIds: favs,
      );
      expect(notSaved.length, all.length - favs.length);
    });

    test('unknown filter IDs are ignored safely', () {
      const bad = SearchFilters(bookIds: {'nope'}, categoryIds: {'nope'});
      expect(service.sanitize(bad).isEmpty, isTrue);
      expect(service.search(filters: bad).length, all.length);
    });

    test('only books with records are offered as filters', () {
      expect(service.filterableBooks.map((b) => b.id), ['bukhari', 'muslim', 'nawawi40']);
    });

    test('category counts come from the data (empty topics are 0)', () {
      expect(repo.categoryById('sawm'), isNotNull, reason: 'topic must exist, not just count 0');
      expect(repo.categoryById('tawbah'), isNotNull);
      expect(service.countForCategory('sawm'), 0);
      expect(service.countForCategory('tawbah'), 0);
      expect(
        service.countForCategory('salah'),
        service.search(filters: const SearchFilters(categoryIds: {'salah'})).length,
      );
    });
  });

  group('Sorting', () {
    test('every sort is deterministic and does not touch the dataset', () {
      final before = all.map((h) => h.id).toList();
      for (final s in SearchSort.values) {
        final a = service.search(sort: s).map((h) => h.id).toList();
        final b = service.search(sort: s).map((h) => h.id).toList();
        expect(a, b, reason: s.name);
        expect(a.toSet().length, all.length, reason: s.name);
      }
      expect(all.map((h) => h.id).toList(), before);
    });

    test('book sort is alphabetical by Somali book name', () {
      final names = service.search(sort: SearchSort.book).map((h) => repo.bookById(h.bookId)!.nameSomali).toList();
      expect(names, [...names]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
      expect(names.first, "Al-Arbaciin an-Nawawiyya", reason: "case-insensitive: al- before Saxiix");
    });

    test('reference sort orders by hadith number', () {
      final numbers = service.search(sort: SearchSort.reference).map((h) => h.number).toList();
      expect(numbers, [...numbers]..sort());
    });

    test('translation sort puts missing translations last', () {
      final r = service.search(sort: SearchSort.somali);
      expect(r.last.hasTranslation, isFalse);
      expect(r.where((h) => !h.hasTranslation), hasLength(1));
    });
  });

  group('Search history', () {
    test('trims, ignores short terms, dedupes, caps and persists', () async {
      final store = InMemorySettingsStore();
      final h = SearchHistoryController(store);
      await h.add('  salaad  maanta ');
      await h.add('a');
      await h.add('Salaad Maanta');
      expect(h.terms, ['Salaad Maanta']);

      for (var i = 0; i < 12; i++) {
        await h.add('eray $i');
      }
      expect(h.terms, hasLength(SearchHistoryController.maxItems));
      expect(h.terms.first, 'eray 11');

      await h.add('الصَّلَاة');
      final restored = SearchHistoryController(store);
      await restored.load();
      expect(restored.terms.first, 'الصَّلَاة', reason: 'Arabic preserved exactly');

      await restored.remove('الصَّلَاة');
      expect(restored.terms.contains('الصَّلَاة'), isFalse);
      await restored.clear();
      expect(restored.terms, isEmpty);
    });
  });
}
