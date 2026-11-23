import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/data/remote/catalog_api.dart';
import 'package:xadiithapp/data/remote/catalog_mapper.dart';
import 'package:xadiithapp/data/remote/catalog_service.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';

// Fixture rows in the v2 shape. Text is TEST ONLY — not hadith.
const _ar1 = 'نَصٌّ لِلِاخْتِبَارِ ١';
const _ar1Vowelized = 'نَصٌّ لِلِاخْتِبَارِ ١ (مشكول)';

final _collections = [
  {
    'id': 'col-a',
    'name_ar': 'مجموعة',
    'name_en': 'Collection A',
    'name_so': 'Ururinta A',
    'name_so_verified': true,
    'sort_order': 1,
  },
  {
    'id': 'col-b',
    'name_ar': 'مجموعة ب',
    'name_en': 'Collection B',
    'name_so': 'unverified',
    'name_so_verified': false,
    'sort_order': 2,
  },
  {'id': 'bad', 'name_ar': '', 'name_en': 'x'},
];
final _books = [
  {
    'id': 'bk-1',
    'collection_id': 'col-a',
    'book_number': '1',
    'title_ar': 'كتاب',
    'title_so': 'Kitaabka 1',
    'sort_order': 1,
  },
  {'id': 'bk-x', 'collection_id': 'nope', 'book_number': '1', 'title_ar': 'x', 'sort_order': 1},
];
final _counts = [
  {'collection_id': 'col-a', 'book_id': 'bk-1', 'published_count': 5},
];

Map<String, dynamic> _item(int i) => {
  'id': 'h$i',
  'collection_id': 'col-a',
  'book_id': 'bk-1',
  'numbering_scheme': 'test',
  'hadith_number': '${i}a',
  'source_position': i,
  'arabic_display': i == 1 ? _ar1 : 'نص $i',
  'somali_text': 'TEST ONLY $i',
  'translator': 'T',
};

Map<String, dynamic> _detail({String status = 'published', bool disagree = true}) => {
  'id': 'h1',
  'collection_id': 'col-a',
  'book_id': 'bk-1',
  'numbering_scheme': 'test',
  'hadith_number': '1a',
  'source_position': 1,
  'status': status,
  'arabic_text': _ar1,
  'arabic_text_vowelized': _ar1Vowelized,
  'vowelized_verified': false,
  'narrator_text_ar': 'راوي',
  'source_name': 'TEST SOURCE',
  'source_edition': 'Ed. 1',
  'source_url': 'https://example.test/1',
  'translations': [
    {
      'language': 'so',
      'text': 'Draft',
      'translator': 'X',
      'translation_source': 'S',
      'is_primary': false,
      'status': 'pending_review',
    },
    {
      'language': 'so',
      'text': 'TEST ONLY tarjumaad',
      'translator': 'T',
      'translation_source': 'S',
      'is_primary': true,
      'status': 'published',
    },
  ],
  'gradings': [
    {'grade': 'sahih', 'scholar': 'Scholar A', 'source_reference': 'Ref A', 'status': 'published'},
    if (disagree) {'grade': 'hasan', 'scholar': 'Scholar B', 'source_reference': 'Ref B', 'status': 'published'},
    {'grade': 'daif', 'scholar': 'Draft scholar', 'source_reference': 'R', 'status': 'imported'},
  ],
  'hadith_narrators': [
    {
      'role': 'sahabi',
      'position': 0,
      'narrators': {'name_ar': 'صحابي', 'status': 'published'},
    },
    {
      'role': 'chain',
      'position': 1,
      'narrators': {'name_ar': 'مسودة', 'status': 'imported'},
    },
  ],
  'hadith_categories': [
    {'category_id': 'iman'},
  ],
};

class FakeApi implements CatalogApi {
  FakeApi({this.total = 5, this.failMeta = false});

  int total;
  bool failMeta;
  Object? failNextList;
  Object? failDetail;
  final listCalls = <(int?, int)>[];
  final idCalls = <List<String>>[];
  final searchCalls = <Map<String, Object?>>[];
  Completer<void>? searchGate;
  Object? failNextSearch;

  void _meta() {
    if (failMeta) throw const SocketException('offline');
  }

  @override
  Future<List<Map<String, dynamic>>> collections() async {
    _meta();
    return _collections;
  }

  @override
  Future<List<Map<String, dynamic>>> books() async {
    _meta();
    return _books;
  }

