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
  return AppServices.create(InMemorySettingsStore({'auth.onboardingSeen': onboarded, 'auth.status': status.name}));
}

Future<AppServices> _pumpApp(WidgetTester tester, {String initial = AppRoutes.home, AppServices? services}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final s = services ?? await _services();
  await tester.pumpWidget(XadiisApp(services: s, initialLocation: initial));
  await tester.pumpAndSettle();
  return s;
}

Finder _tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

int _selectedTab(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

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
      expect(find.text('Baro Axaadiista Nabiga ﷺ'), findsOneWidget);

      await _tap(tester, find.text('Ka gudub'));
      expect(services.auth.onboardingSeen, isTrue);
      expect(find.text('Sii wad adigoon gelin'), findsOneWidget);

      await _tap(tester, find.text('Sii wad adigoon gelin'));
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
      expect(find.text('Sii wad adigoon gelin'), findsOneWidget);
    });
  });

  group('Five tabs', () {
    testWidgets('all five tabs are reachable and highlighted', (tester) async {
      await _pumpApp(tester);
      const titles = ['Assalaamu Calaykum', 'Kutubta Xadiiska', 'Raadi Xadiis', 'Xifdintayda', 'Aniga'];
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
      expect(_appBarTitle('Kutubta Xadiiska'), findsOneWidget);
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
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing, reason: 'focused reading screen');
      // Arabic content is RTL inside the LTR screen.
      final arabic = tester.element(find.descendant(of: find.byType(ArabicText).first, matching: find.byType(Text)));
      expect(Directionality.of(arabic), TextDirection.rtl);

      await _tap(tester, find.byType(BackButton));
      expect(_appBarTitle('Cutub tusaale 2'), findsOneWidget);
      expect(_selectedTab(tester), 1);
    });

    testWidgets('daily hadith opens detail and records history', (tester) async {
      final services = await _pumpApp(tester);
      await _tap(tester, find.byType(DailyHadithCard));
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
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
      await tester.scrollUntilVisible(
        find.text('Xadiisyada aan Kaydiyey'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, find.text('Xadiisyada aan Kaydiyey'));
      expect(find.byType(FavoriteHadithCard), findsOneWidget);
      await _tap(tester, find.byType(FavoriteHadithCard));
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
    });

    testWidgets('memorization → quiz → results → back to memorization', (tester) async {
      await _pumpApp(tester, initial: AppRoutes.memorization);
      await tester.scrollUntilVisible(find.text('Imtixaan'), 300, scrollable: find.byType(Scrollable).first);
      await _tap(tester, find.text('Imtixaan'));
      expect(_appBarTitle('Imtixaanka Xadiiska'), findsOneWidget);
      await _tap(tester, find.text('Bilow imtixaanka'));
      // Answer every question with the first option, then finish.
      for (var i = 1; i <= 5; i++) {
        expect(_appBarTitle("Su'aal $i / 5"), findsOneWidget);
        await _tap(tester, find.text('A').first);
        await _tap(tester, find.text(i == 5 ? 'Arag natiijada' : "Su'aasha xigta"));
      }
      expect(_appBarTitle('Natiijada'), findsOneWidget);
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
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
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
}
