import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw read access to the v2 catalogue (docs/BACKEND_DESIGN.md §5). Returns
/// table rows; mapping to app models lives in `catalog_mapper.dart`. Every
/// method throws [CatalogFailure] on error — never an empty "success".
abstract class CatalogApi {
  Future<List<Map<String, dynamic>>> collections();
  Future<List<Map<String, dynamic>>> books();
  Future<List<Map<String, dynamic>>> categories();
  Future<List<Map<String, dynamic>>> counts();

  /// Published list rows of one v2 book (an app "chapter"), keyset-paginated
  /// by `source_position`.
  Future<List<Map<String, dynamic>>> listItems({required String bookId, int? afterPosition, int limit = 100});

  /// Published list rows for specific ids (favourites, history, search hits).
  Future<List<Map<String, dynamic>>> listItemsByIds(List<String> ids);

  /// One published hadith with its published translations, gradings,
  /// narrators and topics; null when it does not exist or is not published.
  Future<Map<String, dynamic>?> hadithDetail(String id);

  /// `search_hadiths_v2` RPC → one page of ranked rows. All filters are
  /// evaluated by the database; paging is keyset (see [SearchCursor]).
  Future<List<Map<String, dynamic>>> searchPage(SearchRequest request);

  /// `daily_hadith` RPC → zero or one list row.
  Future<List<Map<String, dynamic>>> daily(DateTime day);
}

/// Position after the last row of a page: (rank, collection, position) is
/// the database's deterministic sort key, so pages never overlap or skip.
@immutable
class SearchCursor {
  const SearchCursor({required this.rank, required this.collectionId, required this.position});

  /// Cursor after [row] (a `search_hadiths_v2` row); null if the row lacks
  /// the key columns.
  static SearchCursor? afterRow(Map<String, dynamic> row) {
    final rank = row['rank'];
    final collection = row['collection_id'];
    final position = row['source_position'];
    if (rank is! num || collection is! String || position is! num) return null;
    return SearchCursor(rank: rank, collectionId: collection, position: position.toInt());
  }

  final num rank;
  final String collectionId;
  final int position;

  @override
  bool operator ==(Object other) =>
      other is SearchCursor && other.rank == rank && other.collectionId == collectionId && other.position == position;

  @override
  int get hashCode => Object.hash(rank, collectionId, position);

  @override
  String toString() => 'SearchCursor($rank, $collectionId, $position)';
}

/// Parameters of one `search_hadiths_v2` call. Empty sets mean "no filter".
@immutable
class SearchRequest {
  const SearchRequest({
    this.query = '',
    this.collections = const {},
    this.books = const {},
    this.categories = const {},
    this.narrators = const {},
    this.grades = const {},
    this.translatedOnly = false,
    this.limit = 20,
    this.cursor,
  });

  static const maxLimit = 50;

  final String query;
  final Set<String> collections;

  /// v2 book ids (app chapters).
  final Set<String> books;
  final Set<String> categories;
  final Set<String> narrators;
  final Set<String> grades;
  final bool translatedOnly;
  final int limit;
  final SearchCursor? cursor;

  /// Browse mode: no text, filters only.
  bool get isBrowse => query.trim().isEmpty;

  SearchRequest next(SearchCursor cursor) => SearchRequest(
    query: query,
    collections: collections,
    books: books,
    categories: categories,
    narrators: narrators,
    grades: grades,
    translatedOnly: translatedOnly,
    limit: limit,
    cursor: cursor,
  );

  /// RPC parameters (values are bound by PostgREST — never interpolated).
  Map<String, dynamic> toParams() {
    List<String>? list(Set<String> s) => s.isEmpty ? null : (s.toList()..sort());
    final q = query.trim();
    return {
      'p_query': q.isEmpty ? null : q,
      'p_collections': list(collections),
      'p_books': list(books),
      'p_categories': list(categories),
      'p_narrators': list(narrators),
      'p_grades': list(grades),
      'p_has_translation': translatedOnly ? true : null,
      'p_limit': limit.clamp(1, maxLimit),
      'p_after_rank': cursor?.rank,
      'p_after_collection': cursor?.collectionId,
      'p_after_position': cursor?.position,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is SearchRequest &&
      other.query == query &&
      setEquals(other.collections, collections) &&
      setEquals(other.books, books) &&
      setEquals(other.categories, categories) &&
      setEquals(other.narrators, narrators) &&
      setEquals(other.grades, grades) &&
      other.translatedOnly == translatedOnly &&
      other.limit == limit &&
      other.cursor == cursor;

  @override
  int get hashCode => Object.hash(
    query,
    Object.hashAllUnordered(collections),
    Object.hashAllUnordered(books),
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(narrators),
    Object.hashAllUnordered(grades),
    translatedOnly,
    limit,
    cursor,
  );
}

enum CatalogFailureKind { offline, timeout, permission, notFound, server, malformed }

/// A backend error with a Somali message for the UI.
class CatalogFailure implements Exception {
  const CatalogFailure(this.kind, [this.detail]);

  final CatalogFailureKind kind;

  /// Technical detail for logs only — never shown to users.
  final String? detail;

  String get message => switch (kind) {
    CatalogFailureKind.offline => 'Internet lama heli karo. Hubi xiriirka kadibna isku day mar kale.',
    CatalogFailureKind.timeout => 'Server-ku wuu daahay. Fadlan isku day mar kale.',
    CatalogFailureKind.permission => 'Ma haysatid oggolaansho aad ku aragto xogtan.',
    CatalogFailureKind.notFound => 'Xogtan lama helin.',
    CatalogFailureKind.server => 'Cillad ayaa ka dhacday server-ka. Fadlan isku day goor dambe.',
    CatalogFailureKind.malformed => 'Xogta server-ka si sax ah looma akhrin karo.',
  };

  @override
  String toString() => 'CatalogFailure($kind${detail == null ? '' : ': $detail'})';

  /// Maps any thrown error to a [CatalogFailure].
  static CatalogFailure from(Object error) {
    if (error is CatalogFailure) return error;
    if (error is TimeoutException) return CatalogFailure(CatalogFailureKind.timeout, '$error');
    if (error is SocketException || error is HttpException) {
      return CatalogFailure(CatalogFailureKind.offline, '$error');
    }
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == '42501' || code == 'PGRST301' || code == '401' || code == '403') {
        return CatalogFailure(CatalogFailureKind.permission, code);
      }
      if (code == 'PGRST116' || code == 'PGRST205' || code == '42P01' || code == '404') {
        return CatalogFailure(CatalogFailureKind.notFound, code);
      }
      return CatalogFailure(CatalogFailureKind.server, '${error.code}: ${error.message}');
    }
    if (error is FormatException || error is TypeError) {
      return CatalogFailure(CatalogFailureKind.malformed, '$error');
    }
    final text = '$error';
    if (text.contains('ClientException') || text.contains('Failed host lookup') || text.contains('XMLHttpRequest')) {
      return CatalogFailure(CatalogFailureKind.offline, text);
    }
    return CatalogFailure(CatalogFailureKind.server, text);
  }
}

