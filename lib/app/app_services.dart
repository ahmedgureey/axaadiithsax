import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/audio/audio_engine.dart';
import '../core/notifications/notification_gateway.dart';
import '../core/notifications/reminder_service.dart';
import '../core/update/update_checker.dart';
import '../core/services/share_service.dart';
import '../core/settings/app_settings_controller.dart';
import '../data/remote/catalog_api.dart';
import '../data/remote/catalog_service.dart';
import '../data/repositories/hadith_repository.dart';
import '../features/onboarding/onboarding_controller.dart';
import '../features/favorites/favorites_controller.dart';
import '../features/hadith/reading_history_controller.dart';
import '../features/memorization/memorization_controller.dart';
import '../features/search/data/hadith_search_service.dart';
import '../features/search/search_history_controller.dart';
import '../features/settings/notification_preferences_controller.dart';

/// App-wide dependencies. Each concern has its own controller so unrelated
/// state never rebuilds together:
///   settings (theme, reading size) · onboarding · favorites ·
///   memorization progress · reading history · repository (data).
/// Navigation state (selected tab, stacks) lives in GoRouter only.
class AppServices {
  AppServices({
    required this.settings,
    required this.onboarding,
    required this.favorites,
    required this.memorization,
    required this.history,
    required this.repository,
    required this.search,
    required this.searchHistory,
    required this.notifications,
    this.share = const PlatformShareService(),
    this.audioEngineFactory = JustAudioEngine.new,
    this.catalog,
    NotificationGateway notificationGateway = const NoopNotificationGateway(),
    this.updateChecker,
  }) : reminders = ReminderService(
         gateway: notificationGateway,
         preferences: notifications,
         memorization: memorization,
         repository: repository,
       );

  final AppSettingsController settings;

  /// Whether the introduction was shown. The app has no accounts.
  final OnboardingController onboarding;
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

  /// Schedules device reminders from the real data (see ReminderService).
  final ReminderService reminders;

  /// Checks GitHub for a newer version (null: no check, e.g. web and tests).
  final UpdateChecker? updateChecker;

  /// The update check ran in this app session.
  bool updateCheckDone = false;

  /// Supabase catalogue loader; null without a backend (bundled data).
  final CatalogService? catalog;

  /// Where the hadith catalogue came from (bundled, Supabase, or cache).
  CatalogOrigin get catalogOrigin => catalog?.origin ?? CatalogOrigin.bundled;

  /// System share sheet (replaceable in tests).
  final ShareService share;

  /// Creates the audio engine for each player (replaceable in tests).
  final AudioEngineFactory audioEngineFactory;

  /// Creates and loads all services from [store].
  ///
  /// With [catalogApi] (Supabase) the repository starts EMPTY — never with
  /// bundled placeholders — and [CatalogService] fills it with published
  /// records. Without it, the bundled catalogue is used (tests, no backend).
  static Future<AppServices> create(
    SettingsStore store, {
    HadithRepository? repository,
    CatalogApi? catalogApi,
    ShareService? share,
    AudioEngineFactory? audioEngineFactory,
    NotificationGateway? notificationGateway,
    UpdateChecker? updateChecker,
    DateTime Function()? clock,
  }) async {
    final remote = catalogApi != null;
    final repo =
        repository ??
        (remote ? HadithRepository(books: const [], chapters: const [], hadiths: const []) : HadithRepository());
    final catalog = remote ? CatalogService(catalogApi, repo, store) : null;
    if (catalog != null) await catalog.start();
    repo.dailyStart = await loadDailyStart(store, (clock ?? DateTime.now)());

    List<String> readingOrder() => [
      for (final b in repo.books)
        for (final h in repo.readingOrderOf(b.id)) h.id,
    ];

    final onboarding = OnboardingController(store);
    final favorites = FavoritesController(store);
    final services = AppServices(
      settings: AppSettingsController(store),
      onboarding: onboarding,
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
      audioEngineFactory: audioEngineFactory ?? JustAudioEngine.new,
      notificationGateway: notificationGateway ?? const NoopNotificationGateway(),
      updateChecker: updateChecker,
      catalog: catalog,
    );
    await Future.wait([
      services.settings.load(),
      services.onboarding.load(),
      services.favorites.load(),
      services.searchHistory.load(),
      services.memorization.load(),
      services.notifications.load(),
      services.history.load(),
    ]);
    // Bundled data is complete, so unknown ids are stale. Remote data is
    // loaded on demand: unknown ids are simply not downloaded yet.
    if (!remote) services.history.removeMissing((id) => repo.hadithById(id) != null);
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

  /// Storage key: first day of the "hadith of the day" sequence (yyyy-mm-dd).
  static const dailyStartKey = 'daily.startDay';

  /// Day the hadith-of-the-day sequence starts (hadith 1): saved on first
  /// use, so every user begins with the first hadith.
  static Future<DateTime> loadDailyStart(SettingsStore store, DateTime today) async {
    final saved = DateTime.tryParse(await store.getString(dailyStartKey) ?? '');
    if (saved != null) return saved;
    final day = DateTime(today.year, today.month, today.day);
    final d =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await store.setString(dailyStartKey, d);
    return day;
  }

  /// Deletes ALL locally stored app data — bookmarks, memorisation progress,
  /// quiz history, search history, reading history, preferences and the demo
  /// onboarding flag — from memory and from storage. Hadith content (part
  /// of the app) is not affected.
  Future<void> resetAllLocalData() async {
    history.clear();
    await catalog?.clearCache();
    await Future.wait([
      favorites.clear(),
      memorization.reset(),
      searchHistory.clear(),
      notifications.reset(),
      settings.resetAppearanceAndReading(),
    ]);
    // Last: this triggers the router guard (back to onboarding).
    await onboarding.reset();
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
