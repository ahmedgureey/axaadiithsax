import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/widgets/widgets.dart';
import 'package:xadiithapp/data/models/hadith.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';
import 'package:xadiithapp/features/auth/auth_controller.dart';
import 'package:xadiithapp/features/home/presentation/widgets/featured_books_section.dart';
import 'package:xadiithapp/features/home/presentation/widgets/home_search_shortcut.dart';
import 'package:xadiithapp/features/home/presentation/widgets/recent_hadiths_section.dart';

/// Fails the first [failures] times the home feed asks for the daily hadith.
class _FlakyRepository extends HadithRepository {
  _FlakyRepository(this.failures);
  int failures;

  @override
  Hadith? dailyHadith(DateTime date) {
    if (failures > 0) {
      failures--;
      throw StateError('corrupt dataset');
    }
    return super.dailyHadith(date);
  }
}

Future<AppServices> _pumpHome(
  WidgetTester tester, {
  AuthStatus status = AuthStatus.guest,
  HadithRepository? repository,
  Size size = const Size(390, 844),
  String theme = 'light',
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final services = await AppServices.create(
    InMemorySettingsStore({
      'auth.onboardingSeen': true,
      'auth.status': status.name,
      'auth.displayName': ?(status == AuthStatus.signedIn ? AuthController.demoName : null),
      'settings.themeMode': theme,
    }),
    repository: repository,
  );
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: AppRoutes.home));
  await tester.pumpAndSettle();
  return services;
}

Finder get _homeList => find.byType(Scrollable).first;
Finder get _booksRow => find.descendant(
  of: find.byType(FeaturedBooksSection),
  matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right),
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: _homeList);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

