import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';

/// The single source of truth for saved (bookmarked) hadith.
///
/// * Stores stable record IDs only (never copies of hadith content), newest
///   first, persisted with the app's existing `SettingsStore`.
/// * Duplicates are impossible: stored lists are de-duplicated on load and
///   every write goes through [add] / [remove].
/// * Storage failures never crash the app: a failed read sets [loadFailed]
///   (the UI offers a retry); a failed write keeps the in-memory state.
class FavoritesController extends ChangeNotifier {
  FavoritesController(this._store);

  static const storageKey = 'favorites.hadithIds';
  final SettingsStore _store;
  List<String> _ids = [];
  bool _loaded = false;
  bool _loadFailed = false;

  List<String> get ids => List.unmodifiable(_ids);
  int get count => _ids.length;
  bool get isLoaded => _loaded;
  bool get loadFailed => _loadFailed;
  bool isFavorite(String hadithId) => _ids.contains(hadithId);

  Future<void> load() async {
    try {
      final stored = await _store.getStringList(storageKey) ?? const [];
      // Keep first occurrence (= most recent) of each ID.
      _ids = [
        ...{...stored.where((id) => id.isNotEmpty)},
      ];
      _loadFailed = false;
    } catch (_) {
      _ids = [];
      _loadFailed = true;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Saves [hadithId] at the top. No-op if already saved.
  Future<void> add(String hadithId) async {
    if (_ids.contains(hadithId)) return;
    _ids.insert(0, hadithId);
    notifyListeners();
    await _persist();
  }

  /// Removes [hadithId]. No-op if not saved.
  Future<void> remove(String hadithId) async {
    if (!_ids.remove(hadithId)) return;
    notifyListeners();
    await _persist();
  }

  /// Returns the new state (true = now saved).
  Future<bool> toggle(String hadithId) async {
    if (_ids.contains(hadithId)) {
      await remove(hadithId);
      return false;
    }
    await add(hadithId);
    return true;
  }

  /// Drops saved IDs that no longer exist in the dataset. Returns how many
  /// were removed.
  /// Removes every bookmark from memory and storage.
  Future<void> clear() async {
    _ids = [];
    notifyListeners();
    try {
      await _store.remove(storageKey);
    } catch (_) {}
  }

  Future<int> removeMissing(bool Function(String id) exists) async {
    final before = _ids.length;
    _ids = _ids.where(exists).toList();
    final removed = before - _ids.length;
    if (removed > 0) {
      notifyListeners();
      await _persist();
    }
    return removed;
  }

  Future<void> _persist() async {
    try {
      await _store.setStringList(storageKey, _ids);
    } catch (_) {
      // Best effort: the in-memory list stays correct for this session.
    }
  }
}
