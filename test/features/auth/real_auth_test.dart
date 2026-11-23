import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_router.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/features/auth/auth_controller.dart';
import 'package:xadiithapp/features/auth/auth_gateway.dart';
import 'package:xadiithapp/features/auth/presentation/forgot_password_screen.dart';

import '../../support/test_library.dart';

/// Real-account mode (Supabase) through a fake gateway: no network.
class FakeGateway implements AuthGateway {
  FakeGateway({this.user, this.confirmEmail = true});

  AuthUser? user;
  bool confirmEmail;
  AuthFailure? nextFailure;
  final calls = <String>[];
  final _events = StreamController<AuthGatewayEvent>.broadcast();

  void emit(AuthGatewayEvent e) => _events.add(e);

  Future<T> _run<T>(String name, T Function() ok) async {
    calls.add(name);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
    return ok();
  }

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthGatewayEvent> get events => _events.stream;

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      _run('signIn', () => user = AuthUser(email: email, displayName: 'Cali', emailVerified: true));

  @override
  Future<AuthUser?> signUp({required String name, required String email, required String password}) => _run(
    'signUp',
    () => confirmEmail ? null : (user = AuthUser(email: email, displayName: name, emailVerified: true)),
  );

  @override
  Future<void> sendPasswordReset(String email) => _run('reset:$email', () {});

  @override
  Future<void> resendVerification(String email) => _run('resend:$email', () {});

  @override
  Future<void> updatePassword(String newPassword) => _run('updatePassword', () {});

  @override
  Future<void> updateDisplayName(String name) => _run('name:$name', () {});

  @override
  Future<void> signOut() => _run('signOut', () => user = null);
}

InMemorySettingsStore _store() => InMemorySettingsStore({'auth.onboardingSeen': true});

Future<AuthController> _controller(FakeGateway g, [InMemorySettingsStore? store]) async {
  final c = AuthController(store ?? _store(), gateway: g);
  await c.load();
  return c;
}

Future<AppServices> _pump(WidgetTester tester, FakeGateway g, String route) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final services = await AppServices.create(_store(), repository: testRepository(), authGateway: g);
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: route));
  await tester.pumpAndSettle();
  return services;
}

