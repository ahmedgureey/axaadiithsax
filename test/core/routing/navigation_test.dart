import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/widgets/widgets.dart';
import 'package:xadiithapp/features/auth/auth_controller.dart';
import 'package:xadiithapp/features/splash/presentation/splash_screen.dart';

Future<AppServices> _services({bool onboarded = true, AuthStatus status = AuthStatus.signedIn}) {
  return AppServices.create(
    InMemorySettingsStore({'auth.onboardingSeen': onboarded, 'auth.status': status.name}),
  );
}

Future<AppServices> _pumpApp(
  WidgetTester tester, {
  String initial = AppRoutes.home,
  AppServices? services,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final s = services ?? await _services();
  await tester.pumpWidget(XadiisApp(services: s, initialLocation: initial));
  await tester.pumpAndSettle();
  return s;
}

Finder _tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

int _selectedTab(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Finder _appBarTitle(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('Initial flow', () {
    testWidgets('fresh install: splash → onboarding → welcome → guest → home', (tester) async {
      final services = await _services(onboarded: false, status: AuthStatus.signedOut);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(XadiisApp(services: services));
      expect(find.byType(AppLogo), findsOneWidget);

      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();
      expect(find.text('Akhri axaadiista'), findsOneWidget);

      await _tap(tester, find.text('Ka gudub'));
      expect(services.auth.onboardingSeen, isTrue);
      expect(find.text('Ku sii wad marti ahaan'), findsOneWidget);

      await _tap(tester, find.text('Ku sii wad marti ahaan'));
      expect(services.auth.status, AuthStatus.guest);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(_selectedTab(tester), 0);
    });

    testWidgets('returning signed-in user: splash goes straight to home', (tester) async {
      final services = await _services();
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(XadiisApp(services: services));
      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('signed-out user cannot open main app routes', (tester) async {
      await _pumpApp(tester, services: await _services(status: AuthStatus.signedOut));
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Ku sii wad marti ahaan'), findsOneWidget);
    });
  });

  group('Five tabs', () {
    testWidgets('all five tabs are reachable and highlighted', (tester) async {
      await _pumpApp(tester);
      const titles = ['Xadiis App', 'Kutubta', 'Raadinta', 'Xifdinta', 'Aniga'];
      const labels = ['Guriga', 'Kutubta', 'Raadinta', 'Xifdinta', 'Aniga'];
      for (var i = labels.length - 1; i >= 0; i--) {
        await _tap(tester, _tab(labels[i]));
        expect(_selectedTab(tester), i);
        expect(_appBarTitle(titles[i]), findsOneWidget);
      }
    });

    testWidgets('tab stacks are preserved; reselecting a tab returns to its root', (tester) async {
      await _pumpApp(tester);
      await _tap(tester, _tab('Kutubta'));
      await _tap(tester, find.text('Saxiix al-Bukhaari'));
      expect(find.text('Cutubyada'), findsOneWidget);

      await _tap(tester, _tab('Raadinta'));
      await _tap(tester, _tab('Kutubta'));
      expect(find.text('Cutubyada'), findsOneWidget, reason: 'book detail kept');
      expect(_selectedTab(tester), 1);

      await _tap(tester, _tab('Kutubta'));
      expect(find.text('Cutubyada'), findsNothing, reason: 'reselect pops to root');
      expect(_appBarTitle('Kutubta'), findsOneWidget);
    });

    testWidgets('search state survives tab switches', (tester) async {
      await _pumpApp(tester);
      await _tap(tester, _tab('Raadinta'));
      await tester.enterText(find.byType(TextField), 'tusaale');
      await tester.pumpAndSettle();
      expect(find.textContaining('natiijo'), findsOneWidget);
      await _tap(tester, _tab('Guriga'));
      await _tap(tester, _tab('Raadinta'));
      expect(find.text('tusaale'), findsOneWidget);
    });
  });

  group('Detail navigation', () {
    testWidgets('book → chapter → hadith detail → back keeps context and tab', (tester) async {
      await _pumpApp(tester, initial: AppRoutes.books);
      await _tap(tester, find.text('Saxiix Muslim'));
      await _tap(tester, find.text('Cutub tusaale 2'));
      expect(_appBarTitle('Cutub tusaale 2'), findsOneWidget);

      await _tap(tester, find.byType(HadithCard).first);
      expect(find.text('Tarjumaadda'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing, reason: 'focused reading screen');
      // Arabic content is RTL inside the LTR screen.
      final arabic = tester.element(
        find.descendant(of: find.byType(ArabicText).first, matching: find.byType(Text)),
      );
      expect(Directionality.of(arabic), TextDirection.rtl);

      await _tap(tester, find.byType(BackButton));
      expect(_appBarTitle('Cutub tusaale 2'), findsOneWidget);
      expect(_selectedTab(tester), 1);
    });

    testWidgets('daily hadith opens detail and records history', (tester) async {
      final services = await _pumpApp(tester);
      await _tap(tester, find.byType(DailyHadithCard));
      expect(find.text('Tarjumaadda'), findsOneWidget);
      expect(services.history.recentIds, hasLength(1));
      await _systemBack(tester);
      expect(_selectedTab(tester), 0);
    });

    testWidgets('home topic chip opens search tab filtered by category', (tester) async {
      await _pumpApp(tester);
      await tester.scrollUntilVisible(find.text('Salaadda'), 300, scrollable: find.byType(Scrollable).first);
      await _tap(tester, find.text('Salaadda'));
      expect(_selectedTab(tester), 2);
      expect(find.textContaining('natiijo'), findsOneWidget);
    });

    testWidgets('favorite toggled on detail appears in favorites screen', (tester) async {
      final services = await _pumpApp(tester);
      await _tap(tester, find.byType(DailyHadithCard));
      await _tap(tester, find.byTooltip('Ku dar kuwa la jecel yahay'));
      expect(services.favorites.ids, hasLength(1));
      await _systemBack(tester);
      await _tap(tester, find.byTooltip('Kuwa la jecel yahay'));
      expect(find.byType(FavoriteHadithCard), findsOneWidget);
      await _tap(tester, find.byType(FavoriteHadithCard));
      expect(find.text('Tarjumaadda'), findsOneWidget);
    });

    testWidgets('memorization → quiz → results → back to memorization', (tester) async {
      await _pumpApp(tester, initial: AppRoutes.memorization);
      await _tap(tester, find.text('Imtixaan'));
      await _tap(tester, find.text('Muuji natiijo tusaale ah'));
      expect(find.text('3 / 5'), findsOneWidget);
      await _tap(tester, find.text('Isku day mar kale'));
      expect(_appBarTitle('Imtixaan'), findsOneWidget);
      await _tap(tester, find.text('Muuji natiijo tusaale ah'));
      await _tap(tester, find.text('Ku noqo Xifdinta'));
      expect(_selectedTab(tester), 3);
    });

    testWidgets('quiz results without data shows a friendly state', (tester) async {
      await _pumpApp(tester, initial: AppRoutes.quizResults);
      expect(find.text('Natiijo lama helin'), findsOneWidget);
    });

    testWidgets('profile → settings → appearance switches theme', (tester) async {
      final services = await _pumpApp(tester, initial: AppRoutes.profile);
      await _tap(tester, find.text('Dejinta oo dhan'));
      await _tap(tester, find.text('Muuqaalka'));
      await _tap(tester, find.text('Mugdi'));
      expect(services.settings.themeMode, ThemeMode.dark);
      expect(Theme.of(tester.element(find.byType(Scaffold).last)).brightness, Brightness.dark);
    });
  });

  group('Invalid routes and parameters', () {
    final cases = {
      '/books/does-not-exist': 'Kitaabkan lama helin',
      '/books/bukhari/chapters/muslim-c1': 'Cutubkan lama helin', // chapter of another book
      '/books/bukhari/chapters/nope': 'Cutubkan lama helin',
      '/hadith/nope': 'Xadiiskan lama helin',
      '/this/route/does/not/exist': 'Boggan lama helin',
    };
    for (final MapEntry(key: path, value: message) in cases.entries) {
      testWidgets('$path shows "$message"', (tester) async {
        await _pumpApp(tester, initial: path);
        expect(find.text(message), findsOneWidget);
        await _tap(tester, find.text('Ku noqo Guriga'));
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(_selectedTab(tester), 0);
      });
    }

    testWidgets('deep-linked hadith detail offers a Home button', (tester) async {
      await _pumpApp(tester, initial: AppRoutes.hadith('bukhari-c1-h1'));
      expect(find.text('Tarjumaadda'), findsOneWidget);
      await _tap(tester, find.byTooltip('Guriga'));
      expect(_selectedTab(tester), 0);
    });
  });

  group('Android back', () {
    testWidgets('back pops inside a tab, then returns to Home tab', (tester) async {
      await _pumpApp(tester);
      await _tap(tester, _tab('Kutubta'));
      await _tap(tester, find.text('Saxiix al-Bukhaari'));
      expect(find.text('Cutubyada'), findsOneWidget);

      await _systemBack(tester);
      expect(find.text('Cutubyada'), findsNothing);
      expect(_selectedTab(tester), 1);

      await _systemBack(tester);
      expect(_selectedTab(tester), 0);
    });
  });

  group('Demo authentication', () {
    Future<AppServices> pumpWelcome(WidgetTester tester) async => _pumpApp(
      tester,
      initial: AppRoutes.welcome,
      services: await _services(status: AuthStatus.signedOut),
    );

    testWidgets('login validates, then demo sign-in reaches home', (tester) async {
      final services = await pumpWelcome(tester);
      await _tap(tester, find.text('Gal'));
      expect(find.text('Gal (demo)'), findsOneWidget);

      await _tap(tester, find.text('Gal (demo)'));
      expect(find.text('Fadlan geli email-kaaga.'), findsOneWidget);
      expect(services.auth.isSignedIn, isFalse);

      await tester.enterText(find.byType(TextFormField).at(0), 'amina@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Gal (demo)'));
      await tester.pump(AuthController.demoDelay);
      await tester.pumpAndSettle();
      expect(services.auth.isSignedIn, isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('register → verify e-mail (demo) → home', (tester) async {
      final services = await pumpWelcome(tester);
      await _tap(tester, find.text('Is diiwaangeli'));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Amina');
      await tester.enterText(fields.at(1), 'amina@example.com');
      await tester.enterText(fields.at(2), 'password123');
      await tester.enterText(fields.at(3), 'password123');
      await tester.ensureVisible(find.text('Samee akoon (demo)'));
      await tester.tap(find.text('Samee akoon (demo)'));
      await tester.pump(AuthController.demoDelay);
      await tester.pumpAndSettle();
      expect(find.text('Xaqiiji email-kaaga'), findsOneWidget);

      await _tap(tester, find.text('Waan xaqiijiyay (demo)'));
      expect(services.auth.isSignedIn, isTrue);
      expect(services.auth.displayName, 'Amina');
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('forgot → reset password (demo) → login; back works', (tester) async {
      await pumpWelcome(tester);
      await _tap(tester, find.text('Gal'));
      await _tap(tester, find.text('Ilowday furaha?'));
      expect(find.text('Dir link (demo)'), findsOneWidget);

      await _tap(tester, find.byTooltip('Dib u noqo'));
      expect(find.text('Gal (demo)'), findsOneWidget);

      await _tap(tester, find.text('Ilowday furaha?'));
      await tester.enterText(find.byType(TextFormField), 'amina@example.com');
      await tester.tap(find.text('Dir link (demo)'));
      await tester.pump(AuthController.demoDelay);
      await tester.pumpAndSettle();
      expect(find.text('Furaha cusub'), findsWidgets);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'newpassword1');
      await tester.enterText(fields.at(1), 'newpassword1');
      await tester.tap(find.text('Keydi furaha (demo)'));
      await tester.pump(AuthController.demoDelay);
      await tester.pumpAndSettle();
      expect(find.text('Gal (demo)'), findsOneWidget);
    });

    testWidgets('sign out from profile returns to welcome', (tester) async {
      final services = await _pumpApp(tester, initial: AppRoutes.profile);
      await _tap(tester, find.text('Ka bax'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Ka bax'));
      expect(services.auth.status, AuthStatus.signedOut);
      expect(find.text('Ku sii wad marti ahaan'), findsOneWidget);
    });
  });
}