  @override
  Future<List<Map<String, dynamic>>> categories() async {
    _meta();
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> counts() async {
    _meta();
    return _counts;
  }

  @override
  Future<List<Map<String, dynamic>>> listItems({required String bookId, int? afterPosition, int limit = 100}) async {
    listCalls.add((afterPosition, limit));
    if (failNextList != null) {
      final e = failNextList!;
      failNextList = null;
      throw e;
    }
    final start = (afterPosition ?? 0) + 1;
    return [for (var i = start; i <= total && i < start + limit; i++) _item(i)];
  }

  @override
  Future<List<Map<String, dynamic>>> listItemsByIds(List<String> ids) async {
    idCalls.add(ids);
    return [
      for (final id in ids)
        if (int.tryParse(id.substring(1)) case final n? when n <= total) _item(n),
    ];
  }

  @override
  Future<Map<String, dynamic>?> hadithDetail(String id) async {
    if (failDetail != null) throw failDetail!;
    return id == 'h1' ? _detail() : null;
  }

  /// Simulates `search_hadiths_v2`: rank 0.9 for h1/h2, 0.4 for the rest
  /// (ties exercise the collection/position tie-break), 0 in browse mode;
  /// odd records carry a published sahih grading. Keyset paging like the SQL.
  @override
  Future<List<Map<String, dynamic>>> searchPage(SearchRequest request) async {
    searchCalls.add(request.toParams());
    final gate = searchGate;
    if (gate != null) await gate.future;
    if (failNextSearch != null) {
      final e = failNextSearch!;
      failNextSearch = null;
      throw e;
    }
    final p = request.toParams();
    final grades = p['p_grades'] as List<String>?;
    final q = p['p_query'] as String?; // 'نص' matches all; otherwise a Somali substring
    final rows = [
      for (var i = 1; i <= total; i++)
        if ((grades == null || (i.isOdd && grades.contains('sahih'))) &&
            (q == null || q == 'نص' || 'TEST ONLY $i'.contains(q)))
          {
            ..._item(i),
            'narrator_text_ar': 'راوي $i',
            'grades': i.isOdd
                ? [
                    {'grade': 'sahih', 'scholar': 'Scholar A', 'label': null, 'reference': 'Ref A'},
                  ]
                : const [],
            'rank': request.isBrowse ? 0 : (i <= 2 ? 0.9 : 0.4),
          },
    ];
    final cursor = request.cursor;
    final after = cursor == null
        ? rows
        : rows.where((r) {
            final rank = r['rank'] as num;
            final pos = r['source_position'] as int;
            final col = r['collection_id'] as String;
            return rank < cursor.rank ||
                (rank == cursor.rank &&
                    (col.compareTo(cursor.collectionId) > 0 || (col == cursor.collectionId && pos > cursor.position)));
          });
    return after.take(p['p_limit'] as int).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> daily(DateTime day) async => [_item(4)];
}

Future<CatalogService> _service(FakeApi api, {InMemorySettingsStore? store, int pageSize = 100}) async {
  final repo = HadithRepository(books: const [], chapters: const [], hadiths: const []);
  final s = CatalogService(api, repo, store ?? InMemorySettingsStore(), pageSize: pageSize);
  await s.start();
  return s;
}

void main() {
  group('CatalogMapper', () {
    test('collections: Somali name only when verified; invalid rows dropped', () {
      final c = CatalogMapper.collections(_collections);
      expect(c.map((b) => b.id), ['col-a', 'col-b']);
      expect(c.first.nameSomali, 'Ururinta A');
      expect(c.last.nameSomali, 'Collection B');
      expect(c.every((b) => b.isVerified), isTrue);
    });

    test('books (app chapters) need a known collection', () {
      final ch = CatalogMapper.books(_books, {'col-a'});
      expect(ch.map((c) => c.id), ['bk-1']);
      expect(ch.single.titleSomali, 'Kitaabka 1');
    });

    test('list item keeps Arabic exactly and the original number', () {
      final h = CatalogMapper.listItem(_item(1), collectionName: 'Ururinta A')!;
      expect(h.arabicText, _ar1);
      expect(h.displayNumber, '1a');
      expect(h.number, 1);
      expect(h.isVerified, isTrue);
      expect(h.reference, 'Ururinta A, xadiiska 1a');
      expect(CatalogMapper.listItem({..._item(2), 'arabic_display': '  '}), isNull);
    });

    test('detail: only published translations, gradings and narrators; disagreements kept', () {
      final h = CatalogMapper.detail(_detail())!;
      expect(h.somaliText, 'TEST ONLY tarjumaad');
      expect(h.translator, 'T');
      expect(h.gradings.map((g) => '${g.grade}:${g.scholar}'), ['sahih:Scholar A', 'hasan:Scholar B']);
      expect(h.narrators, ['صحابي']);
      expect(h.categoryIds, ['iman']);
      expect(h.source, 'TEST SOURCE — Ed. 1');
      expect(h.sourceUrl, 'https://example.test/1');
      // vowelized text is NOT used unless verified
      expect(h.arabicText, _ar1);
      expect(CatalogMapper.detail({..._detail(), 'vowelized_verified': true})!.arabicText, _ar1Vowelized);
    });

    test('detail of an unpublished record is rejected', () {
      expect(CatalogMapper.detail(_detail(status: 'verified')), isNull);
      expect(CatalogMapper.detail(_detail(status: 'pending_review')), isNull);
    });

    test('offline cache JSON round-trips without loss', () {
      final h = CatalogMapper.detail(_detail())!;
      final back = CatalogMapper.hadithFromJson(CatalogMapper.hadithToJson(h))!;
      expect(back.arabicText, h.arabicText);
      expect(back.gradings.length, 2);
      expect(back.displayNumber, '1a');
      expect(CatalogMapper.hadithFromJson({'id': 1}), isNull);
    });
  });

  group('CatalogFailure.from', () {
    test('maps network, timeout, permission, not found, server, malformed', () {
      expect(CatalogFailure.from(const SocketException('x')).kind, CatalogFailureKind.offline);
      expect(CatalogFailure.from(TimeoutException('x')).kind, CatalogFailureKind.timeout);
      expect(
        CatalogFailure.from(const PostgrestException(message: 'denied', code: '42501')).kind,
        CatalogFailureKind.permission,
      );
      expect(
        CatalogFailure.from(const PostgrestException(message: 'nf', code: 'PGRST116')).kind,
        CatalogFailureKind.notFound,
      );
      expect(
        CatalogFailure.from(const PostgrestException(message: 'boom', code: 'XX000')).kind,
        CatalogFailureKind.server,
      );
      expect(CatalogFailure.from(const FormatException('bad')).kind, CatalogFailureKind.malformed);
      expect(const CatalogFailure(CatalogFailureKind.offline).message, contains('Internet'));
    });
  });

  group('CatalogService', () {
    test('start: metadata + published counts; no hadith downloaded yet', () async {
      final s = await _service(FakeApi());
      expect(s.origin, CatalogOrigin.remote);
      expect(s.repository.books.map((b) => b.id), ['col-a', 'col-b']);
      expect(s.repository.hadithCountOfBook('col-a'), 5);
      expect(s.repository.hadithCountOfChapter('bk-1'), 5);
      expect(s.repository.allHadiths, isEmpty);
    });

    test('offline start: last download is used; without cache the catalogue is empty, never bundled', () async {
      final store = InMemorySettingsStore();
      await _service(FakeApi(), store: store);
      final cached = await _service(FakeApi(failMeta: true), store: store);
      expect(cached.origin, CatalogOrigin.cache);
      expect(cached.startupFailure?.kind, CatalogFailureKind.offline);
      expect(cached.repository.books, isNotEmpty);

      final none = await _service(FakeApi(failMeta: true));
      expect(none.origin, CatalogOrigin.unavailable);
      expect(none.repository.books, isEmpty);
      expect(none.repository.allHadiths, isEmpty);
    });

    test('chapter loads page by page (keyset) until the last page', () async {
      final api = FakeApi(total: 5);
      final s = await _service(api, pageSize: 2);
      expect((await s.ensureChapter('bk-1')).status, LoadStatus.loaded);
      expect(api.listCalls, [(null, 2), (2, 2), (4, 2)]);
      expect(s.repository.hadithsOf('bk-1').map((h) => h.displayNumber), ['1a', '2a', '3a', '4a', '5a']);
      // already loaded → no new requests
      await s.ensureChapter('bk-1');
      expect(api.listCalls, hasLength(3));
    });

    test('chapter failure is reported (not an empty success) and can be retried', () async {
      final api = FakeApi()..failNextList = TimeoutException('slow');
      final s = await _service(api);
      final state = await s.ensureChapter('bk-1');
      expect(state.isFailed, isTrue);
      expect(state.failure!.kind, CatalogFailureKind.timeout);
      expect(s.repository.hadithsOf('bk-1'), isEmpty);
      expect((await s.retryChapter('bk-1')).status, LoadStatus.loaded);
    });

    test('detail: full record merged; missing/unpublished is "not found"; errors reported', () async {
      final api = FakeApi();
      final s = await _service(api);
      final h = await s.ensureDetail('h1');
      expect(h!.gradings, hasLength(2));
      expect(s.hasDetail('h1'), isTrue);
      expect(await s.ensureDetail('h99'), isNull);
      expect(s.detailState('h99').failure!.kind, CatalogFailureKind.notFound);
      api.failDetail = const SocketException('x');
      await s.ensureDetail('h2');
      expect(s.detailState('h2').failure!.kind, CatalogFailureKind.offline);
    });

    test('ensureHadiths only requests what is missing', () async {
      final api = FakeApi();
      final s = await _service(api);
      await s.ensureHadiths(['h1', 'h2']);
      await s.ensureHadiths(['h1', 'h2', 'h3']);
      expect(api.idCalls, [
        ['h1', 'h2'],
        ['h3'],
      ]);
    });

    test('searchPage: every filter goes to the database as a bound parameter', () async {
      final api = FakeApi();
      final s = await _service(api);
      await s.searchPage(
        const SearchRequest(
          query: '  نص  ',
          collections: {'col-a'},
          books: {'bk-1'},
          categories: {'iman'},
          grades: {'sahih', 'hasan'},
          translatedOnly: true,
          limit: 999,
        ),
      );
      expect(api.searchCalls.single, {
        'p_query': 'نص',
        'p_collections': ['col-a'],
        'p_books': ['bk-1'],
        'p_categories': ['iman'],
        'p_narrators': null,
        'p_grades': ['hasan', 'sahih'],
        'p_has_translation': true,
        'p_limit': SearchRequest.maxLimit,
        'p_after_rank': null,
        'p_after_collection': null,
        'p_after_position': null,
      });
    });

    test('searchPage: empty query = browse mode, no filters = nulls', () {
      final p = const SearchRequest().toParams();
      expect(p['p_query'], isNull);
      expect(p['p_collections'], isNull);
      expect(p['p_has_translation'], isNull, reason: 'false would hide translated records');
      expect(const SearchRequest(query: '   ').isBrowse, isTrue);
    });

    test('searchPage: cursor pages cover every record once, across rank ties, then stop', () async {
      final api = FakeApi(total: 7);
      final s = await _service(api);
      var request = const SearchRequest(query: 'نص', limit: 2);
      final seen = <String>[];
      var pages = 0;
      while (true) {
        final page = await s.searchPage(request);
        expect(page.failure, isNull);
        seen.addAll(page.hadiths.map((h) => h.id));
        pages++;
        if (!page.hasMore) break;
        request = request.next(page.nextCursor!);
      }
      expect(seen, ['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'h7']);
      expect(pages, 4);
      expect(api.searchCalls[1]['p_after_rank'], 0.9);
      expect(api.searchCalls[1]['p_after_position'], 2);
    });

    test('searchPage: exact multiple of the page size ends with an empty last page', () async {
      final api = FakeApi(total: 4);
      final s = await _service(api);
      final first = await s.searchPage(const SearchRequest(query: 'نص', limit: 4));
      expect(first.hadiths, hasLength(4));
      expect(first.hasMore, isTrue);
      final last = await s.searchPage(const SearchRequest(query: 'نص', limit: 4).next(first.nextCursor!));
      expect(last.hadiths, isEmpty);
      expect(last.hasMore, isFalse);
    });

    test('searchPage: gradings come per scholar; full details are not overwritten', () async {
      final api = FakeApi();
      final s = await _service(api);
      await s.ensureDetail('h1');
      final page = await s.searchPage(const SearchRequest(query: 'نص'));
      final h1 = page.hadiths.firstWhere((h) => h.id == 'h1');
      expect(h1.gradings, hasLength(2), reason: 'detail record (2 gradings) kept');
      final h3 = page.hadiths.firstWhere((h) => h.id == 'h3');
      expect(h3.gradings.single.scholar, 'Scholar A');
      expect(h3.narrator, 'راوي 3');
      expect(page.hadiths.firstWhere((h) => h.id == 'h2').gradings, isEmpty, reason: 'never inferred');
    });

    test('searchPage: failure is reported in Somali, not as empty results', () async {
      final api = FakeApi()..failNextSearch = const SocketException('x');
      final s = await _service(api);
      final page = await s.searchPage(const SearchRequest(query: 'نص'));
      expect(page.failure?.kind, CatalogFailureKind.offline);
      expect(page.hasMore, isFalse);
    });

    test('SearchCursor.afterRow needs the full sort key', () {
      expect(SearchCursor.afterRow({'rank': 0.5, 'collection_id': 'c', 'source_position': 3}), isNotNull);
      expect(SearchCursor.afterRow({'rank': 0.5, 'collection_id': 'c'}), isNull);
    });

    test('records persist offline and are restored', () async {
      final store = InMemorySettingsStore();
      final s = await _service(FakeApi(), store: store);
      await s.ensureDetail('h1');
      final offline = await _service(FakeApi(failMeta: true), store: store);
      expect(offline.repository.hadithById('h1')?.gradings, hasLength(2));
      expect(offline.hasDetail('h1'), isTrue);
    });
  });

  group('Screens on the backend (fake API)', () {
    Future<AppServices> pump(
      WidgetTester tester,
      String route, {
      FakeApi? api,
      InMemorySettingsStore? store,
      bool settle = true,
    }) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final services = await AppServices.create(
        store ?? InMemorySettingsStore({'auth.onboardingSeen': true}),
        catalogApi: api ?? FakeApi(),
      );
      await tester.pumpWidget(XadiisApp(services: services, initialLocation: route));
      if (settle) await tester.pumpAndSettle();
      return services;
    }

    testWidgets('Kutubta shows published collections with server counts, no demo badge', (tester) async {
      await pump(tester, AppRoutes.books);
      expect(find.text('Ururinta A'), findsOneWidget);
      expect(find.text('5 xadiis'), findsOneWidget);
      expect(find.text('Tusaale'), findsNothing);
    });

    testWidgets('chapter downloads its records and lists them with original numbers', (tester) async {
      await pump(tester, AppRoutes.chapter('col-a', 'bk-1'));
      expect(find.textContaining('TEST ONLY 1'), findsWidgets);
      expect(find.textContaining('5 xadiis'), findsOneWidget);
    });

    testWidgets('chapter error shows a Somali message with retry', (tester) async {
      final api = FakeApi()..failNextList = const SocketException('x');
      await pump(tester, AppRoutes.chapter('col-a', 'bk-1'), api: api);
      expect(find.text('Xadiisyada lama soo rari karin'), findsOneWidget);
      await tester.tap(find.text('Isku day mar kale'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TEST ONLY 1'), findsWidgets);
    });

    testWidgets('detail shows Arabic RTL, every grading with scholar, and the disagreement chip', (tester) async {
      await pump(tester, AppRoutes.hadith('h1'));
      expect(find.text(_ar1), findsOneWidget);
      expect(Directionality.of(tester.element(find.text(_ar1))), TextDirection.rtl);
      expect(find.text('Darajooyin kala duwan — eeg Tixraaca'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Scholar B'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Saxiix — Scholar A · Ref A'), findsOneWidget);
      expect(find.textContaining('Xasan — Scholar B · Ref B'), findsOneWidget);
      expect(find.textContaining('Draft scholar'), findsNothing);
    });

    testWidgets('unknown/unpublished hadith shows not found (no placeholder)', (tester) async {
      await pump(tester, AppRoutes.hadith('h99'));
      expect(find.text('Xadiiskan lama helin'), findsOneWidget);
    });

    testWidgets('offline with nothing cached: clear error with retry, no bundled content', (tester) async {
      final api = FakeApi(failMeta: true);
      await pump(tester, AppRoutes.books, api: api);
      expect(find.text('Xogta lama soo dejin karo'), findsOneWidget);
      api.failMeta = false;
      await tester.tap(find.text('Isku day mar kale'));
      await tester.pumpAndSettle();
      expect(find.text('Ururinta A'), findsOneWidget);
    });

    testWidgets('search needs 2+ letters before calling the server', (tester) async {
      final api = FakeApi();
      await pump(tester, AppRoutes.searchWith(query: 'x'), api: api);
      expect(find.text('Qor ugu yaraan 2 xaraf'), findsOneWidget);
      expect(api.searchCalls, isEmpty);
    });
    testWidgets('search results come from the server with grade and narrator', (tester) async {
      final api = FakeApi();
      await pump(tester, AppRoutes.searchWith(query: 'نص'), api: api);
      expect(api.searchCalls, hasLength(1));
      expect(find.textContaining('5 natiijo'), findsOneWidget);
      expect(find.textContaining('TEST ONLY 3'), findsWidgets);
      expect(find.text('Saxiix · Scholar A'), findsWidgets);
      expect(find.text('راوي 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Natiijooyinka waa dhammaadeen'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Natiijooyinka waa dhammaadeen'), findsOneWidget);
    });

    testWidgets('infinite scroll loads every page once, without duplicates', (tester) async {
      final api = FakeApi(total: 45);
      await pump(tester, AppRoutes.searchWith(query: 'نص'), api: api);
      for (var i = 0; i < 30; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
        await tester.pumpAndSettle();
        if (find.text('Natiijooyinka waa dhammaadeen').evaluate().isNotEmpty) break;
      }
      expect(find.text('Natiijooyinka waa dhammaadeen'), findsOneWidget);
      expect(find.textContaining('45 natiijo'), findsNothing, reason: 'header scrolled away');
      expect(api.searchCalls.map((c) => c['p_after_position']), [null, 20, 40]);
      await tester.drag(find.byType(ListView).last, const Offset(0, 20000));
      await tester.pumpAndSettle();
      expect(find.textContaining('45 natiijo'), findsOneWidget);
    });

    testWidgets('a failed next page keeps results and retries the same cursor', (tester) async {
      final api = FakeApi(total: 30);
      await pump(tester, AppRoutes.searchWith(query: 'نص'), api: api);
      api.failNextSearch = const SocketException('x');
      final list = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(find.text('Bogga xiga lama soo rari karin'), 500, scrollable: list);
      expect(find.textContaining('TEST ONLY'), findsWidgets);
      await tester.ensureVisible(find.text('Isku day mar kale'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Isku day mar kale'));
      await tester.pumpAndSettle();
      expect(api.searchCalls.map((c) => c['p_after_position']), [null, 20, 20]);
      await tester.scrollUntilVisible(find.text('Natiijooyinka waa dhammaadeen'), 500, scrollable: list);
      expect(find.text('Bogga xiga lama soo rari karin'), findsNothing);
    });

    testWidgets('first-page failure shows a Somali error with retry', (tester) async {
      final api = FakeApi()..failNextSearch = const SocketException('x');
      await pump(tester, AppRoutes.searchWith(query: 'نص'), api: api);
      expect(find.text('Raadintu way fashilantay'), findsOneWidget);
      await tester.tap(find.text('Isku day mar kale'));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 natiijo'), findsOneWidget);
    });

    testWidgets('a stale response (query changed meanwhile) is never shown', (tester) async {
      final gate = Completer<void>();
      final api = FakeApi()..searchGate = gate;
      await pump(tester, AppRoutes.searchWith(query: 'نص'), api: api, settle: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(api.searchCalls.map((c) => c['p_query']), ['نص']);
      // Change the query while the first request is still waiting.
      api.searchGate = null;
      await tester.enterText(find.byType(TextField), 'ONLY 3');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(api.searchCalls.map((c) => c['p_query']), ['نص', 'ONLY 3']);
      expect(find.textContaining('1 natiijo'), findsOneWidget);
      gate.complete(); // the old request (5 results) finishes late
      await tester.pumpAndSettle();
      expect(find.textContaining('1 natiijo'), findsOneWidget);
      expect(find.textContaining('5 natiijo'), findsNothing);
    });

    testWidgets('filters alone browse the server (no text needed)', (tester) async {
      final api = FakeApi();
      await pump(tester, AppRoutes.searchWith(bookId: 'col-a'), api: api);
      expect(api.searchCalls.single['p_query'], isNull);
      expect(api.searchCalls.single['p_collections'], ['col-a']);
      expect(find.textContaining('natiijo · shaandhayn'), findsOneWidget);
    });

    testWidgets('favourites screen downloads saved records by id', (tester) async {
      final api = FakeApi();
      await pump(
        tester,
        AppRoutes.favorites,
        api: api,
        store: InMemorySettingsStore({
          'auth.onboardingSeen': true,
          'favorites.hadithIds': ['h2'],
        }),
      );
      expect(find.textContaining('TEST ONLY 2'), findsWidgets);
      expect(find.text('Ka saar kuwa maqan'), findsNothing);
    });
  });
}
