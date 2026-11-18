import 'package:flutter/widgets.dart';

import '../core/services/share_service.dart';
import '../core/settings/app_settings_controller.dart';
import '../data/repositories/hadith_repository.dart';
import '../features/auth/auth_controller.dart';
import '../features/favorites/favorites_controller.dart';
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

  /// System share sheet (replaceable in tests).
  final ShareService share;

  /// Creates and loads all services from [store].
  static Future<AppServices> create(
    SettingsStore store, {
    HadithRepository? repository,
    ShareService? share,
    DateTime Function()? clock,
  }) async {
    final repo = repository ?? HadithRepository();
    final services = AppServices(
      settings: AppSettingsController(store),
      auth: AuthController(store),
      favorites: FavoritesController(store),
      // Every hadith with content can be memorised, in reading order.
      memorization: MemorizationController(
        store,
        candidateIds: [
          for (final b in repo.books)
            for (final h in repo.readingOrderOf(b.id)) h.id,
        ],
        exists: (id) => repo.hadithById(id) != null,
        clock: clock,
      ),
      history: ReadingHistoryController(),
      repository: repo,
      search: HadithSearchService(repo),
      searchHistory: SearchHistoryController(store),
      notifications: NotificationPreferencesController(store),
      share: share ?? const PlatformShareService(),
    );
    await Future.wait([
      services.settings.load(),
      services.auth.load(),
      services.favorites.load(),
      services.searchHistory.load(),
      services.memorization.load(),
      services.notifications.load(),
    ]);
    return services;
  }

  /// Deletes ALL locally stored app data — bookmarks, memorisation progress,
  /// quiz history, search history, reading history, preferences and the demo
  /// session/onboarding — from memory and from storage. Hadith content (part
  /// of the app) is not affected.
  Future<void> resetAllLocalData() async {
    history.clear();
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
