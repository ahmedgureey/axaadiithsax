import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';

enum AuthStatus { signedOut, guest, signedIn }

/// DEMO-ONLY authentication state.
///
/// There is no backend, no password check and no security here: "signing in"
/// only flips a local flag so the navigation flow can be exercised. Never
/// treat this as real authentication.
class AuthController extends ChangeNotifier {
  AuthController(this._store);

  static const _onboardingKey = 'auth.onboardingSeen';
  static const _statusKey = 'auth.status';
  static const _nameKey = 'auth.displayName';
  static const _emailKey = 'auth.email';

  /// Simulated network delay for demo actions (keeps loading states visible).
  static const demoDelay = Duration(milliseconds: 600);

  final SettingsStore _store;

  bool _onboardingSeen = false;
  AuthStatus _status = AuthStatus.signedOut;
  String? _displayName;
  String? _email;

  /// Registration details waiting for the demo e-mail verification step.
  String? _pendingName;
  String? _pendingEmail;

  bool get onboardingSeen => _onboardingSeen;
  AuthStatus get status => _status;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  bool get canUseApp => _status != AuthStatus.signedOut;
  String? get displayName => _displayName;
  String? get email => _email;
  String? get pendingEmail => _pendingEmail;

  Future<void> load() async {
    try {
      _onboardingSeen = await _store.getBool(_onboardingKey) ?? false;
      final saved = await _store.getString(_statusKey);
      _status = AuthStatus.values.firstWhere((s) => s.name == saved, orElse: () => AuthStatus.signedOut);
      _displayName = await _store.getString(_nameKey);
      _email = await _store.getString(_emailKey);
    } catch (_) {
      // Keep defaults if storage is unavailable.
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingSeen = true;
    notifyListeners();
    await _safe(() => _store.setBool(_onboardingKey, true));
  }

  Future<void> continueAsGuest() => _setSession(AuthStatus.guest, name: null, email: null);

  /// Demo sign-in: accepts any form-valid input. No credential is checked
  /// or stored (the password is never persisted).
  Future<void> signInDemo({required String email}) =>
      _setSession(AuthStatus.signedIn, name: _nameFromEmail(email), email: email);

  /// Demo registration: remembers the details until verification completes.
  void startRegistrationDemo({required String name, required String email}) {
    _pendingName = name.trim();
    _pendingEmail = email.trim();
    notifyListeners();
  }

  /// Demo e-mail verification: completes the pending registration.
  Future<void> completeVerificationDemo() {
    final email = _pendingEmail ?? 'demo@xadiis.app';
    final name = _pendingName ?? _nameFromEmail(email);
    _pendingName = null;
    _pendingEmail = null;
    return _setSession(AuthStatus.signedIn, name: name, email: email);
  }

  Future<void> signOut() => _setSession(AuthStatus.signedOut, name: null, email: null);

  Future<void> _setSession(AuthStatus status, {required String? name, required String? email}) async {
    _status = status;
    _displayName = name;
    _email = email;
    notifyListeners();
    await _safe(() async {
      await _store.setString(_statusKey, status.name);
      name == null ? await _store.remove(_nameKey) : await _store.setString(_nameKey, name);
      email == null ? await _store.remove(_emailKey) : await _store.setString(_emailKey, email);
    });
  }

  static String _nameFromEmail(String email) {
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'Isticmaale';
    return local[0].toUpperCase() + local.substring(1);
  }

  Future<void> _safe(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {}
  }
}
