import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';
import 'auth_gateway.dart';

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
  /// With a [gateway] (Supabase) accounts are real; without one the local
  /// demo flow below is used (tests, builds without a backend).
  AuthController(this._store, {AuthGateway? gateway})
    : _gateway = gateway; // ignore: prefer_initializing_formals — keeps the public parameter name `gateway`.

  final AuthGateway? _gateway;
  StreamSubscription<AuthGatewayEvent>? _events;

  /// True when sign-in, registration and password reset use real accounts.
  bool get usesRealAccounts => _gateway != null;

  static const _rememberKey = 'auth.rememberSession';

  String? _pendingVerificationEmail;
  bool _recoveringPassword = false;

  /// E-mail of an account that was registered but not yet confirmed (real
  /// accounts only). The user is not signed in until they confirm.
  String? get pendingVerificationEmail => _pendingVerificationEmail;

  /// A password-recovery link was opened: the user must choose a new password.
  bool get isRecoveringPassword => _recoveringPassword;

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
    final e = _email ?? _pendingVerificationEmail;
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
    final gateway = _gateway;
    if (gateway != null) await _restoreRealSession(gateway);
    notifyListeners();
  }

  /// Real accounts: the backend's own session is the source of truth; a
  /// locally saved "signedIn" without a backend session is not trusted.
  Future<void> _restoreRealSession(AuthGateway gateway) async {
    var user = gateway.currentUser;
    final remember = await _read(() => _store.getBool(_rememberKey)) ?? true;
    if (user != null && !remember) {
      await _quiet(gateway.signOut);
      user = null;
    }
    if (user != null) {
      _applyUser(user);
    } else if (_status == AuthStatus.signedIn) {
      _status = AuthStatus.signedOut;
      _displayName = _email = null;
      _emailVerified = false;
    }
    _events = gateway.events.listen(_onGatewayEvent);
  }

  void _onGatewayEvent(AuthGatewayEvent event) {
    switch (event.kind) {
      case AuthGatewayEventKind.signedIn || AuthGatewayEventKind.userUpdated:
        if (event.user != null) _applyUser(event.user!);
      case AuthGatewayEventKind.passwordRecovery:
        _recoveringPassword = true;
        if (event.user != null) _applyUser(event.user!);
      case AuthGatewayEventKind.signedOut:
        if (_status == AuthStatus.signedIn) {
          _status = AuthStatus.signedOut;
          _displayName = _email = null;
          _emailVerified = false;
        }
    }
    notifyListeners();
    unawaited(_safe(() => _store.setString(_statusKey, _status.name)));
  }

  /// Only the session status is saved locally for real accounts; e-mail and
  /// name come from the backend session.
  void _applyUser(AuthUser user) {
    _status = AuthStatus.signedIn;
    _email = user.email;
    _displayName = user.displayName ?? user.email.split('@').first;
    _emailVerified = user.emailVerified;
    _pendingVerificationEmail = null;
  }

  // ---------------------------------------------------------------------
  // Account actions — real accounts when a gateway exists, demo otherwise.
  // Each returns null on success or an [AuthFailure] to show to the user.
  // ---------------------------------------------------------------------

  Future<AuthFailure?> signIn({required String email, required String password, bool rememberMe = true}) async {
    final gateway = _gateway;
    if (gateway == null) {
      final ok = await signInDemo(email: email, password: password, rememberMe: rememberMe);
      return ok ? null : const AuthFailure(AuthFailureKind.invalidCredentials);
    }
    try {
      final user = await gateway.signIn(email: email, password: password);
      _applyUser(user);
      notifyListeners();
      await _safe(() async {
        await _store.setBool(_rememberKey, rememberMe);
        await _store.setString(_statusKey, AuthStatus.signedIn.name);
      });
      return null;
    } on AuthFailure catch (f) {
      return f;
    }
  }

  /// Real accounts: creates the account; when e-mail confirmation is on, the
  /// user is NOT signed in and [pendingVerificationEmail] is set.
  Future<AuthFailure?> register({required String name, required String email, required String password}) async {
    final gateway = _gateway;
    if (gateway == null) {
      await registerDemo(name: name, email: email);
      return null;
    }
    try {
      final user = await gateway.signUp(name: name, email: email, password: password);
      if (user != null) {
        _applyUser(user);
        await _safe(() => _store.setString(_statusKey, AuthStatus.signedIn.name));
      } else {
        _pendingVerificationEmail = email.trim().toLowerCase();
      }
      notifyListeners();
      return null;
    } on AuthFailure catch (f) {
      return f;
    }
  }

  /// Sends a reset e-mail (real accounts). The UI always shows the same
  /// confirmation, so it never reveals whether the address has an account.
  Future<AuthFailure?> requestPasswordReset(String email) async {
    final gateway = _gateway;
    if (gateway == null) return null;
    try {
      await gateway.sendPasswordReset(email);
      return null;
    } on AuthFailure catch (f) {
      return f.kind == AuthFailureKind.network || f.kind == AuthFailureKind.rateLimited ? f : null;
    }
  }

  /// Chooses a new password inside a recovery session (real accounts).
  Future<AuthFailure?> completePasswordReset(String newPassword) async {
    final gateway = _gateway;
    if (gateway == null) return null;
    try {
      await gateway.updatePassword(newPassword);
      _recoveringPassword = false;
      notifyListeners();
      return null;
    } on AuthFailure catch (f) {
      return f;
    }
  }

  Future<AuthFailure?> resendVerification() async {
    final gateway = _gateway;
    final email = _pendingVerificationEmail ?? _email;
    if (gateway == null || email == null) return null;
    try {
      await gateway.resendVerification(email);
      return null;
    } on AuthFailure catch (f) {
      return f;
    }
  }

  /// Leaves the "check your e-mail" step without an account session.
  void clearPendingVerification() {
    if (_pendingVerificationEmail == null) return;
    _pendingVerificationEmail = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<T?> _read<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  Future<void> _quiet(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {}
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

  /// Edits the locally stored display name of a demo account (no server).
  /// Returns false for guests or blank names.
  Future<bool> updateDisplayName(String name) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!isSignedIn || clean.isEmpty || clean.length > maxNameLength) return false;
    _displayName = clean;
    notifyListeners();
    await _safe(() => _store.setString(_nameKey, clean));
    final gateway = _gateway;
    if (gateway != null) await _quiet(() => gateway.updateDisplayName(clean));
    return true;
  }

  static const maxNameLength = 40;

  Future<void> signOut() async {
    final gateway = _gateway;
    if (gateway != null && isSignedIn) await _quiet(gateway.signOut);
    _recoveringPassword = false;
    _pendingVerificationEmail = null;
    await _setSession(AuthStatus.signedOut, name: null, email: null, verified: false, persist: true);
  }

  /// Clears ALL demo auth state, including onboarding (for testing).
  Future<void> resetDemo() async {
    final gateway = _gateway;
    if (gateway != null && isSignedIn) await _quiet(gateway.signOut);
    _recoveringPassword = false;
    _pendingVerificationEmail = null;
    _onboardingSeen = false;
    _status = AuthStatus.signedOut;
    _displayName = null;
    _email = null;
    _emailVerified = false;
    notifyListeners();
    await _safe(() async {
      for (final key in [_onboardingKey, _statusKey, _nameKey, _emailKey, _verifiedKey, _rememberKey]) {
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
