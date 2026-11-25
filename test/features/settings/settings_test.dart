import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/app_info.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/theme/app_typography.dart';
import 'package:xadiithapp/features/about/presentation/about_screen.dart';
import 'package:xadiithapp/features/favorites/favorites_controller.dart';
import 'package:xadiithapp/features/memorization/memorization_controller.dart';
import 'package:xadiithapp/features/settings/notification_preferences_controller.dart';
import 'package:xadiithapp/features/settings/presentation/help_screen.dart';
import 'package:xadiithapp/features/settings/presentation/notification_settings_screen.dart';

import '../../support/test_library.dart';

InMemorySettingsStore _guestStore({String theme = 'light'}) =>
    InMemorySettingsStore({'auth.onboardingSeen': true, 'settings.themeMode': theme});

InMemorySettingsStore _signedInStore({String theme = 'light'}) => InMemorySettingsStore({
  'auth.onboardingSeen': true,
  'auth.status': 'signedIn',
  'auth.displayName': 'Cali',
  'auth.email': 'demo@xadiis.app',
  'settings.themeMode': theme,
});

Future<AppServices> _pump(
  WidgetTester tester,
  String initial, {
  InMemorySettingsStore? store,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final services = await createTestServices(store ?? _guestStore(), clock: () => DateTime(2026, 11, 18, 10));
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: initial));
  await tester.pumpAndSettle();
  return services;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('Settings controller (reading + language)', () {
    test('language, translation scale and line height persist and reload', () async {
      final store = InMemorySettingsStore();
      final c = AppSettingsController(store);
      await c.setLanguage(AppLanguage.arabic);
      await c.setTranslationScale(1.2);
      await c.setArabicLineHeight(2.4);
      final reloaded = AppSettingsController(store);
      await reloaded.load();
      expect(reloaded.language, AppLanguage.arabic);
      expect(reloaded.translationScale, closeTo(1.2, 0.001));
      expect(reloaded.arabicLineHeight, closeTo(2.4, 0.001));
    });

    test('values are clamped to safe bounds; corrupted values fall back', () async {
      final c = AppSettingsController(InMemorySettingsStore());
      await c.setTranslationScale(5);
      await c.setArabicLineHeight(0.1);
      expect(c.translationScale, TranslationScale.max);
      expect(c.arabicLineHeight, ArabicLineHeight.min);

      final bad = AppSettingsController(
        InMemorySettingsStore({'settings.language': 'xx', 'settings.translationScale': 99.0}),
      );
      await bad.load();
      expect(bad.language, AppLanguage.somali);
      expect(bad.translationScale, TranslationScale.max);
    });

    test('resetReading removes only reading keys; resetAppearanceAndReading also theme + language', () async {
      final store = InMemorySettingsStore();
      final c = AppSettingsController(store);
      await c.setThemeMode(ThemeMode.dark);
      await c.setLanguage(AppLanguage.english);
      await c.setTranslationScale(1.3);
      expect(c.readingIsDefault, isFalse);
      await c.resetReading();
      expect(c.readingIsDefault, isTrue);
      expect(await store.getDouble('settings.translationScale'), isNull);
      expect(c.themeMode, ThemeMode.dark);
      await c.resetAppearanceAndReading();
      expect(c.themeMode, ThemeMode.system);
      expect(c.language, AppLanguage.somali);
      expect(await store.getString('settings.language'), isNull);
    });
  });

  group('Notification preferences', () {
    test('toggles and time persist; nothing enabled by default', () async {
      final store = InMemorySettingsStore();
      final c = NotificationPreferencesController(store);
      await c.load();
      expect(c.enabledCount, 0);
      expect(c.reminderTime, const TimeOfDay(hour: 8, minute: 0));
      await c.setEnabled(ReminderKind.review, true);
      await c.setReminderTime(const TimeOfDay(hour: 21, minute: 5));
      final reloaded = NotificationPreferencesController(store);
      await reloaded.load();
      expect(reloaded.isEnabled(ReminderKind.review), isTrue);
      expect(reloaded.isEnabled(ReminderKind.dailyHadith), isFalse);
      expect(NotificationPreferencesController.formatTime(reloaded.reminderTime), '21:05');
    });

    test('corrupted time falls back; reset clears storage', () async {
      final store = InMemorySettingsStore({'notifications.time': '99:xx', 'notifications.memorization': true});
      final c = NotificationPreferencesController(store);
      await c.load();
      expect(c.reminderTime, const TimeOfDay(hour: 8, minute: 0));
      expect(NotificationPreferencesController.parseTime('7:3'), isNull);
      await c.reset();
      expect(c.enabledCount, 0);
      expect(await store.getBool('notifications.memorization'), isNull);
      expect(await store.getString('notifications.time'), isNull);
    });
  });

  group('App info', () {
    test('version shown in the app matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
      expect(match, isNotNull);
      expect(AppInfo.pubspecVersion, match!.group(1));
    });
  });

  group('Reset all local data', () {
    test('really deletes every stored key group', () async {
      final store = _signedInStore(theme: 'dark');
      final s = await createTestServices(store, clock: () => DateTime(2026, 11, 18, 10));
      final id = s.repository.dailyHadith(DateTime(2026, 11, 18))!.id;
      await s.favorites.add(id);
      await s.memorization.markMemorized(id);
      await s.searchHistory.add('salaad');
      await s.notifications.setEnabled(ReminderKind.dailyHadith, true);
      await s.settings.setTranslationScale(1.2);
      expect(await store.getStringList(FavoritesController.storageKey), isNotEmpty);

      await s.resetAllLocalData();

      expect(await store.getStringList(FavoritesController.storageKey), isNull);
      expect(await store.getString(MemorizationController.storageKey), isNull);
      expect(await store.getStringList('search.history'), isNull);
      expect(await store.getBool('notifications.dailyHadith'), isNull);
      expect(await store.getDouble('settings.translationScale'), isNull);
      expect(await store.getString('settings.themeMode'), isNull);
      expect(await store.getString('auth.status'), isNull);
      expect(await store.getString('auth.displayName'), isNull);
      expect(s.favorites.count, 0);
      expect(s.memorization.memorizedCount, 0);
      expect(s.searchHistory.terms, isEmpty);
      expect(s.onboarding.onboardingSeen, isFalse);
    });
  });

  group('Profile screen', () {
    testWidgets('no notice card, no privacy; renamed reading items; stats and links', (tester) async {
      await _pump(tester, AppRoutes.profile);
      expect(find.textContaining('Akoon looma baahna'), findsNothing);
      expect(find.text('Arrimaha gaarka ah'), findsNothing);
      expect(_statSemantics('La keydiyay: 0'), findsOneWidget);
      expect(find.text('Xadiisyada kaydsan'), findsOneWidget);
      expect(find.text('Habka akhriska'), findsNothing);
      expect(find.text('Horumarka xifdinta'), findsOneWidget);
      expect(find.text('Imtixaan'), findsWidgets);
      await tester.scrollUntilVisible(find.text(HelpScreen.title), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Dejinta'), findsOneWidget);
      expect(find.text('Ogeysiisyada'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Xadiith App · Nooca ${AppInfo.version}'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('La wadaag app-ka'), findsOneWidget);
    });

    testWidgets('stats reflect real favourites', (tester) async {
      final s = await _pump(tester, AppRoutes.profile);
      await s.favorites.add(s.repository.dailyHadith(DateTime(2026, 11, 18))!.id);
      await tester.pumpAndSettle();
      expect(_statSemantics('La keydiyay: 1'), findsOneWidget);
    });

    testWidgets('profile → illustrated user guide: pages, skip, WhatsApp on the last page', (tester) async {
      await _pump(tester, AppRoutes.profile);
      await _tap(tester, find.text(HelpScreen.title));
      expect(find.text('HAGAHA ISTICMAALKA  1 / ${HelpScreen.pages.length}'), findsOneWidget);
      expect(find.text(HelpScreen.pages.first.$1), findsOneWidget);
      for (var i = 1; i < HelpScreen.pages.length; i++) {
        await _tap(tester, find.text('Xiga'));
        expect(find.text(HelpScreen.pages[i].$1), findsOneWidget);
      }
      expect(find.textContaining(HelpScreen.whatsAppDisplay), findsOneWidget);
      expect(HelpScreen.whatsAppUri.toString(), 'https://wa.me/252612341376');
      await _tap(tester, find.text('Dhammee'));
      expect(find.text(HelpScreen.pages.first.$1), findsNothing, reason: 'guide closed');
    });
  });

  group('Settings screens', () {
    testWidgets('theme selection applies and persists', (tester) async {
      final store = _guestStore();
      final s = await _pump(tester, AppRoutes.settings, store: store);
      await tester.tap(find.text('Mugdi'));
      await tester.pumpAndSettle();
      expect(s.settings.themeMode, ThemeMode.dark);
      expect(Theme.of(tester.element(find.text('Mugdi'))).brightness, Brightness.dark);
      final reloaded = AppSettingsController(store);
      await reloaded.load();
      expect(reloaded.themeMode, ThemeMode.dark);
    });

    testWidgets('language: Arabic switches nav labels and direction, honest partial notice', (tester) async {
      final s = await _pump(tester, AppRoutes.settingsLanguage);
      expect(find.text('La doortay'), findsOneWidget);
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(s.settings.language, AppLanguage.arabic);
      expect(find.textContaining('qayb ahaan'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('العربية'))), TextDirection.rtl);

      s.settings.setLanguage(AppLanguage.english);
      await tester.pumpAndSettle();
      expect(Directionality.of(tester.element(find.text('English'))), TextDirection.ltr);
    });

    testWidgets('Arabic nav labels appear in the shell', (tester) async {
      final store = _guestStore()..setString('settings.language', 'ar');
      await _pump(tester, AppRoutes.home, store: store);
      expect(find.text('الرئيسية'), findsWidgets);
      expect(find.text('Guriga'), findsNothing);
    });

    testWidgets('reading preferences: steppers respect bounds and reset', (tester) async {
      final s = await _pump(tester, AppRoutes.settingsReading);
      final plus = find.byTooltip('Kordhi: Cabbirka tarjumaadda');
      for (var i = 0; i < 8; i++) {
        if (tester.widget<IconButton>(find.ancestor(of: plus, matching: find.byType(IconButton))).onPressed == null) {
          break;
        }
        await tester.tap(plus);
        await tester.pumpAndSettle();
      }
      expect(s.settings.translationScale, TranslationScale.max);
      expect(find.text('140%'), findsOneWidget);
      await _tap(tester, find.text('Ku celi qiyamka asalka ah'));
      expect(s.settings.translationScale, TranslationScale.defaultValue);
      expect(s.settings.readingIsDefault, isTrue);
    });

    testWidgets('notifications: two reminders with their own time (no daily-hadith notification)', (tester) async {
      final store = _guestStore();
      final s = await _pump(tester, AppRoutes.settingsNotifications, store: store);
      expect(find.text(NotificationSettingsScreen.unsupportedNotice), findsOneWidget, reason: 'tests use no device');
      for (final k in ReminderKind.offered) {
        expect(find.text(k.label), findsOneWidget);
      }
      expect(find.text(ReminderKind.dailyHadith.label), findsNothing);
      expect(find.text('08:00'), findsNothing);
      expect(find.text('19:00'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
      await tester.tap(find.text(ReminderKind.memorization.label));
      await tester.pumpAndSettle();
      expect(s.notifications.isEnabled(ReminderKind.memorization), isTrue);
      expect(await store.getBool('notifications.memorization'), isTrue);
    });

    testWidgets('about shows the real version and what the app offers (no warning, no library list)', (tester) async {
      await _pump(tester, AppRoutes.about);
      expect(find.text(AboutScreen.versionLabel), findsOneWidget);
      expect(find.text('Nooca 1.0.16 (build 17)'), findsOneWidget);
      expect(find.textContaining('xadiisyo la xaqiijiyey'), findsNothing);
      expect(find.text('Waxyaabaha la isticmaalay'), findsNothing);
      expect(find.text('42 xadiis'), findsOneWidget);
      expect(find.text("Internet la'aan"), findsOneWidget);
      expect(find.textContaining('(demo)'), findsNothing);
    });
  });

  group('Reset actions need confirmation', () {
    testWidgets('cancel keeps data; confirm deletes it', (tester) async {
      final store = _guestStore();
      final s = await _pump(tester, AppRoutes.settings, store: store);
      await s.favorites.add(s.repository.dailyHadith(DateTime(2026, 11, 18))!.id);

      await _tap(tester, find.text('Tirtir dhammaan xogta qalabka'));
      expect(find.text('Tirtir dhammaan xogta?'), findsOneWidget);
      await tester.tap(find.text('Jooji'));
      await tester.pumpAndSettle();
      expect(s.favorites.count, 1);

      await _tap(tester, find.text('Tirtir dhammaan xogta qalabka'));
      await tester.tap(find.text('Tirtir'));
      await tester.pumpAndSettle();
      expect(s.favorites.count, 0);
      expect(await store.getStringList(FavoritesController.storageKey), isNull);
      expect(s.onboarding.onboardingSeen, isFalse);
    });

    testWidgets('notification reset only touches notifications', (tester) async {
      final s = await _pump(tester, AppRoutes.settings);
      await s.notifications.setEnabled(ReminderKind.review, true);
      await s.settings.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Dib u deji ogeysiisyada'));
      await tester.tap(find.text('Dib u deji'));
      await tester.pumpAndSettle();
      expect(s.notifications.enabledCount, 0);
      expect(s.settings.themeMode, ThemeMode.dark);
      expect(find.text('Ogeysiisyada waa la dib u dejiyay'), findsOneWidget);
    });
  });

  group('Layout: small screen, dark, large text', () {
    for (final route in [
      AppRoutes.profile,
      AppRoutes.settings,
      AppRoutes.settingsLanguage,
      AppRoutes.settingsReading,
      AppRoutes.settingsNotifications,
      AppRoutes.settingsAppearance,
      AppRoutes.help,
      AppRoutes.about,
    ]) {
      testWidgets('$route has no overflow', (tester) async {
        await _pump(
          tester,
          route,
          store: _signedInStore(theme: 'dark'),
          size: const Size(320, 568),
          textScale: 1.5,
        );
        expect(tester.takeException(), isNull);
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Finder _statSemantics(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label, description: 'stat "$label"');