const _listColumns =
    'id,collection_id,book_id,chapter_id,numbering_scheme,hadith_number,source_position,'
    'arabic_display,narrator_text_ar,somali_text,translator';

const _detailColumns =
    'id,collection_id,book_id,chapter_id,numbering_scheme,hadith_number,source_position,status,'
    'arabic_text,arabic_text_vowelized,vowelized_verified,narrator_text_ar,'
    'source_name,source_edition,source_url,'
    'translations(language,text,translator,translation_source,source_url,is_primary,status),'
    'gradings(grade,grade_label_ar,scholar,source_reference,source_url,disagreement_notes,status),'
    'hadith_narrators(role,position,narrators(name_ar,status)),'
    'hadith_categories(category_id)';

const _audioColumns = 'audio_url,reciter,source_name,source_url,license,duration_seconds,language,verified_at,status';

/// v2 catalogue over the official Supabase client (publishable key + RLS).
class SupabaseCatalogApi implements CatalogApi {
  SupabaseCatalogApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(timeout);
    } catch (e) {
      throw CatalogFailure.from(e);
    }
  }

  List<Map<String, dynamic>> _rows(Object? data) => [
    for (final r in (data as List)) Map<String, dynamic>.from(r as Map),
  ];

  @override
  Future<List<Map<String, dynamic>>> collections() =>
      _run(() async => _rows(await _client.from('collections').select().order('sort_order')));

  @override
  Future<List<Map<String, dynamic>>> books() => _run(
    () async => _rows(
      await _client
          .from('books')
          .select('id,collection_id,book_number,title_ar,title_en,title_so,sort_order')
          .order('sort_order'),
    ),
  );

  @override
  Future<List<Map<String, dynamic>>> categories() =>
      _run(() async => _rows(await _client.from('categories').select().order('sort_order')));

  @override
  Future<List<Map<String, dynamic>>> counts() => _run(() async => _rows(await _client.from('catalog_counts').select()));

  @override
  Future<List<Map<String, dynamic>>> listItems({required String bookId, int? afterPosition, int limit = 100}) =>
      _run(() async {
        var q = _client.from('hadith_list_items').select(_listColumns).eq('book_id', bookId);
        if (afterPosition != null) q = q.gt('source_position', afterPosition);
        return _rows(await q.order('source_position').limit(limit));
      });

  @override
  Future<List<Map<String, dynamic>>> listItemsByIds(List<String> ids) => _run(() async {
    if (ids.isEmpty) return const [];
    return _rows(await _client.from('hadith_list_items').select(_listColumns).inFilter('id', ids));
  });

  @override
  Future<Map<String, dynamic>?> hadithDetail(String id) => _run(() async {
    final rows = _rows(
      await _client
          .from('hadiths')
          .select(_detailColumns)
          .eq('id', id)
          // Explicit filters: a reviewer's session must not cache drafts.
          .eq('status', 'published')
          .eq('translations.status', 'published')
          .eq('gradings.status', 'published'),
    );
    if (rows.isEmpty) return null;
    return {...rows.single, 'hadith_audio': await _audioOf(id)};
  });

  /// Published recitations of a hadith (migration 0010). Audio is optional:
  /// if the table is missing or the request fails, the hadith still loads.
  Future<List<Map<String, dynamic>>> _audioOf(String hadithId) async {
    try {
      return _rows(
        await _client
            .from('hadith_audio')
            .select(_audioColumns)
            .eq('hadith_id', hadithId)
            .eq('status', 'published')
            .order('is_primary', ascending: false)
            .limit(1),
      );
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchPage(SearchRequest request) =>
      _run(() async => _rows(await _client.rpc('search_hadiths_v2', params: request.toParams())));

  @override
  Future<List<Map<String, dynamic>>> daily(DateTime day) => _run(() async {
    final d =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    return _rows(await _client.rpc('daily_hadith', params: {'p_day': d}));
  });
}
