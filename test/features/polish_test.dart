import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/l10n/app_strings.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/theme/app_typography.dart';
import 'package:xadiithapp/data/models/hadith.dart';
import 'package:xadiithapp/features/hadith/reading_history_controller.dart';
import 'package:xadiithapp/features/settings/notification_preferences_controller.dart';

import '../support/test_library.dart';

/// Prompt 12: persisted reading history, Home progress cards, reader
/// translation controls and position, and interface localisation.

InMemorySettingsStore _store({String theme = 'light', String? language, List<String>? history}) =>
    InMemorySettingsStore({
      'auth.onboardingSeen': true,
      'settings.themeMode': theme,
      'settings.language': ?language,
      'reading.history': ?history,
    });

Future<AppServices> _pump(
  WidgetTester tester,
  String route, {
  InMemorySettingsStore? store,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final services = await createTestServices(store ?? _store(), clock: () => DateTime(2026, 11, 18, 10));
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: route));
  await tester.pumpAndSettle();
  return services;
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// A record in the middle of a book (has both neighbours) with a translation.
Future<Hadith> _middleHadith() async {
  final s = await createTestServices(InMemorySettingsStore());
  final order = s.repository.readingOrderOf('bukhari');
  return order.skip(1).firstWhere((h) => h.hasTranslation && h != order.last);
}

