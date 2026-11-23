import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/remote/catalog_api.dart';
import '../auth/auth_controller.dart';
import 'favorites_controller.dart';

/// Keeps the device bookmarks ([FavoritesController]) in step with the
/// signed-in account's `bookmarks` table.
///
/// * Only for real (Supabase) accounts; guests and the demo keep bookmarks
///   on the device only.
/// * On sign-in: union of device and account bookmarks (nothing is lost).
/// * While signed in: every add/remove is sent to the server. The server's
///   RLS decides ownership — the app only ever sends the user's own rows.
/// * Failures keep the local change and are retried at the next sync;
///   [lastFailure] tells the UI.
/// * A local "delete all data" pauses syncing so it never deletes the
///   account's bookmarks.
class BookmarkSync extends ChangeNotifier {
  BookmarkSync(this._api, this._favorites, this._auth);

  final BookmarkApi _api;
  final FavoritesController _favorites;
  final AuthController _auth;

  Set<String> _known = {};
  bool _synced = false;
  bool _paused = false;
  bool _running = false;
  CatalogFailure? _lastFailure;

  bool get isSynced => _synced;
  CatalogFailure? get lastFailure => _lastFailure;

  bool get _active => _auth.usesRealAccounts && _auth.isSignedIn && !_paused;

  void start() {
    _auth.addListener(_onAuth);
    _favorites.addListener(_onFavorites);
    _known = _favorites.ids.toSet();
    unawaited(_onAuth());
  }

  /// Stops pushing changes until the next sign-in (used by local reset).
  void pause() {
    _paused = true;
    _synced = false;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _favorites.removeListener(_onFavorites);
    super.dispose();
  }

  Future<void> _onAuth() async {
    if (!_auth.isSignedIn) {
      _synced = false;
      _paused = false; // next sign-in syncs again
      return;
    }
    if (_active && !_synced && !_running) await syncNow();
  }

  /// Merges device and account bookmarks. Safe to call again (retry).
  Future<void> syncNow() async {
    if (!_active || _running) return;
    _running = true;
    try {
      final remote = (await _api.bookmarkIds()).toSet();
      final local = _favorites.ids.toSet();
      // Account → device (update _known first so the listener doesn't echo).
      for (final id in remote.difference(local)) {
        _known.add(id);
        await _favorites.add(id);
      }
      // Device → account.
      for (final id in local.difference(remote)) {
        await _api.add(id);
      }
      _known = _favorites.ids.toSet();
      _synced = true;
      _lastFailure = null;
    } catch (e) {
      _lastFailure = CatalogFailure.from(e);
      debugPrint('Bookmark sync failed: $_lastFailure');
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _onFavorites() async {
    final now = _favorites.ids.toSet();
    final added = now.difference(_known);
    final removed = _known.difference(now);
    _known = now;
    if (!_active || !_synced || (added.isEmpty && removed.isEmpty)) return;
    try {
      for (final id in added) {
        await _api.add(id);
      }
      for (final id in removed) {
        await _api.remove(id);
      }
      _lastFailure = null;
    } catch (e) {
      // Keep the device change; the next sign-in/sync reconciles additions.
      _lastFailure = CatalogFailure.from(e);
      _synced = false;
      debugPrint('Bookmark change not saved to account: $_lastFailure');
    }
    notifyListeners();
  }
}
