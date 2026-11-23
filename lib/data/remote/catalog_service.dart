import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';
import '../models/hadith.dart';
import '../repositories/hadith_repository.dart';
import 'catalog_api.dart';
import 'catalog_mapper.dart';

/// Where the catalogue on screen came from.
enum CatalogOrigin {
  /// Bundled with the app (no backend configured).
  bundled,

  /// Downloaded from Supabase at this start.
  remote,

  /// The last successful download (backend unreachable now).
  cache,

  /// Backend configured but unreachable and nothing cached yet.
  unavailable,
}

enum LoadStatus { idle, loading, loaded, failed }

class LoadState {
  const LoadState(this.status, [this.failure]);

  static const idle = LoadState(LoadStatus.idle);
  static const loading = LoadState(LoadStatus.loading);
  static const loaded = LoadState(LoadStatus.loaded);

  final LoadStatus status;
  final CatalogFailure? failure;

  bool get isLoading => status == LoadStatus.loading;
  bool get isFailed => status == LoadStatus.failed;
}

/// One page of server search results.
class SearchPage {
  const SearchPage(this.hadiths, {this.nextCursor, this.failure});

  final List<Hadith> hadiths;

  /// Where the next page starts; null when this was the last page.
  final SearchCursor? nextCursor;
  final CatalogFailure? failure;

  bool get hasMore => nextCursor != null;
}

/// Loads the published catalogue from Supabase into [HadithRepository] on
/// demand, with an offline cache. The repository stays the single source the
/// screens read from; this service only fills it and reports load states.
///
/// Never loads the whole database: metadata at start, chapters page by page,
/// records by id, search on the server.
class CatalogService extends ChangeNotifier {
  CatalogService(this._api, this.repository, this._store, {this.pageSize = 100, this.maxCachedRecords = 600});

  static const metaCacheKey = 'catalog.v2.meta';
  static const recordsCacheKey = 'catalog.v2.records';

  final CatalogApi _api;
  final HadithRepository repository;
  final SettingsStore _store;
  final int pageSize;
  final int maxCachedRecords;

  CatalogOrigin _origin = CatalogOrigin.unavailable;
  CatalogFailure? _startupFailure;
  final _chapterStates = <String, LoadState>{};
  final _detailStates = <String, LoadState>{};
  final _detailLoaded = <String>{};
  final _cachedOrder = <String>[]; // most recent first

  CatalogOrigin get origin => _origin;

  /// Why the start-up download failed (null when it succeeded).
  CatalogFailure? get startupFailure => _startupFailure;

  LoadState chapterState(String chapterId) => _chapterStates[chapterId] ?? LoadState.idle;
  LoadState detailState(String hadithId) => _detailStates[hadithId] ?? LoadState.idle;
  bool hasDetail(String hadithId) => _detailLoaded.contains(hadithId);

  String? _collectionName(String collectionId) => repository.bookById(collectionId)?.nameSomali;

  // -------------------------------------------------------------- start-up --

  /// Downloads metadata; on failure falls back to the cached metadata and
  /// records. Never throws.
  Future<CatalogOrigin> start({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final results = await Future.wait([_api.collections(), _api.books(), _api.categories(), _api.counts()])
          .timeout(timeout);
      _applyMeta(results[0], results[1], results[2], results[3]);
      await _write(metaCacheKey, jsonEncode({'c': results[0], 'b': results[1], 'g': results[2], 'n': results[3]}));
      _origin = CatalogOrigin.remote;
      _startupFailure = null;
    } catch (e) {
      _startupFailure = CatalogFailure.from(e);
      debugPrint('Catalogue download failed: $_startupFailure');
      final cached = await _read(metaCacheKey);
      if (cached != null) {
        try {
          final m = jsonDecode(cached) as Map<String, dynamic>;
          List<Map<String, dynamic>> rows(String k) => [
            for (final r in (m[k] as List)) Map<String, dynamic>.from(r as Map),
          ];
          _applyMeta(rows('c'), rows('b'), rows('g'), rows('n'));
          _origin = CatalogOrigin.cache;
        } catch (_) {
          _origin = CatalogOrigin.unavailable;
        }
      } else {
        _origin = CatalogOrigin.unavailable;
        // Nothing to show: an empty catalogue, never bundled placeholders.
        repository.replaceCatalog(books: const [], chapters: const []);
      }
    }
    await _restoreRecords();
    notifyListeners();
    return _origin;
  }

