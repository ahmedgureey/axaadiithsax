import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/routing/app_router.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/features/onboarding/onboarding_controller.dart';

Future<OnboardingController> _onboarding({required bool seen, Map<String, Object> extra = const {}}) async {
  final c = OnboardingController(InMemorySettingsStore({OnboardingController.seenKey: seen, ...extra}));
  await c.load();
  return c;
}

void main() {
  test('splash is never redirected', () async {
    expect(appRedirect(await _onboarding(seen: false), AppRoutes.splash), isNull);
  });

  test('the introduction is shown until completed', () async {
    final o = await _onboarding(seen: false);
    expect(appRedirect(o, AppRoutes.home), AppRoutes.onboarding);
    expect(appRedirect(o, AppRoutes.onboarding), isNull);
    expect(splashDestination(o), AppRoutes.onboarding);
  });

  test('after the introduction every screen is open — no login needed', () async {
    final o = await _onboarding(seen: true);
    for (final r in [
      AppRoutes.home,
      AppRoutes.books,
      AppRoutes.search,
      AppRoutes.memorization,
      AppRoutes.profile,
      AppRoutes.favorites,
      AppRoutes.settings,
      AppRoutes.hadith('x'),
    ]) {
      expect(appRedirect(o, r), isNull, reason: r);
    }
    expect(appRedirect(o, AppRoutes.onboarding), AppRoutes.home);
    expect(splashDestination(o), AppRoutes.home);
  });

  test('links to the removed login / sign-up screens open Home', () async {
    final o = await _onboarding(seen: true);
    for (final r in AppRoutes.legacyAccountRoutes) {
      expect(appRedirect(o, r), AppRoutes.home, reason: r);
    }
  });

  test('old account data is deleted from the device; the introduction flag is kept', () async {
    final store = InMemorySettingsStore({
      OnboardingController.seenKey: true,
      'auth.status': 'signedIn',
      'auth.email': 'someone@example.test',
      'auth.displayName': 'Name',
    });
    final o = OnboardingController(store);
    await o.load();
    expect(o.onboardingSeen, isTrue);
    for (final key in OnboardingController.legacyAccountKeys) {
      expect(await store.getString(key), isNull, reason: key);
    }
  });

  test('reset shows the introduction again', () async {
    final o = await _onboarding(seen: true);
    await o.reset();
    expect(o.onboardingSeen, isFalse);
  });
}