void main() {
  group('Reading history persistence', () {
    test('records persist, reload, drop missing ids and clear storage', () async {
      final store = InMemorySettingsStore();
      final c = ReadingHistoryController(store);
      c
        ..record('a')
        ..record('b')
        ..record('a');
      await Future<void>.delayed(Duration.zero);
      expect(c.recentIds, ['a', 'b']);
      expect(await store.getStringList(ReadingHistoryController.storageKey), ['a', 'b']);

      final reloaded = ReadingHistoryController(store);
      await reloaded.load();
      expect(reloaded.lastId, 'a');
      reloaded.removeMissing((id) => id == 'b');
      expect(reloaded.recentIds, ['b']);

      reloaded.clear();
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.lastId, isNull);
      expect(await store.getStringList(ReadingHistoryController.storageKey), isNull);
    });

    test('AppServices drops ids that are not in the dataset', () async {
      final s = await createTestServices(_store(history: ['does-not-exist']));
      expect(s.history.recentIds, isEmpty);
    });

    test('reset all local data clears reading history', () async {
      final h = await _middleHadith();
      final store = _store(history: [h.id]);
      final s = await createTestServices(store);
      expect(s.history.lastId, h.id);
      await s.resetAllLocalData();
      await Future<void>.delayed(Duration.zero);
      expect(await store.getStringList(ReadingHistoryController.storageKey), isNull);
    });
  });

  group('Home progress cards', () {
    testWidgets('continue reading is hidden until something was read, then opens it', (tester) async {
      expect(find.text('Sii wad akhriska'), findsNothing);
      final h = await _middleHadith();
      await _pump(tester, AppRoutes.home, store: _store(history: [h.id]));
      await _scrollTo(tester, find.text('Sii wad akhriska'));
      expect(find.textContaining('#${h.number}'), findsWidgets);
      await tester.tap(find.text('Sii wad akhriska'));
      await tester.pumpAndSettle();
      expect(find.text(h.arabicText), findsOneWidget);
    });

    testWidgets('no history → no continue card', (tester) async {
      await _pump(tester, AppRoutes.home);
      expect(find.text('Sii wad akhriska'), findsNothing);
    });

    testWidgets('memorization summary uses real numbers; reminder is honest', (tester) async {
      final s = await _pump(tester, AppRoutes.home);
      await _scrollTo(tester, find.text('Horumarka xifdinta'));
      expect(find.text('0 / ${s.memorization.plannedToday} xadiis la xifdiyay'), findsOneWidget);
      await _scrollTo(tester, find.text('Xasuusinta akhriska'));
      expect(find.textContaining('Dansan'), findsOneWidget);

      await s.notifications.setEnabled(ReminderKind.dailyHadith, true);
      await tester.pumpAndSettle();
      expect(find.text('Doorbid: maalin kasta 08:00 · weli lama diro'), findsOneWidget);
      await tester.tap(find.text('Xasuusinta akhriska'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Ogeysiisyada'), findsOneWidget);
    });
  });

  group('Reader', () {
    testWidgets('translation can be hidden and shown; choice persists', (tester) async {
      final h = await _middleHadith();
      final store = _store();
      final s = await _pump(tester, AppRoutes.hadith(h.id), store: store);
      expect(find.text(h.somaliText!), findsOneWidget);
      await _scrollTo(tester, find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(s.settings.showTranslation, isFalse);
      expect(find.text(h.somaliText!), findsNothing);
      expect(find.text('Tarjumaadda waa la qariyay.'), findsOneWidget);
      expect(await store.getBool('settings.showTranslation'), isFalse);
      // Arabic source text is untouched.
      expect(find.text(h.arabicText), findsOneWidget);
    });

    testWidgets('reading settings sheet changes translation size in the reader', (tester) async {
      final h = await _middleHadith();
      final s = await _pump(tester, AppRoutes.hadith(h.id));
      double translationSize() => tester
          .widget<SelectableText>(find.ancestor(of: find.text(h.somaliText!), matching: find.byType(SelectableText)))
          .style!
          .fontSize!;
      final before = translationSize();
      await tester.tap(find.byTooltip('Dejinta akhriska'));
      await tester.pumpAndSettle();
      expect(find.text('Muuji tarjumaadda'), findsOneWidget);
      await tester.tap(find.byTooltip('Kordhi: Cabbirka tarjumaadda'));
      await tester.pumpAndSettle();
      expect(s.settings.translationScale, greaterThan(TranslationScale.defaultValue));
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(translationSize(), greaterThan(before));
    });

    testWidgets('position indicator shows place in the book', (tester) async {
      final h = await _middleHadith();
      final s = await _pump(tester, AppRoutes.hadith(h.id));
      final order = s.repository.readingOrderOf(h.bookId);
      final pos = order.indexWhere((x) => x.id == h.id) + 1;
      expect(find.text('$pos / ${order.length}'), findsOneWidget);
    });

    testWidgets('Arabic interface: RTL reader with translated controls; next still moves forward', (tester) async {
      final h = await _middleHadith();
      final s = await _pump(tester, AppRoutes.hadith(h.id), store: _store(language: 'ar'));
      expect(find.text('الراوي'), findsOneWidget);
      expect(find.text('الحديث التالي'), findsOneWidget);
      final nextButton = find.text('الحديث التالي');
      expect(Directionality.of(tester.element(nextButton)), TextDirection.rtl);
      // In RTL "next" sits on the left of "previous".
      expect(tester.getCenter(nextButton).dx, lessThan(tester.getCenter(find.text('الحديث السابق')).dx));
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
      final expected = s.repository.neighboursOf(h).next!;
      expect(find.text(expected.arabicText), findsOneWidget);
    });
  });

  group('Interface localisation', () {
    test('every key is translated in every language', () {
      for (final lang in AppLanguage.values) {
        expect(AppStrings.translatedCount(lang), AppStrings.totalKeys, reason: lang.name);
      }
    });

    testWidgets('English: settings, profile and home use translated labels', (tester) async {
      await _pump(tester, AppRoutes.settings, store: _store(language: 'en'));
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, AppRoutes.home, store: _store(language: 'en'));
      expect(find.text('Assalamu alaikum'), findsOneWidget);
      expect(find.text('HADITH OF THE DAY'), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('switching language updates labels immediately', (tester) async {
      final s = await _pump(tester, AppRoutes.profile);
      expect(find.widgetWithText(AppBar, 'Aniga'), findsOneWidget);
      await s.settings.setLanguage(AppLanguage.arabic);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'حسابي'), findsOneWidget);
    });
  });

  group('Layout and accessibility of new UI', () {
    for (final theme in ['light', 'dark']) {
      testWidgets('home with history ($theme): guidelines + no overflow at 320×568, 1.5×', (tester) async {
        final handle = tester.ensureSemantics();
        final h = await _middleHadith();
        await _pump(
          tester,
          AppRoutes.home,
          store: _store(theme: theme, history: [h.id]),
          size: const Size(320, 568),
          textScale: 1.5,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('reader settings sheet: no overflow on a small screen with large text', (tester) async {
      final h = await _middleHadith();
      await _pump(
        tester,
        AppRoutes.hadith(h.id),
        store: _store(theme: 'dark', language: 'ar'),
        size: const Size(320, 568),
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('إعدادات القراءة'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
