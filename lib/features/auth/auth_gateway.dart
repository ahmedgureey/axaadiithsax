/// Real account backend used by [AuthController] when one is configured.
/// Without a gateway the controller runs the local demo flow.
abstract class AuthGateway {
  /// The signed-in user restored from the backend's own session store.
  AuthUser? get currentUser;

  /// Session changes the app did not start itself (e-mail link confirmed,
  /// password-recovery link opened, session expired).
  Stream<AuthGatewayEvent> get events;

  /// Throws [AuthFailure].
  Future<AuthUser> signIn({required String email, required String password});

  /// Returns the user when a session started immediately (e-mail
  /// confirmation disabled), or null when a confirmation e-mail was sent.
  /// Throws [AuthFailure].
  Future<AuthUser?> signUp({required String name, required String email, required String password});

  Future<void> sendPasswordReset(String email);
  Future<void> resendVerification(String email);

  /// Only valid inside a password-recovery session. Throws [AuthFailure].
  Future<void> updatePassword(String newPassword);

  Future<void> updateDisplayName(String name);
  Future<void> signOut();
}

class AuthUser {
  const AuthUser({required this.email, this.displayName, this.emailVerified = false});

  final String email;
  final String? displayName;
  final bool emailVerified;
}

enum AuthGatewayEventKind { signedIn, signedOut, passwordRecovery, userUpdated }

class AuthGatewayEvent {
  const AuthGatewayEvent(this.kind, [this.user]);

  final AuthGatewayEventKind kind;
  final AuthUser? user;
}

enum AuthFailureKind {
  invalidCredentials,
  emailNotConfirmed,
  weakPassword,
  rateLimited,
  network,
  noRecoverySession,
  unknown,
}

/// A backend error mapped to a user-facing Somali message. Messages never
/// reveal whether an e-mail address has an account.
class AuthFailure implements Exception {
  const AuthFailure(this.kind);

  final AuthFailureKind kind;

  String get message => switch (kind) {
    AuthFailureKind.invalidCredentials => 'Email-ka ama furaha sirta ah waa khalad.',
    AuthFailureKind.emailNotConfirmed =>
      'Email-kaaga weli lama xaqiijin. Riix link-ga email-ka laguu soo diray, kadibna gal.',
    AuthFailureKind.weakPassword => 'Furaha sirta ah waa daciif. Isticmaal mid ka dheer oo xarfo iyo tirooyin leh.',
    AuthFailureKind.rateLimited => 'Isku day badan ayaa dhacay. Fadlan sug dhowr daqiiqo kadibna isku day.',
    AuthFailureKind.network => 'Internet lama heli karo. Hubi xiriirka kadibna isku day mar kale.',
    AuthFailureKind.noRecoverySession =>
      'Link-ga dib-u-dejinta waa dhacay ama lama furin. Codso email cusub kadibna ka fur telefoonkan.',
    AuthFailureKind.unknown => 'Wax khalad ah ayaa dhacay. Fadlan isku day mar kale.',
  };

  @override
  String toString() => 'AuthFailure($kind)';
}
