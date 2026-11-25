import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/hadith.dart';
import '../../../data/remote/catalog_api.dart';
import '../../../data/remote/catalog_service.dart';
import '../domain/search_options.dart';
import 'widgets/search_filter_sheet.dart';
import 'widgets/search_result_card.dart';
import 'widgets/search_states.dart';

/// Tab 3 — "Raadi Xadiis". UI state (query, filters, sort) lives here; all
/// matching / filtering / sorting is done by `HadithSearchService`. The tab's
/// IndexedStack keeps this state while the user reads a result.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.initialCategoryId, this.initialBookId});

  static const title = 'Raadi Xadiis';
  static const hint = 'Raadi xadiis';

  /// Short pause after typing before searching (fewer rebuilds while typing).
  static const debounce = Duration(milliseconds: 250);

  /// From `/search?q=&category=&book=`; unknown IDs are ignored.
  final String? initialQuery;
  final String? initialCategoryId;
  final String? initialBookId;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';
  SearchFilters _filters = SearchFilters.none;
  SearchSort _sort = SearchSort.dataset;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _applyRouteParams();
    }
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (old.initialQuery != widget.initialQuery ||
        old.initialCategoryId != widget.initialCategoryId ||
        old.initialBookId != widget.initialBookId) {
      _applyRouteParams();
    }
  }

  /// Applies `?q=&category=&book=` (invalid IDs are dropped by sanitize).
  void _applyRouteParams() {
    final q = widget.initialQuery?.trim() ?? '';
    final hasParams = q.isNotEmpty || widget.initialCategoryId != null || widget.initialBookId != null;
    if (!hasParams) return;
    _controller.text = q;
    _query = q;
    _filters = context.services.search.sanitize(
      SearchFilters(categoryIds: {?widget.initialCategoryId}, bookIds: {?widget.initialBookId}),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(SearchScreen.debounce, () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _onSubmitted(String value) {
    _debounceTimer?.cancel();
    setState(() => _query = value);
  }

  void _clearQuery() {
    _debounceTimer?.cancel();
    setState(() => _query = '');
  }

  void _resetAll() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() {
      _query = '';
      _filters = SearchFilters.none;
      _sort = SearchSort.dataset;
    });
  }

  Future<void> _openFilters() async {
    final result = await showSearchFilterSheet(context, _filters);
    if (result != null && mounted) setState(() => _filters = result);
  }

  void _browseCategories() => context.go(AppRoutes.categories);

  bool get _hasCriteria => _query.trim().isNotEmpty || !_filters.isEmpty;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    return Scaffold(
      appBar: AppTopBar(
        title: context.tr(AppText.titleSearch),
        showOrnament: true,
        actions: [
          if (_hasCriteria)
            IconActionButton(icon: Icons.restart_alt_rounded, tooltip: 'Dib u deji raadinta', onPressed: _resetAll),
        ],
      ),
      body: Column(
        children: [
          AppPageBody(
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _controller,
                    hintText: SearchScreen.hint,
                    onChanged: _onChanged,
                    onSubmitted: _onSubmitted,
                    onCleared: _clearQuery,
                  ),
                ),
                AppSpacing.gapXs,
                Badge(
                  isLabelVisible: _filters.activeCount > 0,
                  label: Text('${_filters.activeCount}'),
                  child: IconButton.filledTonal(
                    tooltip: 'Shaandhee',
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ),
          if (!_filters.isEmpty) _ActiveFilters(filters: _filters, onChanged: (f) => setState(() => _filters = f)),
          AppSpacing.gapXs,
          Expanded(
            child: !_hasCriteria
                ? SearchInitialView(
                    onCategory: (id) => setState(() => _filters = SearchFilters(categoryIds: {id})),
                    onBrowseCategories: _browseCategories,
                  )
                : services.catalog != null
                ? _RemoteResults(
                    key: ValueKey('$_query|${_filters.hashCode}'),
                    query: _query,
                    filters: _filters,
                    onResetFilters: () => setState(() => _filters = SearchFilters.none),
                    onBrowseCategories: _browseCategories,
                  )
                : ListenableBuilder(
                    // Only results depend on bookmarks (for the bookmark filter).
                    listenable: services.favorites,
                    builder: (context, _) {
                      final results = services.search.search(
                        query: _query,
                        filters: _filters,
                        sort: _sort,
                        favoriteIds: services.favorites.ids.toSet(),
                      );
                      if (results.isEmpty) {
                        return SearchNoResultsView(
                          hasFilters: !_filters.isEmpty,
                          onResetFilters: () => setState(() => _filters = SearchFilters.none),
                          onBrowseCategories: _browseCategories,
                        );
                      }
                      final tokens = ArabicNormalizer.tokens(_query);
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        itemCount: results.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return AppPageBody(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text('${results.length} natiijo', style: context.textStyles.labelMedium),
                                    ),
                                  ),
                                  _SortButton(value: _sort, onChanged: (s) => setState(() => _sort = s)),
                                ],
                              ),
                            );
                          }
                          final h = results[i - 1];
                          return AppPageBody(
                            key: ValueKey(h.id),
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                            child: SearchResultCard(hadith: h, tokens: tokens),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Removable chips for every active filter.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    final chips = <Widget>[
      for (final id in filters.bookIds)
        InputChip(
          label: Text(repo.bookById(id)?.nameSomali ?? id),
          avatar: const Icon(Icons.menu_book_outlined, size: 16),
          onDeleted: () => onChanged(filters.copyWith(bookIds: {...filters.bookIds}..remove(id))),
          deleteButtonTooltipMessage: 'Ka saar shaandhaynta',
        ),
      for (final id in filters.categoryIds)
        InputChip(
          label: Text(repo.categoryById(id)?.nameSomali ?? id),
          avatar: const Icon(Icons.label_outline_rounded, size: 16),
          onDeleted: () => onChanged(filters.copyWith(categoryIds: {...filters.categoryIds}..remove(id))),
          deleteButtonTooltipMessage: 'Ka saar shaandhaynta',
        ),
      if (filters.bookmark != BookmarkFilter.all)
        InputChip(
          label: Text(filters.bookmark.label),
          avatar: const Icon(Icons.bookmark_outline_rounded, size: 16),
          onDeleted: () => onChanged(filters.copyWith(bookmark: BookmarkFilter.all)),
          deleteButtonTooltipMessage: 'Ka saar shaandhaynta',
        ),
    ];
    return SizedBox(
      height: AppSizes.minTouchTarget + AppSpacing.xs,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
        itemCount: chips.length + 1,
        separatorBuilder: (_, _) => AppSpacing.gapXs,
        itemBuilder: (context, i) => i < chips.length
            ? Center(child: chips[i])
            : Center(
                child: AppTextButton(label: 'Tirtir shaandhaynta', onPressed: () => onChanged(SearchFilters.none)),
              ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final SearchSort value;
  final ValueChanged<SearchSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SearchSort>(
      tooltip: 'Kala soocid',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [for (final s in SearchSort.values) PopupMenuItem(value: s, child: Text(s.label))],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget, maxWidth: 220),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: AppSizes.iconSm, color: context.colors.primary),
            AppSpacing.gapXxs,
            Flexible(
              child: Text(
                value.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.labelMedium?.copyWith(color: context.colors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Server-side search (backend): `search_hadiths_v2`, cursor pages of
/// [pageSize] with infinite scroll and pull-to-refresh.
///
/// * Text, collections, chapters, topics, grades and "has translation" are
///   evaluated by the database. Only the bookmark filter is applied on the
///   device (bookmarks are private), so more pages load automatically while
///   the visible list is too short.
/// * Order is the server's (relevance, then collection + position) — the
///   only order that stays correct across pages.
/// * Every request carries a generation number; a response for an older
///   generation (refresh/reset/dispose meanwhile) is dropped. Only one page
///   request runs at a time; rows already shown are never added twice.
class _RemoteResults extends StatefulWidget {
  const _RemoteResults({
    super.key,
    required this.query,
    required this.filters,
    required this.onResetFilters,
    required this.onBrowseCategories,
  });

  final String query;
  final SearchFilters filters;
  final VoidCallback onResetFilters;
  final VoidCallback onBrowseCategories;

  @override
  State<_RemoteResults> createState() => _RemoteResultsState();
}

class _RemoteResultsState extends State<_RemoteResults> {
  static const pageSize = 20;

  /// Start loading the next page this close to the end of the list.
  static const loadAheadPx = 600.0;

  final _scroll = ScrollController();
  final _results = <Hadith>[];
  final _ids = <String>{};
  SearchCursor? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  bool _started = false;
  CatalogFailure? _failure;
  int _generation = 0;

  String get _q => widget.query.trim();
  bool get _tooShort => _q.isNotEmpty && _q.characters.length < 2;

  SearchRequest get _request {
    final f = widget.filters;
    return SearchRequest(
      query: _q,
      collections: f.bookIds,
      books: f.chapterIds,
      categories: f.categoryIds,
      grades: f.grades,
      translatedOnly: f.translatedOnly,
      limit: pageSize,
    );
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _generation++; // drop any response still in flight
    _scroll.dispose();
    super.dispose();
  }

  /// First page (initial load, pull-to-refresh, retry of a failed first page).
  Future<void> _reload() async {
    if (_tooShort || !mounted) return;
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    final page = await context.services.catalog!.searchPage(_request);
    if (!mounted || gen != _generation) return;
    setState(() {
      _loading = false;
      _started = true;
      _failure = page.failure;
      if (page.failure == null) {
        _results.clear();
        _ids.clear();
        _append(page);
      }
    });
    _afterLayout();
  }

  /// Next page after [_cursor]; ignored while another request is running.
  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (_loading || !_hasMore || cursor == null || !mounted) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    final page = await context.services.catalog!.searchPage(_request.next(cursor));
    if (!mounted || gen != _generation) return;
    setState(() {
      _loading = false;
      _failure = page.failure;
      if (page.failure == null) _append(page);
    });
    _afterLayout();
  }

  void _append(SearchPage page) {
    for (final h in page.hadiths) {
      if (_ids.add(h.id)) _results.add(h);
    }
    _cursor = page.nextCursor;
    _hasMore = page.hasMore;
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients || _failure != null) return;
    final p = _scroll.position;
    if (p.maxScrollExtent - p.pixels <= loadAheadPx) _loadMore();
  }

  /// A short list cannot be scrolled, so check once it is laid out.
  void _afterLayout() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _maybeLoadMore();
  });

  List<Hadith> _visible(Set<String> favoriteIds) => switch (widget.filters.bookmark) {
    BookmarkFilter.all => _results,
    BookmarkFilter.bookmarked => [
      for (final h in _results)
        if (favoriteIds.contains(h.id)) h,
    ],
    BookmarkFilter.notBookmarked => [
      for (final h in _results)
        if (!favoriteIds.contains(h.id)) h,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    if (_tooShort) {
      return const EmptyStateWidget(
        icon: Icons.keyboard_rounded,
        title: 'Qor ugu yaraan 2 xaraf',
        message: 'Qor eray Carabi ama Soomaali ah.',
      );
    }
    if (_failure != null && _results.isEmpty) {
      return ErrorStateWidget(title: 'Raadintu way fashilantay', message: _failure!.message, onRetry: _reload);
    }
    if (!_started) return const SearchLoadingState();
    return ListenableBuilder(
      listenable: services.favorites,
      builder: (context, _) {
        final results = _visible(services.favorites.ids.toSet());
        if (results.isEmpty && !_hasMore && !_loading) {
          return RefreshIndicator(
            onRefresh: _reload,
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: c.maxHeight,
                  child: SearchNoResultsView(
                    hasFilters: !widget.filters.isEmpty,
                    onResetFilters: widget.onResetFilters,
                    onBrowseCategories: widget.onBrowseCategories,
                  ),
                ),
              ),
            ),
          );
        }
        // The list may have become short (bookmark filter): keep filling it.
        if (_hasMore && !_loading && _failure == null) _afterLayout();
        final tokens = ArabicNormalizer.tokens(widget.query);
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            itemCount: results.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) {
                return AppPageBody(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${results.length}${_hasMore ? '+' : ''} natiijo · '
                      '${_q.isEmpty ? 'shaandhayn' : 'kuwa ugu habboon marka hore'}',
                      style: context.textStyles.labelMedium,
                    ),
                  ),
                );
              }
              if (i == results.length + 1) {
                if (_failure != null) {
                  return AppPageBody(
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        children: [
                          Text('Bogga xiga lama soo rari karin', style: context.textStyles.titleSmall),
                          AppSpacing.gapXxs,
                          Text(_failure!.message, textAlign: TextAlign.center, style: context.textStyles.bodySmall),
                          AppTextButton(label: 'Isku day mar kale', icon: Icons.refresh_rounded, onPressed: _loadMore),
                        ],
                      ),
                    ),
                  );
                }
                if (_loading) return const AppPageBody(child: Center(child: LoadingIndicator()));
                if (!_hasMore && results.isNotEmpty) {
                  return AppPageBody(
                    child: Center(child: Text('Natiijooyinka waa dhammaadeen', style: context.textStyles.bodySmall)),
                  );
                }
                return const SizedBox.shrink();
              }
              final h = results[i - 1];
              return AppPageBody(
                key: ValueKey(h.id),
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: SearchResultCard(hadith: h, tokens: tokens),
              );
            },
          ),
        );
      },
    );
  }
}
