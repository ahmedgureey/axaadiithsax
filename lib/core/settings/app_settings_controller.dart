import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_typography.dart';

/// Key-value storage used by [AppSettingsController].
/// Abstracted so tests can use [InMemorySettingsStore].
abstract interface class SettingsStore {
  Future<String?> getString(String key);
  Future<double?> getDouble(String key);
  Future<bool?> getBool(String key);
  Future<List<String>?> getStringList(String key);
  Future<void> setString(String key, String value);
  Future<void> setDouble(String key, double value);
  Future<void> setBool(String key, bool value);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

/// Local persistence backed by `shared_preferences` (device only, no backend).
class SharedPrefsSettingsStore implements SettingsStore {
  SharedPrefsSettingsStore([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> getString(String key) => _prefs.getString(key);
  @override
  Future<double?> getDouble(String key) => _prefs.getDouble(key);
  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
  @override
  Future<void> setDouble(String key, double value) => _prefs.setDouble(key, value);
  @override
  Future<bool?> getBool(String key) => _prefs.getBool(key);
  @override
  Future<List<String>?> getStringList(String key) => _prefs.getStringList(key);
  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  @override
  Future<void> setStringList(String key, List<String> value) => _prefs.setStringList(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([Map<String, Object>? initial]) : _data = {...?initial};
  final Map<String, Object> _data;

  @override
  Future<String?> getString(String key) async => _data[key] as String?;
  @override
  Future<double?> getDouble(String key) async => _data[key] as double?;
  @override
  Future<void> setString(String key, String value) async => _data[key] = value;
  @override
  Future<void> setDouble(String key, double value) async => _data[key] = value;
  @override
  Future<bool?> getBool(String key) async => _data[key] as bool?;
  @override
  Future<List<String>?> getStringList(String key) async => (_data[key] as List<String>?)?.toList();
  @override
  Future<void> setBool(String key, bool value) async => _data[key] = value;
  @override
  Future<void> setStringList(String key, List<String> value) async => _data[key] = value.toList();
  @override
  Future<void> remove(String key) async => _data.remove(key);
}

/// Holds user-facing appearance settings: theme mode and Arabic reading size.
///
/// Phase 3 may move this behind the chosen state-management solution; the
/// public API (getters + setters) is designed to survive that move.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this._store);

  static const _themeKey = 'settings.themeMode';
  static const _arabicSizeKey = 'settings.arabicFontSize';

  final SettingsStore _store;

  ThemeMode _themeMode = ThemeMode.system;
  double _arabicFontSize = ArabicFontSize.defaultSize;

  ThemeMode get themeMode => _themeMode;
  double get arabicFontSize => _arabicFontSize;

  /// Loads saved values. Safe to call once at startup; falls back to defaults
  /// if storage is unavailable or contains unexpected data.
  Future<void> load() async {
    try {
      final savedTheme = await _store.getString(_themeKey);
      _themeMode = ThemeMode.values.firstWhere((m) => m.name == savedTheme, orElse: () => ThemeMode.system);
      final savedSize = await _store.getDouble(_arabicSizeKey);
      if (savedSize != null) {
        _arabicFontSize = savedSize.clamp(ArabicFontSize.min, ArabicFontSize.max).toDouble();
      }
    } catch (_) {
      // Storage failure must never block app start — keep defaults.
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _safeWrite(() => _store.setString(_themeKey, mode.name));
  }

  Future<void> setArabicFontSize(double size) async {
    final clamped = size.clamp(ArabicFontSize.min, ArabicFontSize.max).toDouble();
    if (clamped == _arabicFontSize) return;
    _arabicFontSize = clamped;
    notifyListeners();
    await _safeWrite(() => _store.setDouble(_arabicSizeKey, clamped));
  }

  Future<void> _safeWrite(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      // In-memory value is still applied; persistence is best-effort.
    }
  }
}

/// Makes [AppSettingsController] available to the widget tree and rebuilds
/// dependants when settings change.
class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({super.key, required AppSettingsController controller, required super.child})
    : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found in widget tree');
    return scope!.notifier!;
  }

  /// Returns null instead of asserting — handy for widgets used in isolation.
  static AppSettingsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()?.notifier;
}