int _tab(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  group('Layout', () {
    testWidgets('shows all sections inside the single app shell', (tester) async {
      await _pumpHome(tester);
      expect(find.text('Assalaamu Calaykum'), findsOneWidget);
      expect(find.text(HomeSearchShortcut.hint), findsOneWidget);
      expect(find.text('XADIISKA MAALINTA'), findsOneWidget);
      for (final title in ['Si Degdeg ah u Gal', 'Kutubta Caanka ah', 'Mowduucyada']) {
        await _scrollTo(tester, find.text(title));
        expect(find.text(title), findsOneWidget);
      }
      await _scrollTo(tester, find.text(RecentHadithsSection.featuredTitle));
      expect(find.byType(NavigationBar), findsOneWidget, reason: 'no duplicate bottom navigation');
      expect(_tab(tester), 0);
    });

    testWidgets('daily hadith Arabic is RTL; demo content is labelled', (tester) async {
      await _pumpHome(tester);
      final card = find.byType(DailyHadithCard);
      final arabicText = find.descendant(
        of: find.descendant(of: card, matching: find.byType(ArabicText)).last,
        matching: find.byType(Text),
      );
      expect(Directionality.of(tester.element(arabicText)), TextDirection.rtl);
      expect(find.descendant(of: card, matching: find.byType(DemoContentBadge)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('(tusaale)')), findsOneWidget);
      expect(find.text('Tarjumaadda Af Soomaaliga:'), findsOneWidget);
    });
  });

  group('App bar', () {
    testWidgets('guest is greeted generically', (tester) async {
      await _pumpHome(tester);
      expect(find.text('Ku soo dhowow Xadiith App'), findsOneWidget);
      expect(find.byTooltip('Aniga (marti)'), findsOneWidget);
    });

    testWidgets('signed-in demo user is greeted by name', (tester) async {
      await _pumpHome(tester, status: AuthStatus.signedIn);
      expect(find.text('Ku soo dhowow, ${AuthController.demoName}'), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Aniga')), findsOneWidget);
    });

    testWidgets('notifications opens an honest empty state', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byTooltip('Ogeysiisyada'));
      await tester.pumpAndSettle();
      expect(find.text('Ogeysiis ma jiro'), findsOneWidget);
    });

    testWidgets('profile shortcut opens the Aniga tab', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byTooltip('Aniga (marti)'));
      await tester.pumpAndSettle();
      expect(_tab(tester), 4);
    });
  });

  group('Daily hadith', () {
    testWidgets('"Akhri Xadiiska" opens the detail of a valid hadith', (tester) async {
      final services = await _pumpHome(tester);
      final daily = services.repository.dailyHadith(DateTime.now())!;
      await _tap(tester, find.text('Akhri Xadiiska'));
      expect(find.text('Tarjumaadda'), findsOneWidget);
      expect(services.history.recentIds.first, daily.id);
    });

    testWidgets('bookmark uses the shared favorites state', (tester) async {
      final services = await _pumpHome(tester);
      final daily = services.repository.dailyHadith(DateTime.now())!;
      final bookmark = find.descendant(
        of: find.byType(DailyHadithCard),
        matching: find.byTooltip('Ku dar kuwa la jecel yahay'),
      );
      await _tap(tester, bookmark);
      expect(services.favorites.isFavorite(daily.id), isTrue);
      expect(find.text('Waa la keydiyay'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DailyHadithCard),
          matching: find.byTooltip('Ka saar kuwa la jecel yahay'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('share copies the text (no share plugin yet)', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final services = await _pumpHome(tester);
      final daily = services.repository.dailyHadith(DateTime.now())!;
      await _tap(
        tester,
        find.descendant(of: find.byType(DailyHadithCard), matching: find.byTooltip('La wadaag')),
      );
      expect(copied, contains(daily.somaliText));
      expect(find.textContaining('waa la koobiyeeyay'), findsOneWidget);
    });
  });

  group('Navigation from sections', () {
    testWidgets('search shortcut opens the Search tab', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.text(HomeSearchShortcut.hint));
      await tester.pumpAndSettle();
      expect(_tab(tester), 2);
      expect(find.byType(AppSearchField), findsOneWidget);
    });

    testWidgets('featured book opens its detail in the Kutubta tab', (tester) async {
      await _pumpHome(tester);
      await _scrollTo(tester, find.text('Kutubta Caanka ah'));
      final muslim = find.descendant(
        of: find.byType(FeaturedBooksSection),
        matching: find.text('Saxiix Muslim'),
      );
      await tester.scrollUntilVisible(muslim, 200, scrollable: _booksRow);
      await tester.tap(muslim);
      await tester.pumpAndSettle();
      expect(_tab(tester), 1);
      expect(find.text('Cutubyada'), findsOneWidget);
    });

    testWidgets('book without content is labelled and opens a clear empty state', (tester) async {
      await _pumpHome(tester);
      await _scrollTo(tester, find.text('Kutubta Caanka ah'));
      await tester.scrollUntilVisible(find.text('Sunan Abi Daawuud'), 200, scrollable: _booksRow);
      await tester.pumpAndSettle();
      expect(find.text('Weli lama darin'), findsWidgets);
      await tester.tap(find.text('Sunan Abi Daawuud'));
      await tester.pumpAndSettle();
      expect(find.text('Cutub lama helin'), findsOneWidget);
    });

    testWidgets('topic opens Search filtered by that category', (tester) async {
      await _pumpHome(tester);
      await _tap(tester, find.text('Dulqaadka'));
      expect(_tab(tester), 2);
      expect(find.textContaining('natiijo'), findsOneWidget);
    });

    final quickActions = {'Raadso Xadiis': 2, 'Qorshaha Xifdinta': 3};
    for (final MapEntry(key: label, value: tab) in quickActions.entries) {
      testWidgets('quick action "$label" opens tab $tab', (tester) async {
        await _pumpHome(tester);
        await _tap(tester, find.text(label));
        expect(_tab(tester), tab);
      });
    }

    testWidgets('quick actions open favorites and quiz screens', (tester) async {
      await _pumpHome(tester);
      await _tap(tester, find.text('Xadiisyada aan Kaydiyey'));
      expect(find.text('Weli wax ma keydsan'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Imtixaanka Xadiiska'));
      expect(find.text('Imtixaanka xifdinta'), findsOneWidget);
    });

    testWidgets('recent section switches from featured to real history', (tester) async {
      await _pumpHome(tester);
      await _scrollTo(tester, find.text(RecentHadithsSection.featuredTitle));
      expect(find.text(RecentHadithsSection.recentTitle), findsNothing);

      await tester.tap(find.byType(HadithCard).first);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text(RecentHadithsSection.recentTitle));
      expect(find.text(RecentHadithsSection.featuredTitle), findsNothing);
      await _tap(tester, find.text('Eeg Dhammaan'));
      expect(_tab(tester), 1);
    });
  });

  group('Empty and error states', () {
    testWidgets('empty dataset shows friendly empty states', (tester) async {
      // Tall viewport so the whole (short) lazy list is built at once.
      await _pumpHome(
        tester,
        size: const Size(390, 1800),
        repository: HadithRepository(books: [], chapters: [], hadiths: [], categories: []),
      );
      for (final text in [
        'Xadiiska maalinta lama heli karo',
        'Kutub lama helin.',
        'Mowduuc lama helin.',
        'Xadiis lama helin.',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('data error shows retry instead of a raw exception', (tester) async {
      await _pumpHome(tester, repository: _FlakyRepository(1));
      expect(find.text('Xogta lama soo rari karin'), findsOneWidget);
      expect(find.textContaining('corrupt'), findsNothing);
      await tester.tap(find.text('Isku day mar kale'));
      await tester.pumpAndSettle();
      expect(find.text('XADIISKA MAALINTA'), findsOneWidget);
    });
  });

  group('Responsive', () {
    final cases = {
      'small phone, dark, 1.5× text': (const Size(320, 568), 'dark', 1.5),
      'phone, light, 1.0×': (const Size(390, 844), 'light', 1.0),
      'tablet landscape, light, 1.3×': (const Size(1024, 768), 'light', 1.3),
    };
    for (final MapEntry(key: name, value: (size, theme, scale)) in cases.entries) {
      testWidgets('no overflow: $name', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pumpHome(tester, size: size, theme: theme);
        // Scroll the horizontal books row to its end while it is built…
        await _scrollTo(tester, find.text('Kutubta Caanka ah'));
        await tester.drag(_booksRow, const Offset(-2000, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // …then the whole page.
        for (var i = 0; i < 12; i++) {
          await tester.drag(_homeList, const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