  void _applyMeta(
    List<Map<String, dynamic>> collections,
    List<Map<String, dynamic>> books,
    List<Map<String, dynamic>> categories,
    List<Map<String, dynamic>> counts,
  ) {
    final c = CatalogMapper.collections(collections);
    final (bookCounts, chapterCounts) = CatalogMapper.counts(counts);
    repository.replaceCatalog(
      books: c,
      chapters: CatalogMapper.books(books, {for (final x in c) x.id}),
      categories: CatalogMapper.categories(categories),
      bookCounts: bookCounts,
      chapterCounts: chapterCounts,
    );
  }

  // --------------------------------------------------------------- chapters --

  /// Loads every published record of [chapterId] (a v2 book), page by page.
  Future<LoadState> ensureChapter(String chapterId) async {
    final current = chapterState(chapterId);
    if (current.isLoading || current.status == LoadStatus.loaded) return current;
    _setChapter(chapterId, LoadState.loading);
    try {
      int? after;
      while (true) {
        final rows = await _api.listItems(bookId: chapterId, afterPosition: after, limit: pageSize);
        final page = [
          for (final r in rows) ?CatalogMapper.listItem(r, collectionName: _collectionName('${r['collection_id']}')),
        ];
        // Keep fuller detail records already in the cache.
        repository.mergeHadiths(page.where((h) => !_detailLoaded.contains(h.id)));
        _remember(page);
        if (rows.length < pageSize) break;
        after = page.isEmpty ? null : page.last.number;
        if (after == null) break;
      }
      _setChapter(chapterId, LoadState.loaded);
      await _persistRecords();
    } catch (e) {
      _setChapter(chapterId, LoadState(LoadStatus.failed, CatalogFailure.from(e)));
    }
    return chapterState(chapterId);
  }

  /// Retry after a failure.
  Future<LoadState> retryChapter(String chapterId) {
    _chapterStates.remove(chapterId);
    return ensureChapter(chapterId);
  }

  void _setChapter(String id, LoadState s) {
    _chapterStates[id] = s;
    notifyListeners();
  }

  // ---------------------------------------------------------------- records --

  /// Full record (translations, gradings, narrators). Returns null when the
  /// record does not exist or is not published.
  Future<Hadith?> ensureDetail(String id, {bool force = false}) async {
    if (!force && _detailLoaded.contains(id)) return repository.hadithById(id);
    if (detailState(id).isLoading) return repository.hadithById(id);
    _detailStates[id] = LoadState.loading;
    notifyListeners();
    try {
      final row = await _api.hadithDetail(id);
      final h = row == null
          ? null
          : CatalogMapper.detail(row, collectionName: _collectionName('${row['collection_id']}'));
      if (h == null) {
        _detailStates[id] = const LoadState(LoadStatus.failed, CatalogFailure(CatalogFailureKind.notFound));
      } else {
        _detailLoaded.add(id);
        repository.mergeHadiths([h]);
        _remember([h]);
        _detailStates[id] = LoadState.loaded;
        await _persistRecords();
      }
    } catch (e) {
      _detailStates[id] = LoadState(LoadStatus.failed, CatalogFailure.from(e));
    }
    notifyListeners();
    return repository.hadithById(id);
  }

  /// Makes sure the given records are in the cache (favourites, history,
  /// memorisation lists). Returns a failure when the download failed.
  Future<CatalogFailure?> ensureHadiths(Iterable<String> ids) async {
    final missing = {
      for (final id in ids)
        if (repository.hadithById(id) == null) id,
    }.toList();
    if (missing.isEmpty) return null;
    try {
      for (var i = 0; i < missing.length; i += 100) {
        final chunk = missing.sublist(i, (i + 100).clamp(0, missing.length));
        final rows = await _api.listItemsByIds(chunk);
        final found = [
          for (final r in rows) ?CatalogMapper.listItem(r, collectionName: _collectionName('${r['collection_id']}')),
        ];
        repository.mergeHadiths(found);
        _remember(found);
      }
      await _persistRecords();
      return null;
    } catch (e) {
      return CatalogFailure.from(e);
    }
  }

