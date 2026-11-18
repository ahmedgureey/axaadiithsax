import 'package:flutter/widgets.dart';

import '../core/settings/app_settings_controller.dart';
import '../data/repositories/hadith_repository.dart';
import '../features/auth/auth_controller.dart';
import '../features/favorites/favorites_controller.dart';
import '../features/hadith/reading_history_controller.dart';
import '../features/memorization/memorization_controller.dart';

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
  });

  final AppSettingsController settings;
  final AuthController auth;
  final FavoritesController favorites;
  final MemorizationController memorization;
  final ReadingHistoryController history;
  final HadithRepository repository;

  /// Creates and loads all services from [store].
  static Future<AppServices> create(SettingsStore store, {HadithRepository? repository}) async {
    final repo = repository ?? HadithRepository();
    final services = AppServices(
      settings: AppSettingsController(store),
      auth: AuthController(store),
      favorites: FavoritesController(store),
      // Demo plan: first five hadith of the dataset (IDs always exist).
      memorization: MemorizationController(planHadithIds: repo.allHadiths.take(5).map((h) => h.id).toList()),
      history: ReadingHistoryController(),
      repository: repo,
    );
    await Future.wait([services.settings.load(), services.auth.load(), services.favorites.load()]);
    return services;
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