void main() {
  group('AuthController with a real backend', () {
    test('restores the backend session; ignores a stale local "signedIn"', () async {
      final restored = await _controller(FakeGateway(user: const AuthUser(email: 'a@b.so', emailVerified: true)));
      expect(restored.isSignedIn, isTrue);
      expect(restored.usesRealAccounts, isTrue);
      expect(restored.displayName, 'a');

      final stale = await _controller(
        FakeGateway(),
        InMemorySettingsStore({'auth.onboardingSeen': true, 'auth.status': 'signedIn', 'auth.email': 'x@y.so'}),
      );
      expect(stale.isSignedIn, isFalse);
      expect(stale.email, isNull);
    });

    test('sign in success and mapped failure', () async {
      final g = FakeGateway();
      final c = await _controller(g);
      g.nextFailure = const AuthFailure(AuthFailureKind.invalidCredentials);
      final failed = await c.signIn(email: 'a@b.so', password: 'wrongpass');
      expect(failed?.kind, AuthFailureKind.invalidCredentials);
      expect(c.isSignedIn, isFalse);

      expect(await c.signIn(email: 'a@b.so', password: 'rightpass'), isNull);
      expect(c.isSignedIn, isTrue);
      expect(c.emailVerified, isTrue);
    });

    test('"remember me" off: next start signs out of the backend', () async {
      final store = _store();
      final g = FakeGateway();
      final c = await _controller(g, store);
      await c.signIn(email: 'a@b.so', password: 'rightpass', rememberMe: false);
      final next = await _controller(g, store);
      expect(next.isSignedIn, isFalse);
      expect(g.calls, contains('signOut'));
    });

    test('register with e-mail confirmation → pending, not signed in', () async {
      final g = FakeGateway();
      final c = await _controller(g);
      expect(await c.register(name: 'Cali', email: ' Cali@B.so ', password: 'Password1'), isNull);
      expect(c.isSignedIn, isFalse);
      expect(c.pendingVerificationEmail, 'cali@b.so');
      expect(c.maskedEmail, startsWith('c'));
      expect(await c.resendVerification(), isNull);
      expect(g.calls, contains('resend:cali@b.so'));
    });

    test('register without confirmation → signed in immediately', () async {
      final c = await _controller(FakeGateway(confirmEmail: false));
      await c.register(name: 'Cali', email: 'cali@b.so', password: 'Password1');
      expect(c.isSignedIn, isTrue);
      expect(c.displayName, 'Cali');
    });

    test('password reset never reveals accounts; only network errors surface', () async {
      final g = FakeGateway();
      final c = await _controller(g);
      g.nextFailure = const AuthFailure(AuthFailureKind.unknown);
      expect(await c.requestPasswordReset('nobody@b.so'), isNull);
      g.nextFailure = const AuthFailure(AuthFailureKind.network);
      expect((await c.requestPasswordReset('a@b.so'))?.kind, AuthFailureKind.network);
    });

    test('recovery link → recovering; new password clears it', () async {
      final g = FakeGateway();
      final c = await _controller(g);
      g.emit(
        const AuthGatewayEvent(AuthGatewayEventKind.passwordRecovery, AuthUser(email: 'a@b.so', emailVerified: true)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.isRecoveringPassword, isTrue);
      expect(appRedirect(c, AppRoutes.home), AppRoutes.resetPassword);
      expect(await c.completePasswordReset('NewPassword1'), isNull);
      expect(c.isRecoveringPassword, isFalse);
      expect(appRedirect(c, AppRoutes.home), isNull);
    });

    test('confirmation link (signedIn event) signs the user in', () async {
      final g = FakeGateway();
      final c = await _controller(g);
      g.emit(const AuthGatewayEvent(AuthGatewayEventKind.signedIn, AuthUser(email: 'a@b.so', emailVerified: true)));
      await Future<void>.delayed(Duration.zero);
      expect(c.isSignedIn, isTrue);
    });

    test('sign out and name change reach the backend', () async {
      final g = FakeGateway(user: const AuthUser(email: 'a@b.so', emailVerified: true));
      final c = await _controller(g);
      expect(await c.updateDisplayName('  Xaliimo  '), isTrue);
      expect(g.calls, contains('name:Xaliimo'));
      await c.signOut();
      expect(c.isSignedIn, isFalse);
      expect(g.calls, contains('signOut'));
    });

    test('pending verification may open /verify-email while signed out', () async {
      final c = await _controller(FakeGateway());
      expect(appRedirect(c, AppRoutes.verifyEmail), AppRoutes.welcome);
      await c.register(name: 'Cali', email: 'cali@b.so', password: 'Password1');
      expect(appRedirect(c, AppRoutes.verifyEmail), isNull);
    });
  });

  group('Screens in real-account mode', () {
    testWidgets('login hides the demo account and shows backend errors', (tester) async {
      final g = FakeGateway();
      final s = await _pump(tester, g, AppRoutes.login);
      expect(find.text('Akoonka demo-ga'), findsNothing);
      expect(find.text('Tijaabi Demo-ga'), findsNothing);

      g.nextFailure = const AuthFailure(AuthFailureKind.emailNotConfirmed);
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.so');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password1');
      await tester.tap(find.widgetWithText(FilledButton, 'Gal'));
      await tester.pumpAndSettle();
      expect(find.text(const AuthFailure(AuthFailureKind.emailNotConfirmed).message), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Gal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Gal'));
      await tester.pumpAndSettle();
      expect(s.auth.isSignedIn, isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('register → "check your e-mail" screen with resend', (tester) async {
      final g = FakeGateway();
      final s = await _pump(tester, g, AppRoutes.register);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Cali Axmed');
      await tester.enterText(fields.at(1), 'cali@b.so');
      await tester.enterText(fields.at(2), 'Password1');
      await tester.enterText(fields.at(3), 'Password1');
      final terms = find.byType(Checkbox);
      if (terms.evaluate().isNotEmpty) {
        await tester.ensureVisible(terms.first);
        await tester.tap(terms.first);
      }
      final submit = find.widgetWithText(FilledButton, 'Samee Akoon');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(s.auth.pendingVerificationEmail, 'cali@b.so');
      expect(find.text('Xaqiiji Email-ka'), findsOneWidget);
      expect(find.text('Tijaabi Xaqiijinta'), findsNothing); // no simulated verification
      await tester.ensureVisible(find.text('Dib u dir email-ka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dib u dir email-ka'));
      await tester.pumpAndSettle();
      expect(g.calls, contains('resend:cali@b.so'));
    });

    testWidgets('forgot password sends a real reset with a neutral message', (tester) async {
      final g = FakeGateway();
      await _pump(tester, g, AppRoutes.forgotPassword);
      await tester.enterText(find.byType(TextFormField), 'a@b.so');
      await tester.tap(find.widgetWithText(FilledButton, 'Sii wad'));
      await tester.pumpAndSettle();
      expect(g.calls, contains('reset:a@b.so'));
      expect(find.text(ForgotPasswordScreen.realConfirmation), findsOneWidget);
      expect(find.text('U gudub furaha cusub (demo)'), findsNothing);
    });
  });
}
