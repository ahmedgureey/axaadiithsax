import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/services/share_service.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/widgets/widgets.dart';
import 'package:xadiithapp/data/models/hadith.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';
import 'package:xadiithapp/features/home/presentation/widgets/home_search_shortcut.dart';
import 'package:xadiithapp/features/home/presentation/widgets/recent_hadiths_section.dart';

import '../../support/test_library.dart';

/// Fails the first [failures] times the home feed asks for the daily hadith.
class _FlakyRepository extends HadithRepository {
  _FlakyRepository(this.failures) : super(chapters: TestLibrary.chapters, hadiths: TestLibrary.hadiths);
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

class _RecordingShare implements ShareService {
  final shared = <String>[];
  @override
  Future<ShareOutcome> shareText(String text, {String? subject}) async {
    shared.add(text);
    return ShareOutcome.shared;
  }
}

Future<AppServices> _pumpHome(
  WidgetTester tester, {
  HadithRepository? repository,
  ShareService? share,
  Size size = const Size(390, 844),
  String theme = 'light',
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final services = await createTestServices(
    InMemorySettingsStore({'auth.onboardingSeen': true, 'settings.themeMode': theme}),
    repository: repository,
    share: share,
  );
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: AppRoutes.home));
  await tester.pumpAndSettle();
  return services;
}

Finder get _homeList => find.byType(Scrollable).first;

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
      for (final title in ['Si Degdeg ah u Gal', 'Kutubta Xadiithka']) {
        expect(find.text(title), findsNothing, reason: 'removed from Home');
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
    });
  });

  group('App bar', () {
    testWidgets('everyone is greeted the same way (no accounts)', (tester) async {
      await _pumpHome(tester);
      expect(find.text('Ku soo dhowow Xadiith App'), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Cusboonaysii')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Aniga')), findsNothing);
    });

    testWidgets('notifications opens an honest empty state', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byTooltip('Ogeysiisyada'));
      await tester.pumpAndSettle();
      expect(find.text('Ogeysiis ma jiro'), findsOneWidget);
    });

    testWidgets('refresh button reloads home and confirms', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Cusboonaysii')));
      await tester.pumpAndSettle();
      expect(find.text('Waa la cusboonaysiiyay'), findsOneWidget);
      expect(_tab(tester), 0, reason: 'stays on Guriga');
    });

    testWidgets('daily hadith card has Arabic text-size controls', (tester) async {
      final s = await _pumpHome(tester);
      final before = s.settings.arabicFontSize;
      await tester.tap(find.byTooltip('Weyneey qoraalka Carabiga').first);
      await tester.pumpAndSettle();
      expect(s.settings.arabicFontSize, before + 2);
      await tester.tap(find.byTooltip('Yaree qoraalka Carabiga').first);
      await tester.pumpAndSettle();
      expect(s.settings.arabicFontSize, before);
      expect(find.byTooltip('Dib u deji cabbirka'), findsNothing, reason: 'compact control on the card');
    });
  });

  group('Daily hadith', () {
    testWidgets('"Akhri Xadiiska" opens the detail of a valid hadith', (tester) async {
      final services = await _pumpHome(tester);
      final daily = services.repository.dailyHadith(DateTime.now())!;
      await _tap(tester, find.text('Akhri Xadiiska'));
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
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
        find.descendant(of: find.byType(DailyHadithCard), matching: find.byTooltip('Ka saar kuwa la jecel yahay')),
        findsOneWidget,
      );
    });

    testWidgets('share opens the system share sheet with the hadith text', (tester) async {
      final share = _RecordingShare();
      final services = await _pumpHome(tester, share: share);
      final daily = services.repository.dailyHadith(DateTime.now())!;
      await _tap(tester, find.descendant(of: find.byType(DailyHadithCard), matching: find.byTooltip('La wadaag')));
      expect(share.shared.single, contains(daily.arabicText));
      expect(share.shared.single, contains('Xog tusaale ah'));
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
      await _tap(tester, find.text('Dhammaan'));
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
      for (final text in ['Xadiiska maalinta lama heli karo', 'Xadiis lama helin.']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Mowduucyada'), findsNothing, reason: 'topics section removed from Home');
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
