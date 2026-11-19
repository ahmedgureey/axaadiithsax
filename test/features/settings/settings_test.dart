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
import 'package:xadiithapp/features/auth/auth_controller.dart';
import 'package:xadiithapp/features/favorites/favorites_controller.dart';
import 'package:xadiithapp/features/memorization/memorization_controller.dart';
import 'package:xadiithapp/features/settings/notification_preferences_controller.dart';
import 'package:xadiithapp/features/settings/presentation/help_screen.dart';
import 'package:xadiithapp/features/settings/presentation/notification_settings_screen.dart';
import 'package:xadiithapp/features/settings/presentation/privacy_screen.dart';

InMemorySettingsStore _guestStore({String theme = 'light'}) =>
    InMemorySettingsStore({'auth.onboardingSeen': true, 'auth.status': 'guest', 'settings.themeMode': theme});

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
  final services = await AppServices.create(store ?? _guestStore(), clock: () => DateTime(2026, 11, 18, 10));
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

  group('Profile name (demo)', () {
    test('guest cannot rename; signed-in name is trimmed, validated and persisted', () async {
      final guest = AuthController(_guestStore());
      await guest.load();
      expect(await guest.updateDisplayName('X'), isFalse);

      final store = _signedInStore();
      final auth = AuthController(store);
      await auth.load();
      expect(await auth.updateDisplayName('   '), isFalse);
      expect(await auth.updateDisplayName('x' * (AuthController.maxNameLength + 1)), isFalse);
      expect(await auth.updateDisplayName('  Xaliimo  '), isTrue);
      expect(auth.displayName, 'Xaliimo');
      expect(await store.getString('auth.displayName'), 'Xaliimo');
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
      final s = await AppServices.create(store, clock: () => DateTime(2026, 11, 18, 10));
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
      expect(s.auth.onboardingSeen, isFalse);
    });
  });

  group('Profile screen', () {
    testWidgets('guest: honest header, zero stats, login entry, links', (tester) async {
      await _pump(tester, AppRoutes.profile);
      expect(find.text('Marti'), findsOneWidget);
      expect(find.text('Marti — akoon ma jiro'), findsOneWidget);
      expect(_statSemantics('La keydiyay: 0'), findsOneWidget);
      expect(find.text('Gal ama is diiwaangeli'), findsOneWidget);
      expect(find.byTooltip('Beddel magaca'), findsNothing);
      await tester.scrollUntilVisible(find.text('Caawimaad'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Dejinta oo dhan'), findsOneWidget);
    });

    testWidgets('signed-in: name edit validates and saves locally', (tester) async {
      final s = await _pump(tester, AppRoutes.profile, store: _signedInStore());
      expect(find.text('Cali'), findsOneWidget);
      expect(find.text('demo@xadiis.app'), findsOneWidget);
      expect(find.text('Akoon demo · email lama xaqiijin'), findsOneWidget);

      await tester.tap(find.byTooltip('Beddel magaca'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '  ');
      await tester.tap(find.text('Keydi'));
      await tester.pumpAndSettle();
      expect(find.text('Magacu waa qasab.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Xaliimo');
      await tester.tap(find.text('Keydi'));
      await tester.pumpAndSettle();
      expect(s.auth.displayName, 'Xaliimo');
      expect(find.text('Xaliimo'), findsOneWidget);
    });

    testWidgets('stats reflect real favourites', (tester) async {
      final s = await _pump(tester, AppRoutes.profile);
      await s.favorites.add(s.repository.dailyHadith(DateTime(2026, 11, 18))!.id);
      await tester.pumpAndSettle();
      expect(_statSemantics('La keydiyay: 1'), findsOneWidget);
    });

    testWidgets('profile → help and settings navigation', (tester) async {
      await _pump(tester, AppRoutes.profile);
      await _tap(tester, find.text('Caawimaad'));
      expect(find.widgetWithText(AppBar, HelpScreen.title), findsOneWidget);
      await tester.tap(find.text(HelpScreen.topics.first.$2));
      await tester.pumpAndSettle();
      expect(find.text(HelpScreen.topics.first.$3), findsOneWidget);
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

    testWidgets('notifications: honest notice, toggle + persistence', (tester) async {
      final store = _guestStore();
      final s = await _pump(tester, AppRoutes.settingsNotifications, store: store);
      expect(find.text(NotificationSettingsScreen.notice), findsOneWidget);
      expect(find.textContaining('Dansan'), findsNWidgets(ReminderKind.values.length));
      await tester.tap(find.text(ReminderKind.memorization.label));
      await tester.pumpAndSettle();
      expect(s.notifications.isEnabled(ReminderKind.memorization), isTrue);
      expect(await store.getBool('notifications.memorization'), isTrue);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('privacy explains local storage and web downloads accurately', (tester) async {
      await _pump(tester, AppRoutes.settingsPrivacy);
      expect(find.widgetWithText(AppBar, PrivacyScreen.title), findsOneWidget);
      expect(find.text('Waxa qalabkan lagu kaydiyo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Nooca web-ka (browser)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('CanvasKit'), findsOneWidget);
    });

    testWidgets('about shows the real version and a disclaimer', (tester) async {
      await _pump(tester, AppRoutes.about);
      expect(find.text(AboutScreen.versionLabel), findsOneWidget);
      expect(find.text('Nooca 1.0.1 (build 2)'), findsOneWidget);
      expect(find.textContaining('tusaale aan la xaqiijin'), findsOneWidget);
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
      expect(s.auth.onboardingSeen, isFalse);
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
      AppRoutes.settingsPrivacy,
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
