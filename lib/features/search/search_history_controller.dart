import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../core/utils/arabic_normalizer.dart';

/// Recent search terms, persisted locally (newest first, max [maxItems]).
/// Only search terms are stored — never anything typed in other forms.
class SearchHistoryController extends ChangeNotifier {
  SearchHistoryController(this._store);

  static const maxItems = 8;
  static const minLength = 2;
  static const _key = 'search.history';

  final SettingsStore _store;
  List<String> _terms = [];

  List<String> get terms => List.unmodifiable(_terms);

  Future<void> load() async {
    try {
      _terms = (await _store.getStringList(_key) ?? []).take(maxItems).toList();
    } catch (_) {
      _terms = [];
    }
    notifyListeners();
  }

  /// Adds a term (trimmed, whitespace collapsed). Duplicates — compared after
  /// normalisation, so "Salaad" and "salaad " are one entry — move to the top.
  Future<void> add(String term) async {
    final clean = term.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length < minLength) return;
    final key = ArabicNormalizer.normalize(clean);
    _terms = [clean, ..._terms.where((t) => ArabicNormalizer.normalize(t) != key)].take(maxItems).toList();
    notifyListeners();
    await _save();
  }

  Future<void> remove(String term) async {
    _terms = _terms.where((t) => t != term).toList();
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _terms = [];
    notifyListeners();
    try {
      await _store.remove(_key);
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await _store.setStringList(_key, _terms);
    } catch (_) {}
  }
}
