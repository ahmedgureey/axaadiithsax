import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';

/// Saved (bookmarked) hadith IDs, persisted locally. Newest first.
class FavoritesController extends ChangeNotifier {
  FavoritesController(this._store);

  static const _key = 'favorites.hadithIds';
  final SettingsStore _store;
  List<String> _ids = [];

  List<String> get ids => List.unmodifiable(_ids);
  bool isFavorite(String hadithId) => _ids.contains(hadithId);

  Future<void> load() async {
    try {
      _ids = await _store.getStringList(_key) ?? [];
    } catch (_) {
      _ids = [];
    }
    notifyListeners();
  }

  /// Returns the new state (true = now saved).
  Future<bool> toggle(String hadithId) async {
    final added = !_ids.contains(hadithId);
    added ? _ids.insert(0, hadithId) : _ids.remove(hadithId);
    notifyListeners();
    try {
      await _store.setStringList(_key, _ids);
    } catch (_) {}
    return added;
  }
}
