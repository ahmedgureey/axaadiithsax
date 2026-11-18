import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';

/// Recently viewed hadith ids, newest first. Persisted locally when a store
/// is given (only ids are stored), so "Sii wad akhriska" survives restarts.
class ReadingHistoryController extends ChangeNotifier {
  ReadingHistoryController([this._store]);

  static const maxItems = 10;
  static const storageKey = 'reading.history';

  final SettingsStore? _store;
  final List<String> _ids = [];

  List<String> get recentIds => List.unmodifiable(_ids);

  /// Most recently opened hadith id, if any.
  String? get lastId => _ids.isEmpty ? null : _ids.first;

  Future<void> load() async {
    final store = _store;
    if (store == null) return;
    try {
      final stored = await store.getStringList(storageKey) ?? const [];
      _ids
        ..clear()
        ..addAll(stored.toSet().take(maxItems));
      notifyListeners();
    } catch (_) {
      // Corrupted or unavailable storage: start with an empty history.
    }
  }

  /// Keeps only ids that still exist in the dataset.
  void removeMissing(bool Function(String id) exists) {
    final before = _ids.length;
    _ids.removeWhere((id) => !exists(id));
    if (_ids.length != before) {
      notifyListeners();
      _save();
    }
  }

  void clear() {
    final hadItems = _ids.isNotEmpty;
    _ids.clear();
    if (hadItems) notifyListeners();
    final store = _store;
    if (store != null) {
      store.remove(storageKey).catchError((_) {});
    }
  }

  void record(String hadithId) {
    if (_ids.isNotEmpty && _ids.first == hadithId) return;
    _ids
      ..remove(hadithId)
      ..insert(0, hadithId);
    if (_ids.length > maxItems) _ids.removeLast();
    notifyListeners();
    _save();
  }

  void _save() {
    final store = _store;
    if (store == null) return;
    store.setStringList(storageKey, List.of(_ids)).catchError((_) {});
  }
}
