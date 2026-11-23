import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';

/// The app has no accounts: everyone uses it directly. The only start-up
/// state is whether the short introduction (onboarding) was shown.
class OnboardingController extends ChangeNotifier {
  OnboardingController(this._store);

  /// Same key as before accounts were removed, so returning users do not
  /// see the introduction again.
  static const seenKey = 'auth.onboardingSeen';

  /// Data from the removed login feature; deleted from the device on start.
  static const legacyAccountKeys = [
    'auth.status',
    'auth.displayName',
    'auth.email',
    'auth.emailVerified',
    'auth.rememberSession',
  ];

  final SettingsStore _store;
  bool _seen = false;

  bool get onboardingSeen => _seen;

  Future<void> load() async {
    try {
      _seen = await _store.getBool(seenKey) ?? false;
      for (final key in legacyAccountKeys) {
        await _store.remove(key);
      }
    } catch (_) {
      // Storage unavailable: show the introduction, keep going.
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _seen = true;
    notifyListeners();
    try {
      await _store.setBool(seenKey, true);
    } catch (_) {}
  }

  /// Back to first-start state (used by "delete all local data").
  Future<void> reset() async {
    _seen = false;
    notifyListeners();
    try {
      await _store.remove(seenKey);
    } catch (_) {}
  }
}
