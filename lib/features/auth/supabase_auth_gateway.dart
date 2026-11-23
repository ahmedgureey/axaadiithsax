import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_gateway.dart';

/// Supabase Auth (e-mail + password). Sessions are stored and refreshed by
/// supabase_flutter itself; the password never touches app storage.
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  /// Where e-mail links (confirmation, password reset) send the user back.
  /// Must be listed in Supabase → Authentication → URL Configuration →
  /// Redirect URLs, and matches the Android intent filter.
  static const redirectUrl = 'com.xadiithapp.app://login-callback';

  final sb.SupabaseClient _client;

  sb.GoTrueClient get _auth => _client.auth;

  /// On the web the dashboard's Site URL is used instead of the app scheme.
  String? get _redirect => kIsWeb ? null : redirectUrl;

  static AuthUser _map(sb.User u) {
    final name = u.userMetadata?['display_name'];
    return AuthUser(
      email: u.email ?? '',
      displayName: name is String && name.trim().isNotEmpty ? name : null,
      emailVerified: u.emailConfirmedAt != null,
    );
  }

  @override
  AuthUser? get currentUser {
    final u = _auth.currentUser;
    return u == null || _auth.currentSession == null ? null : _map(u);
  }

  @override
  Stream<AuthGatewayEvent> get events => _auth.onAuthStateChange
      .map((state) {
        final user = state.session?.user;
        return switch (state.event) {
          sb.AuthChangeEvent.signedIn when user != null => AuthGatewayEvent(AuthGatewayEventKind.signedIn, _map(user)),
          sb.AuthChangeEvent.passwordRecovery => AuthGatewayEvent(
            AuthGatewayEventKind.passwordRecovery,
            user == null ? null : _map(user),
          ),
          sb.AuthChangeEvent.userUpdated when user != null => AuthGatewayEvent(
            AuthGatewayEventKind.userUpdated,
            _map(user),
          ),
          sb.AuthChangeEvent.signedOut => const AuthGatewayEvent(AuthGatewayEventKind.signedOut),
          _ => null,
        };
      })
      .where((e) => e != null)
      .cast<AuthGatewayEvent>();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.AuthRetryableFetchException {
      throw const AuthFailure(AuthFailureKind.network);
    } on sb.AuthWeakPasswordException {
      throw const AuthFailure(AuthFailureKind.weakPassword);
    } on sb.AuthException catch (e) {
      final code = e.code ?? '';
      throw AuthFailure(switch (code) {
        'invalid_credentials' => AuthFailureKind.invalidCredentials,
        'email_not_confirmed' => AuthFailureKind.emailNotConfirmed,
        'weak_password' => AuthFailureKind.weakPassword,
        'over_email_send_rate_limit' || 'over_request_rate_limit' => AuthFailureKind.rateLimited,
        _ => e.statusCode == '429' ? AuthFailureKind.rateLimited : AuthFailureKind.unknown,
      });
    } on AuthFailure {
      rethrow;
    } catch (e) {
      debugPrint('Auth error: $e');
      throw const AuthFailure(AuthFailureKind.network);
    }
  }

  @override
  Future<AuthUser> signIn({required String email, required String password}) => _guard(() async {
    final res = await _auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
    final user = res.user;
    if (user == null) throw const AuthFailure(AuthFailureKind.invalidCredentials);
    return _map(user);
  });

  @override
  Future<AuthUser?> signUp({required String name, required String email, required String password}) => _guard(() async {
    final res = await _auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      emailRedirectTo: _redirect,
      data: {'display_name': name.trim()},
    );
    final user = res.user;
    return res.session != null && user != null ? _map(user) : null;
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email.trim().toLowerCase(), redirectTo: _redirect));

  @override
  Future<void> resendVerification(String email) => _guard(
    () => _auth.resend(type: sb.OtpType.signup, email: email.trim().toLowerCase(), emailRedirectTo: _redirect),
  );

  @override
  Future<void> updatePassword(String newPassword) => _guard(() async {
    if (_auth.currentSession == null) throw const AuthFailure(AuthFailureKind.noRecoverySession);
    await _auth.updateUser(sb.UserAttributes(password: newPassword));
  });

  @override
  Future<void> updateDisplayName(String name) =>
      _guard(() => _auth.updateUser(sb.UserAttributes(data: {'display_name': name})));

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());
}
