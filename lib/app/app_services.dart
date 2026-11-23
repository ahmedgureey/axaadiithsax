import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/services/share_service.dart';
import '../core/settings/app_settings_controller.dart';
import '../data/remote/catalog_api.dart';
import '../data/remote/catalog_service.dart';
import '../data/repositories/hadith_repository.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_gateway.dart';
import '../features/favorites/favorites_controller.dart';
import '../features/favorites/bookmark_sync.dart';
import '../features/hadith/reading_history_controller.dart';
import '../features/memorization/memorization_controller.dart';
import '../features/search/data/hadith_search_service.dart';
import '../features/search/search_history_controller.dart';
import '../features/settings/notification_preferences_controller.dart';

/// App-wide dependencies. Each concern has its own controller so unrelated
/// state never rebuilds together:
///   settings (theme, reading size) · auth (demo session) · favorites ·
///   memorization progress · reading history · repository (data).
/// Navigation state (selected tab, stacks) lives in GoRouter only.
class AppServices {
  AppServices({
    required this.settings,
    required this.auth,
    required this.favorites,
    required this.memorization,
    required this.history,
    required this.repository,
    required this.search,
    required this.searchHistory,
    required this.notifications,
    this.share = const PlatformShareService(),
    this.catalog,
    this.bookmarkSync,
  });

  final AppSettingsController settings;
  final AuthController auth;
  final FavoritesController favorites;
  final MemorizationController memorization;
  final ReadingHistoryController history;
  final HadithRepository repository;

  /// Local search index over [repository].
  final HadithSearchService search;

  /// Recent search terms (persisted).
  final SearchHistoryController searchHistory;

  /// Reminder preferences (no notification service yet).
  final NotificationPreferencesController notifications;

  /// Supabase catalogue loader; null without a backend (bundled data).
  final CatalogService? catalog;

  /// Keeps bookmarks in step with the signed-in account; null without a backend.
  final BookmarkSync? bookmarkSync;

  /// Where the hadith catalogue came from (bundled, Supabase, or cache).
  CatalogOrigin get catalogOrigin => catalog?.origin ?? CatalogOrigin.bundled;

  /// System share sheet (replaceable in tests).
  final ShareService share;

  /// Creates and loads all services from [store].
  ///
  /// With [catalogApi] (Supabase) the repository starts EMPTY — never with
  /// bundled placeholders — and [CatalogService] fills it with published
  /// records. Without it, the bundled catalogue is used (tests, no backend).
  static Future<AppServices> create(
    SettingsStore store, {
    HadithRepository? repository,
    CatalogApi? catalogApi,
    BookmarkApi? bookmarkApi,
    AuthGateway? authGateway,
    ShareService? share,
    DateTime Function()? clock,
  }) async {
    final remote = catalogApi != null;
    final repo =
        repository ??
        (remote ? HadithRepository(books: const [], chapters: const [], hadiths: const []) : HadithRepository());
    final catalog = remote ? CatalogService(catalogApi, repo, store) : null;
    if (catalog != null) await catalog.start();

    List<String> readingOrder() => [
      for (final b in repo.books)
        for (final h in repo.readingOrderOf(b.id)) h.id,
    ];

    final auth = AuthController(store, gateway: authGateway);
    final favorites = FavoritesController(store);
    final services = AppServices(
      settings: AppSettingsController(store),
      auth: auth,
      favorites: favorites,
      // Every hadith with content can be memorised, in reading order. With a
      // backend: the records loaded so far (memorised records stay valid even
      // before they are downloaded again).
      memorization: remote
          ? MemorizationController(store, candidatesProvider: readingOrder, clock: clock)
          : MemorizationController(
              store,
              candidateIds: readingOrder(),
              exists: (id) => repo.hadithById(id) != null,
              clock: clock,
            ),
      history: ReadingHistoryController(store),
      repository: repo,
      search: HadithSearchService(repo),
      searchHistory: SearchHistoryController(store),
      notifications: NotificationPreferencesController(store),
      share: share ?? const PlatformShareService(),
      catalog: catalog,
      bookmarkSync: bookmarkApi == null ? null : BookmarkSync(bookmarkApi, favorites, auth),
    );
    await Future.wait([
      services.settings.load(),
      services.auth.load(),
      services.favorites.load(),
      services.searchHistory.load(),
      services.memorization.load(),
      services.notifications.load(),
      services.history.load(),
    ]);
    // Bundled data is complete, so unknown ids are stale. Remote data is
    // loaded on demand: unknown ids are simply not downloaded yet.
    if (!remote) services.history.removeMissing((id) => repo.hadithById(id) != null);
    services.bookmarkSync?.start();
    // Backend: fetch the records this device refers to (favourites, history,
    // memorisation) in one background request; lists rebuild when they arrive.
    if (catalog != null) {
      unawaited(
        catalog.ensureHadiths({
          ...favorites.ids,
          ...services.history.recentIds,
          for (final r in services.memorization.recentlyMemorized) r.hadithId,
        }),
      );
    }
    return services;
  }

  /// Deletes ALL locally stored app data — bookmarks, memorisation progress,
  /// quiz history, search history, reading history, preferences and the demo
  /// session/onboarding — from memory and from storage. Hadith content (part
  /// of the app) is not affected.
  Future<void> resetAllLocalData() async {
    history.clear();
    // Local data only: the account's server-side bookmarks stay in the
    // account (deleting them is an account action, not a device reset).
    bookmarkSync?.pause();
    await catalog?.clearCache();
    await Future.wait([
      favorites.clear(),
      memorization.reset(),
      searchHistory.clear(),
      notifications.reset(),
      settings.resetAppearanceAndReading(),
    ]);
    // Last: this triggers the router guard (back to onboarding).
    await auth.resetDemo();
  }
}

class AppServicesScope extends InheritedWidget {
  const AppServicesScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppServicesScope>();
    assert(scope != null, 'AppServicesScope not found');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) => oldWidget.services != services;
}

extension AppServicesContext on BuildContext {
  /// Access services. Listen to a specific controller with
  /// `ListenableBuilder` when a widget must rebuild on its changes.
  AppServices get services => AppServicesScope.of(this);
}
