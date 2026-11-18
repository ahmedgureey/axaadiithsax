import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/features/auth/auth_controller.dart';
import 'package:xadiithapp/features/auth/presentation/forgot_password_screen.dart';
import 'package:xadiithapp/features/auth/presentation/reset_password_screen.dart';
import 'package:xadiithapp/features/splash/presentation/splash_screen.dart';
import 'package:xadiithapp/core/widgets/widgets.dart';

const _demoEmail = AuthController.demoEmail;
const _demoPassword = AuthController.demoPassword;

class _Harness {
  _Harness(this.store, this.services);
  final InMemorySettingsStore store;
  final AppServices services;
  AuthController get auth => services.auth;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  String initial = AppRoutes.welcome,
  bool onboarded = true,
  Size size = const Size(390, 844),
  InMemorySettingsStore? store,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final s = store ?? InMemorySettingsStore({'auth.onboardingSeen': onboarded});
  final services = await AppServices.create(s);
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: initial));
  await tester.pumpAndSettle();
  return _Harness(s, services);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps a button that triggers [AuthController.demoDelay].
Future<void> _tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(AuthController.demoDelay);
  await tester.pumpAndSettle();
}

Finder _field(int i) => find.byType(TextFormField).at(i);
Finder _button(String label) => find.widgetWithText(FilledButton, label);
bool _inMainApp(WidgetTester tester) => find.byType(NavigationBar).evaluate().isNotEmpty;

