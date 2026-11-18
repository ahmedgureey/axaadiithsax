import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';

/// Session kinds. None of these are server-verified — see [AuthController].
enum AuthStatus {
  /// Not in the app yet (only onboarding / auth screens).
  signedOut,

  /// Uses the app without an account. Never shown as "logged in".
  guest,

  /// Simulated account session (demo login or demo registration).
  signedIn,
}

/// DEMO-ONLY authentication state, separate from UI code.
///
/// * No backend, no network, no real accounts.
/// * Login only accepts the published demo credentials ([demoEmail] /
///   [demoPassword]); any other input is rejected with a friendly error.
/// * Passwords are compared in memory and NEVER persisted or logged.
/// * "Verified" means the user tapped the simulated verification button.
///
/// Persisted locally: onboarding flag, session status (if "remember me"),
/// display name, e-mail and the simulated verification flag.
class AuthController extends ChangeNotifier {
  AuthController(this._store);

  // Published demo account (shown on the login screen and in docs).
  static const demoEmail = 'demo@xadiis.app';
  static const demoPassword = 'Demo1234';
  static const demoName = 'Isticmaale Demo';

  /// Documented minimum password length for all demo forms.
  static const minPasswordLength = 8;

  /// Simulated network delay for demo actions (keeps loading states visible).
  static const demoDelay = Duration(milliseconds: 600);

  static const _onboardingKey = 'auth.onboardingSeen';
  static const _statusKey = 'auth.status';
  static const _nameKey = 'auth.displayName';
  static const _emailKey = 'auth.email';
  static const _verifiedKey = 'auth.emailVerified';

  final SettingsStore _store;

  bool _onboardingSeen = false;
  AuthStatus _status = AuthStatus.signedOut;
  String? _displayName;
  String? _email;
  bool _emailVerified = false;

  bool get onboardingSeen => _onboardingSeen;
  AuthStatus get status => _status;
  bool get isGuest => _status == AuthStatus.guest;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  bool get canUseApp => _status != AuthStatus.signedOut;

  /// Simulated verification (only meaningful when [isSignedIn]).
  bool get emailVerified => isSignedIn && _emailVerified;
  String? get displayName => _displayName;
  String? get email => _email;

  /// e.g. `d***@xadiis.app` — for display on the verification screen.
  String? get maskedEmail {
    final e = _email;
    if (e == null || !e.contains('@')) return null;
    final [local, domain] = e.split('@');
    if (local.isEmpty) return '***@$domain';
    return '${local[0]}${'*' * (local.length - 1).clamp(2, 6)}@$domain';
  }

  Future<void> load() async {
    try {
      _onboardingSeen = await _store.getBool(_onboardingKey) ?? false;
      final saved = await _store.getString(_statusKey);
      _status = AuthStatus.values.firstWhere((s) => s.name == saved, orElse: () => AuthStatus.signedOut);
      _displayName = await _store.getString(_nameKey);
      _email = await _store.getString(_emailKey);
      _emailVerified = await _store.getBool(_verifiedKey) ?? false;
    } catch (_) {
      // Storage unavailable: start signed out with onboarding.
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingSeen = true;
    notifyListeners();
    await _safe(() => _store.setBool(_onboardingKey, true));
  }

  /// Guest access: the user is NOT authenticated.
  Future<void> continueAsGuest() =>
      _setSession(AuthStatus.guest, name: null, email: null, verified: false, persist: true);

  /// Demo login. Returns `false` (and changes nothing) unless the input
  /// matches the published demo account. The e-mail is trimmed and
  /// case-insensitive; the password is compared exactly as typed.
  Future<bool> signInDemo({required String email, required String password, bool rememberMe = true}) async {
    final ok = email.trim().toLowerCase() == demoEmail && password == demoPassword;
    if (!ok) return false;
    await _setSession(
      AuthStatus.signedIn,
      name: demoName,
      email: demoEmail,
      verified: true, // the demo account is treated as already verified
      persist: rememberMe,
    );
    return true;
  }

  /// "Tijaabi Demo-ga": signs in with the demo account in one tap.
  Future<void> tryDemo({bool rememberMe = true}) =>
      signInDemo(email: demoEmail, password: demoPassword, rememberMe: rememberMe);

  /// Demo registration: starts a simulated, UNVERIFIED session. Only the name
  /// and e-mail are kept; the password is discarded by the caller.
  Future<void> registerDemo({required String name, required String email}) => _setSession(
    AuthStatus.signedIn,
    name: name.trim(),
    email: email.trim().toLowerCase(),
    verified: false,
    persist: true,
  );

  /// Simulated e-mail verification (user explicitly tapped the demo button).
  Future<void> verifyEmailDemo() async {
    if (!isSignedIn) return;
    _emailVerified = true;
    notifyListeners();
    await _safe(() => _store.setBool(_verifiedKey, true));
  }

  Future<void> signOut() =>
      _setSession(AuthStatus.signedOut, name: null, email: null, verified: false, persist: true);

  /// Clears ALL demo auth state, including onboarding (for testing).
  Future<void> resetDemo() async {
    _onboardingSeen = false;
    _status = AuthStatus.signedOut;
    _displayName = null;
    _email = null;
    _emailVerified = false;
    notifyListeners();
    await _safe(() async {
      for (final key in [_onboardingKey, _statusKey, _nameKey, _emailKey, _verifiedKey]) {
        await _store.remove(key);
      }
    });
  }

  Future<void> _setSession(
    AuthStatus status, {
    required String? name,
    required String? email,
    required bool verified,
    required bool persist,
  }) async {
    _status = status;
    _displayName = name;
    _email = email;
    _emailVerified = verified;
    notifyListeners();
    await _safe(() async {
      if (!persist) {
        // "Remember me" off: session lives in memory only.
        await _store.setString(_statusKey, AuthStatus.signedOut.name);
        for (final key in [_nameKey, _emailKey, _verifiedKey]) {
          await _store.remove(key);
        }
        return;
      }
      await _store.setString(_statusKey, status.name);
      name == null ? await _store.remove(_nameKey) : await _store.setString(_nameKey, name);
      email == null ? await _store.remove(_emailKey) : await _store.setString(_emailKey, email);
      await _store.setBool(_verifiedKey, verified);
    });
  }

  Future<void> _safe(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {}
  }
}
