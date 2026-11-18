import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/routing/app_router.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/features/auth/auth_controller.dart';

Future<AuthController> _auth({required bool onboarded, required AuthStatus status}) async {
  final c = AuthController(
    InMemorySettingsStore({'auth.onboardingSeen': onboarded, 'auth.status': status.name}),
  );
  await c.load();
  return c;
}

void main() {
  test('splash is never redirected', () async {
    final a = await _auth(onboarded: false, status: AuthStatus.signedOut);
    expect(appRedirect(a, AppRoutes.splash), isNull);
  });

  test('onboarding is forced until completed', () async {
    final a = await _auth(onboarded: false, status: AuthStatus.signedOut);
    expect(appRedirect(a, AppRoutes.home), AppRoutes.onboarding);
    expect(appRedirect(a, AppRoutes.login), AppRoutes.onboarding);
    expect(appRedirect(a, AppRoutes.onboarding), isNull);
  });

  test('signed-out users only see the auth flow', () async {
    final a = await _auth(onboarded: true, status: AuthStatus.signedOut);
    expect(appRedirect(a, AppRoutes.home), AppRoutes.welcome);
    expect(appRedirect(a, AppRoutes.hadith('x')), AppRoutes.welcome);
    for (final r in AppRoutes.authFlow.difference({AppRoutes.verifyEmail})) {
      expect(appRedirect(a, r), isNull, reason: r);
    }
    expect(appRedirect(a, AppRoutes.onboarding), AppRoutes.welcome);
  });

  test('signed-in users skip the auth flow', () async {
    final a = await _auth(onboarded: true, status: AuthStatus.signedIn);
    expect(appRedirect(a, AppRoutes.login), AppRoutes.home);
    expect(appRedirect(a, AppRoutes.welcome), AppRoutes.home);
    expect(appRedirect(a, AppRoutes.books), isNull);
  });

  test('guests may open login but use the app freely', () async {
    final a = await _auth(onboarded: true, status: AuthStatus.guest);
    expect(appRedirect(a, AppRoutes.login), isNull);
    expect(appRedirect(a, AppRoutes.search), isNull);
  });

  test('splash destination', () async {
    expect(
      splashDestination(await _auth(onboarded: false, status: AuthStatus.signedOut)),
      AppRoutes.onboarding,
    );
    expect(splashDestination(await _auth(onboarded: true, status: AuthStatus.signedOut)), AppRoutes.welcome);
    expect(splashDestination(await _auth(onboarded: true, status: AuthStatus.guest)), AppRoutes.home);
  });

  test('route builders encode parameters', () {
    expect(AppRoutes.book('bukhari'), '/books/bukhari');
    expect(AppRoutes.chapter('bukhari', 'bukhari-c1'), '/books/bukhari/chapters/bukhari-c1');
    expect(AppRoutes.hadith('a b'), '/hadith/a%20b');
    expect(AppRoutes.searchCategory('salah'), '/search?category=salah');
  });

  test('auth controller never stores a password', () async {
    final store = InMemorySettingsStore();
    final a = AuthController(store);
    expect(await a.signInDemo(email: 'amina@example.com', password: 'whatever1'), isFalse);
    await a.signInDemo(email: AuthController.demoEmail, password: AuthController.demoPassword);
    expect(a.displayName, AuthController.demoName);
    for (final key in ['auth.status', 'auth.displayName', 'auth.email']) {
      expect(await store.getString(key), isNot(contains('password')));
    }
  });

  test('verify-email only for a simulated, unverified session', () async {
    final store = InMemorySettingsStore({'auth.onboardingSeen': true});
    final a = AuthController(store);
    await a.load();
    expect(appRedirect(a, AppRoutes.verifyEmail), AppRoutes.welcome);

    await a.continueAsGuest();
    expect(appRedirect(a, AppRoutes.verifyEmail), AppRoutes.home);

    await a.registerDemo(name: 'Amina', email: 'amina@example.com');
    expect(appRedirect(a, AppRoutes.verifyEmail), isNull);
    expect(appRedirect(a, AppRoutes.login), AppRoutes.home);

    await a.verifyEmailDemo();
    expect(appRedirect(a, AppRoutes.verifyEmail), AppRoutes.home);
  });

  test('privacy and about are readable while signed out', () async {
    final a = await _auth(onboarded: true, status: AuthStatus.signedOut);
    expect(appRedirect(a, AppRoutes.settingsPrivacy), isNull);
    expect(appRedirect(a, AppRoutes.about), isNull);
    expect(appRedirect(a, AppRoutes.settings), AppRoutes.welcome);
  });
}