void main() {
  group('Splash', () {
    testWidgets('deep green brand screen with name and subtitle', (tester) async {
      final store = InMemorySettingsStore();
      final services = await AppServices.create(store);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(XadiisApp(services: services));

      expect(find.text('Xadiith App'), findsOneWidget);
      expect(find.text('Axaadiista Nabiga ﷺ'), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final scheme = Theme.of(tester.element(find.byType(AppLogo))).colorScheme;
      expect(scaffold.backgroundColor, scheme.tertiary);

      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();
      expect(find.text('Baro Axaadiista Nabiga ﷺ'), findsOneWidget, reason: 'first launch → onboarding');
    });
  });

  group('Onboarding', () {
    testWidgets('three pages, Next/Bilow, completion persisted', (tester) async {
      final h = await _pump(tester, initial: AppRoutes.onboarding, onboarded: false);
      expect(find.text('Baro Axaadiista Nabiga ﷺ'), findsOneWidget);
      expect(find.bySemanticsLabel('Bogga 1 ee 3'), findsOneWidget);

      await _tap(tester, _button('Xiga'));
      expect(find.text('Akhri oo Faham'), findsWidgets);
      await _tap(tester, _button('Xiga'));
      expect(find.text('Xifdi oo Dib-u-eeg'), findsWidgets);
      expect(_button('Bilow'), findsOneWidget);

      await _tap(tester, _button('Bilow'));
      expect(find.text('Gal Akoonka'), findsOneWidget);
      expect(await h.store.getBool('auth.onboardingSeen'), isTrue);
    });

    testWidgets('skip persists completion; next launch skips onboarding', (tester) async {
      final h = await _pump(tester, initial: AppRoutes.onboarding, onboarded: false);
      await _tap(tester, find.text('Ka gudub'));
      expect(find.text('Gal Akoonka'), findsOneWidget);

      // Simulate an app restart with the same storage.
      await tester.pumpWidget(const SizedBox());
      final services = await AppServices.create(h.store);
      await tester.pumpWidget(XadiisApp(services: services));
      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();
      expect(find.text('Gal Akoonka'), findsOneWidget);
    });
  });

  group('Welcome', () {
    testWidgets('buttons open login / register; back returns', (tester) async {
      await _pump(tester);
      await _tap(tester, find.text('Gal Akoonka'));
      expect(find.text('Ku soo dhowow mar kale'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Gal Akoonka'), findsOneWidget);

      await _tap(tester, find.text('Samee Akoon'));
      expect(find.text('Magaca oo buuxa'), findsOneWidget);
    });

    testWidgets('guest access opens Home without authenticating', (tester) async {
      final h = await _pump(tester);
      await _tap(tester, find.text('Sii wad adigoon gelin'));
      expect(_inMainApp(tester), isTrue);
      expect(h.auth.isGuest, isTrue);
      expect(h.auth.isSignedIn, isFalse);
      expect(h.auth.emailVerified, isFalse);
    });
  });

  group('Login', () {
    Future<_Harness> openLogin(WidgetTester tester) async {
      final h = await _pump(tester);
      await _tap(tester, find.text('Gal Akoonka'));
      return h;
    }

    testWidgets('required fields', (tester) async {
      await openLogin(tester);
      await _tap(tester, _button('Gal'));
      expect(find.text('Fadlan geli email-kaaga.'), findsOneWidget);
      expect(find.text('Fadlan geli furaha sirta ah.'), findsOneWidget);
    });

    testWidgets('invalid email format and short password', (tester) async {
      await openLogin(tester);
      await tester.enterText(_field(0), 'amina@');
      await tester.enterText(_field(1), 'abc');
      await _tap(tester, _button('Gal'));
      expect(find.text('Email-ku sax maaha.'), findsOneWidget);
      expect(find.text('Furuhu waa inuu ahaadaa ugu yaraan 8 xaraf.'), findsOneWidget);
    });

    testWidgets('non-demo credentials are rejected with a friendly error', (tester) async {
      final h = await openLogin(tester);
      await tester.enterText(_field(0), 'amina@example.com');
      await tester.enterText(_field(1), 'password123');
      await _tapAndWait(tester, _button('Gal'));
      expect(find.textContaining('kuma habboona akoonka demo-ga'), findsOneWidget);
      expect(h.auth.canUseApp, isFalse);
      expect(_inMainApp(tester), isFalse);
    });

    testWidgets('email is trimmed, password is NOT trimmed', (tester) async {
      final h = await openLogin(tester);
      await tester.enterText(_field(0), '  DEMO@xadiis.app ');
      await tester.enterText(_field(1), '$_demoPassword ');
      await _tapAndWait(tester, _button('Gal'));
      expect(h.auth.isSignedIn, isFalse, reason: 'trailing space changes the password');

      await tester.enterText(_field(1), _demoPassword);
      await _tapAndWait(tester, _button('Gal'));
      expect(h.auth.isSignedIn, isTrue);
      expect(h.auth.emailVerified, isTrue);
      expect(_inMainApp(tester), isTrue);
    });

    testWidgets('fill demo + password visibility toggle', (tester) async {
      await openLogin(tester);
      await _tap(tester, find.text('Buuxi xogta demo-ga'));
      expect(find.text(_demoEmail), findsWidgets);
      EditableText pw() => tester.widget<EditableText>(
        find.descendant(of: find.byType(PasswordTextField), matching: find.byType(EditableText)),
      );
      expect(pw().obscureText, isTrue);
      await _tap(tester, find.byTooltip('Muuji furaha'));
      expect(pw().obscureText, isFalse);
      await _tap(tester, find.byTooltip('Qari furaha'));
      expect(pw().obscureText, isTrue);
    });

    testWidgets('"Tijaabi Demo-ga" signs in with the demo account', (tester) async {
      final h = await openLogin(tester);
      await _tapAndWait(tester, find.text('Tijaabi Demo-ga'));
      expect(h.auth.isSignedIn, isTrue);
      expect(h.auth.displayName, AuthController.demoName);
      expect(_inMainApp(tester), isTrue);
    });

    testWidgets('"I xasuuso" off keeps the session in memory only', (tester) async {
      final h = await openLogin(tester);
      await _tap(tester, find.text('I xasuuso'));
      await _tapAndWait(tester, find.text('Tijaabi Demo-ga'));
      expect(h.auth.isSignedIn, isTrue);
      expect(await h.store.getString('auth.status'), AuthStatus.signedOut.name);
      expect(await h.store.getString('auth.email'), isNull);
    });

    testWidgets('login ⇄ register links replace each other (no back loop)', (tester) async {
      await openLogin(tester);
      await _tap(tester, find.text('Akoon ma lihid? Isdiiwaangeli'));
      await _tap(tester, find.text('Akoon ma leedahay? Gal'));
      expect(find.text('Ku soo dhowow mar kale'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Gal Akoonka'), findsOneWidget, reason: 'back goes straight to Welcome');
    });
  });

  group('Register & verify e-mail', () {
    Future<_Harness> openRegister(WidgetTester tester, {Size size = const Size(390, 844)}) async {
      final h = await _pump(tester, size: size);
      await _tap(tester, find.text('Samee Akoon'));
      return h;
    }

    Future<void> fillValid(WidgetTester tester) async {
      await tester.enterText(_field(0), 'Amina Cali');
      await tester.enterText(_field(1), ' amina@example.com ');
      await tester.enterText(_field(2), 'password123');
      await tester.enterText(_field(3), 'password123');
    }

    testWidgets('all fields and terms are required', (tester) async {
      await openRegister(tester);
      await _tap(tester, _button('Samee Akoon'));
      expect(find.text('Magacu waa qasab.'), findsOneWidget);
      expect(find.text('Fadlan geli email-kaaga.'), findsOneWidget);
      expect(find.text('Fadlan geli furaha sirta ah.'), findsOneWidget);
      expect(find.text('Fadlan ku celi furaha sirta ah.'), findsOneWidget);
      expect(find.text('Fadlan aqbal shuruudaha si aad u sii wadato.'), findsOneWidget);
    });

    testWidgets('password mismatch', (tester) async {
      await openRegister(tester);
      await fillValid(tester);
      await tester.enterText(_field(3), 'password124');
      await _tap(tester, _button('Samee Akoon'));
      expect(find.text('Furayaashu isma laha.'), findsOneWidget);
    });

    testWidgets('both password fields toggle visibility independently', (tester) async {
      await openRegister(tester);
      final toggles = find.byTooltip('Muuji furaha');
      expect(toggles, findsNWidgets(2));
      await _tap(tester, toggles.first);
      expect(find.byTooltip('Qari furaha'), findsOneWidget);
      expect(find.byTooltip('Muuji furaha'), findsOneWidget);
    });

    testWidgets('register → masked e-mail → simulated verification → home', (tester) async {
      final h = await openRegister(tester);
      await fillValid(tester);
      await _tap(tester, find.byType(Checkbox));
      await _tapAndWait(tester, _button('Samee Akoon'));

      expect(find.text('Xaqiiji Email-ka'), findsOneWidget);
      expect(find.textContaining('a****@example.com'), findsOneWidget);
      expect(h.auth.isSignedIn, isTrue);
      expect(h.auth.emailVerified, isFalse);
      expect(h.auth.email, 'amina@example.com');

      // No password anywhere in storage.
      for (final key in ['auth.status', 'auth.displayName', 'auth.email']) {
        expect(await h.store.getString(key), isNot(contains('password123')));
      }

      await _tapAndWait(tester, _button('Tijaabi Xaqiijinta'));
      expect(h.auth.emailVerified, isTrue);
      expect(_inMainApp(tester), isTrue);
    });

    testWidgets('"Ku noqo Gelitaanka" ends the unverified session', (tester) async {
      final h = await openRegister(tester);
      await fillValid(tester);
      await _tap(tester, find.byType(Checkbox));
      await _tapAndWait(tester, _button('Samee Akoon'));
      await _tap(tester, find.text('Ku noqo Gelitaanka'));
      expect(find.text('Ku soo dhowow mar kale'), findsOneWidget);
      expect(h.auth.canUseApp, isFalse);
    });

    testWidgets('"Hadda ka dib" → unverified user can verify later from profile', (tester) async {
      final h = await openRegister(tester);
      await fillValid(tester);
      await _tap(tester, find.byType(Checkbox));
      await _tapAndWait(tester, _button('Samee Akoon'));
      await _tap(tester, find.text('Hadda ka dib'));
      expect(_inMainApp(tester), isTrue);

      expect(h.auth.emailVerified, isFalse);
      await _tap(tester, find.descendant(of: find.byType(NavigationBar), matching: find.text('Aniga')));
      expect(find.text('Akoon demo · email lama xaqiijin'), findsOneWidget);
      await _tap(tester, find.text('Xaqiiji email-ka (demo)'));
      expect(find.text('Xaqiiji Email-ka'), findsOneWidget);
    });

    testWidgets('privacy link is reachable before signing in', (tester) async {
      await openRegister(tester);
      await _tap(tester, find.text('arrimaha gaarka ah'));
      expect(find.text('Server ma jiro'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Magaca oo buuxa'), findsOneWidget);
    });
  });

  group('Forgot & reset password', () {
    testWidgets('forgot validates, shows generic confirmation, reset demo completes', (tester) async {
      final h = await _pump(tester, initial: AppRoutes.login);
      await _tap(tester, find.text('Ilowday furaha?'));
      expect(find.text('Ma illowday furaha sirta ah?'), findsOneWidget);

      await tester.enterText(_field(0), 'not-an-email');
      await _tap(tester, _button('Sii wad'));
      expect(find.text('Email-ku sax maaha.'), findsOneWidget);

      await tester.enterText(_field(0), 'amina@example.com');
      await _tapAndWait(tester, _button('Sii wad'));
      expect(find.text(ForgotPasswordScreen.confirmation), findsOneWidget);

      await _tap(tester, find.text('U gudub furaha cusub (demo)'));
      await tester.enterText(_field(0), 'newpass12');
      await tester.enterText(_field(1), 'newpass13');
      await _tap(tester, _button('Cusboonaysii Furaha'));
      expect(find.text('Furayaashu isma laha.'), findsOneWidget);

      await tester.enterText(_field(1), 'newpass12');
      await _tapAndWait(tester, _button('Cusboonaysii Furaha'));
      expect(find.text(ResetPasswordScreen.doneMessage), findsOneWidget);
      expect(h.auth.canUseApp, isFalse, reason: 'reset never signs anyone in');

      await _tap(tester, _button('Ku noqo Gelitaanka'));
      expect(find.text('Ku soo dhowow mar kale'), findsOneWidget);
    });

    testWidgets('back from forgot returns to login (button and system back)', (tester) async {
      await _pump(tester, initial: AppRoutes.login);
      await _tap(tester, find.text('Ilowday furaha?'));
      await _tap(tester, find.text('Ku noqo Gelitaanka'));
      expect(find.text('Ku soo dhowow mar kale'), findsOneWidget);

      await _tap(tester, find.text('Ilowday furaha?'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Ku soo dhowow mar kale'), findsOneWidget);
    });

    testWidgets('reset requires both fields', (tester) async {
      await _pump(tester, initial: AppRoutes.resetPassword);
      await _tap(tester, _button('Cusboonaysii Furaha'));
      expect(find.text('Fadlan geli furaha sirta ah.'), findsOneWidget);
      expect(find.text('Fadlan ku celi furaha sirta ah.'), findsOneWidget);
    });
  });

  group('Demo state', () {
    testWidgets('resetDemo clears session and onboarding', (tester) async {
      final h = await _pump(tester);
      await h.auth.tryDemo();
      await h.auth.resetDemo();
      expect(h.auth.onboardingSeen, isFalse);
      expect(h.auth.status, AuthStatus.signedOut);
      expect(await h.store.getBool('auth.onboardingSeen'), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Baro Axaadiista Nabiga ﷺ'), findsOneWidget, reason: 'guard sends to onboarding');
    });
  });

  group('Small screens, dark mode, large text', () {
    const routes = [
      AppRoutes.welcome,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
      AppRoutes.resetPassword,
      AppRoutes.onboarding,
    ];
    for (final route in routes) {
      testWidgets('$route has no overflow at 320×568, dark, 1.3× text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = InMemorySettingsStore({
          'auth.onboardingSeen': route != AppRoutes.onboarding,
          'settings.themeMode': 'dark',
        });
        await _pump(tester, initial: route, size: const Size(320, 568), store: store);
        expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await tester.drag(scrollables.first, const Offset(0, -1500));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('verify-email has no overflow at 320×568, dark', (tester) async {
      final store = InMemorySettingsStore({'auth.onboardingSeen': true, 'settings.themeMode': 'dark'});
      final services = await AppServices.create(store);
      await services.auth.registerDemo(name: 'Amina', email: 'amina@example.com');
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(XadiisApp(services: services, initialLocation: AppRoutes.verifyEmail));
      await tester.pumpAndSettle();
      expect(find.text('Xaqiiji Email-ka'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