  // ----------------------------------------------------------------- search --

  /// One page of `search_hadiths_v2`. Filters are evaluated by the database.
  /// Records already loaded with full details are not overwritten by the
  /// shorter search row. [SearchPage.nextCursor] is null on the last page.
  Future<SearchPage> searchPage(SearchRequest request) async {
    try {
      final rows = await _api.searchPage(request);
      final hits = <Hadith>[];
      final seen = <String>{};
      for (final r in rows) {
        final h = CatalogMapper.searchRow(r, collectionName: _collectionName('${r['collection_id']}'));
        if (h != null && seen.add(h.id)) hits.add(h);
      }
      final fresh = hits.where((h) => !_detailLoaded.contains(h.id)).toList();
      if (fresh.isNotEmpty) {
        repository.mergeHadiths(fresh);
        _remember(fresh);
        unawaited(_persistRecords());
      }
      final full = rows.length >= request.limit.clamp(1, SearchRequest.maxLimit);
      return SearchPage([
        for (final h in hits) repository.hadithById(h.id) ?? h,
      ], nextCursor: full && rows.isNotEmpty ? SearchCursor.afterRow(rows.last) : null);
    } catch (e) {
      return SearchPage(const [], failure: CatalogFailure.from(e));
    }
  }

  /// Hadith of the day chosen by the server (same for everyone).
  Future<Hadith?> daily(DateTime day) async {
    try {
      final rows = await _api.daily(day);
      if (rows.isEmpty) return null;
      final h = CatalogMapper.listItem(rows.first, collectionName: _collectionName('${rows.first['collection_id']}'));
      if (h != null && repository.hadithById(h.id) == null) repository.mergeHadiths([h]);
      return h == null ? null : repository.hadithById(h.id);
    } catch (e) {
      debugPrint('Daily hadith unavailable: ${CatalogFailure.from(e)}');
      return null;
    }
  }

  // ------------------------------------------------------------ offline cache

  void _remember(Iterable<Hadith> records) {
    for (final h in records) {
      _cachedOrder
        ..remove(h.id)
        ..insert(0, h.id);
    }
    if (_cachedOrder.length > maxCachedRecords) _cachedOrder.removeRange(maxCachedRecords, _cachedOrder.length);
  }

  Future<void> _persistRecords() async {
    final records = [
      for (final id in _cachedOrder)
        if (repository.hadithById(id) case final h?) CatalogMapper.hadithToJson(h),
    ];
    await _write(recordsCacheKey, jsonEncode(records));
  }

  Future<void> _restoreRecords() async {
    final raw = await _read(recordsCacheKey);
    if (raw == null) return;
    try {
      final records = [
        for (final j in (jsonDecode(raw) as List)) ?CatalogMapper.hadithFromJson(Map<String, dynamic>.from(j as Map)),
      ];
      final bookIds = {for (final b in repository.books) b.id};
      final valid = [
        for (final h in records)
          if (bookIds.contains(h.bookId)) h,
      ];
      repository.mergeHadiths(valid);
      for (final h in valid.reversed) {
        _remember([h]);
        if (h.gradings.isNotEmpty || h.source != null) _detailLoaded.add(h.id);
      }
    } catch (_) {
      // corrupted cache → ignored
    }
  }

  /// Removes cached catalogue data (used by "delete all local data").
  Future<void> clearCache() async {
    _cachedOrder.clear();
    try {
      await _store.remove(metaCacheKey);
      await _store.remove(recordsCacheKey);
    } catch (_) {}
  }

  Future<String?> _read(String key) async {
    try {
      return await _store.getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _store.setString(key, value);
    } catch (_) {}
  }
}
