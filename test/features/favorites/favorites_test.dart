import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/theme/theme.dart';
import 'package:xadiithapp/core/widgets/widgets.dart';
import 'package:xadiithapp/data/models/chapter.dart';
import 'package:xadiithapp/data/models/hadith.dart';
import 'package:xadiithapp/data/models/hadith_book.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';
import 'package:xadiithapp/features/favorites/favorites_controller.dart';
import 'package:xadiithapp/features/favorites/presentation/favorites_screen.dart';
import 'package:xadiithapp/features/favorites/presentation/widgets/favorites_empty_state.dart';
import 'package:xadiithapp/features/hadith/hadith_actions.dart';
import 'package:xadiithapp/features/hadith/presentation/widgets/hadith_audio_player.dart';

import '../../support/test_library.dart';

/// Storage that can be told to fail reads and/or writes.
class _FlakyStore extends InMemorySettingsStore {
  _FlakyStore([super.initial]);
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<List<String>?> getStringList(String key) =>
      failReads ? Future.error(StateError('read failed')) : super.getStringList(key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      failWrites ? Future.error(StateError('write failed')) : super.setStringList(key, value);
}

Future<AppServices> _pump(
  WidgetTester tester,
  String initial, {
  SettingsStore? store,
  Size size = const Size(390, 844),
  String theme = 'light',
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final s = store ?? InMemorySettingsStore({'auth.onboardingSeen': true, 'settings.themeMode': theme});
  final services = await createTestServices(s);
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: initial));
  await tester.pumpAndSettle();
  return services;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Map<String, Object> _session([List<String>? favorites]) => {
  'auth.onboardingSeen': true,
  'favorites.hadithIds': ?favorites,
};

void main() {
  group('FavoritesController', () {
    test('add / remove are idempotent; newest first; no duplicates', () async {
      final c = FavoritesController(InMemorySettingsStore());
      await c.load();
      await c.add('a');
      await c.add('b');
      await c.add('a');
      expect(c.ids, ['b', 'a']);
      expect(await c.toggle('a'), isFalse);
      expect(await c.toggle('a'), isTrue);
      expect(c.ids, ['a', 'b']);
      await c.remove('zzz');
      expect(c.count, 2);
    });

    test('restores after a simulated restart', () async {
      final store = InMemorySettingsStore();
      final first = FavoritesController(store);
      await first.load();
      await first.add('muslim-c1-h1');
      await first.add('bukhari-c1-h2');

      final restarted = FavoritesController(store);
      expect(restarted.isLoaded, isFalse);
      await restarted.load();
      expect(restarted.ids, ['bukhari-c1-h2', 'muslim-c1-h1']);
    });

    test('corrupted storage is de-duplicated on load', () async {
      final c = FavoritesController(
        InMemorySettingsStore({
          FavoritesController.storageKey: ['x', 'y', 'x', ''],
        }),
      );
      await c.load();
      expect(c.ids, ['x', 'y']);
    });

    test('read failure is reported, retry recovers', () async {
      final store = _FlakyStore({
        FavoritesController.storageKey: ['x'],
      })..failReads = true;
      final c = FavoritesController(store);
      await c.load();
      expect(c.loadFailed, isTrue);
      expect(c.ids, isEmpty);
      store.failReads = false;
      await c.load();
      expect(c.loadFailed, isFalse);
      expect(c.ids, ['x']);
    });

    test('write failure keeps the in-memory state', () async {
      final store = _FlakyStore()..failWrites = true;
      final c = FavoritesController(store);
      await c.load();
      await c.add('x');
      expect(c.isFavorite('x'), isTrue);
    });

    test('removeMissing drops IDs that no longer exist', () async {
      final c = FavoritesController(InMemorySettingsStore());
      await c.load();
      await c.add('real');
      await c.add('ghost');
      expect(await c.removeMissing((id) => id == 'real'), 1);
      expect(c.ids, ['real']);
    });
  });

  group('Copy / share text', () {
    final repo = testRepository();

    test('demo record: Arabic, Somali, book, reference, narrator, disclaimer; no grade', () {
      final h = repo.hadithById('muslim-c1-h1')!;
      final text = formatHadithText(h, repo);
      expect(text, contains(h.arabicText));
      expect(text, contains(h.somaliText));
      expect(text, contains('Saxiix Muslim · ${repo.referenceLabel(h)}'));
      expect(text, startsWith(h.narrator!));
      expect(text, contains('ma aha xadiis la xaqiijiyay'));
      expect(text, isNot(contains('Darajada')));
    });

    test('missing translation / narrator are not invented', () {
      final h = repo.hadithById('${TestLibrary.incompleteChapterId}-h3')!;
      final text = formatHadithText(h, repo);
      expect(text, contains(missingTranslationText));
      expect(text, startsWith(h.arabicText));
    });

    test('verified record includes grade and real reference, no disclaimer', () {
      const book = HadithBook(id: 'b', nameSomali: 'Kitaab', nameArabic: 'كتاب', author: 'A', description: '');
      const chapter = Chapter(id: 'b-c1', bookId: 'b', number: 1, titleSomali: 'C', titleArabic: 'ب');
      const verified = Hadith(
        id: 'v1',
        bookId: 'b',
        chapterId: 'b-c1',
        number: 7,
        arabicText: 'نص',
        somaliText: 'Tarjumaad',
        grade: 'Saxiix',
        reference: 'Kitaab 7',
        sourceStatus: SourceStatus.verified,
      );
      final r = HadithRepository(books: [book], chapters: [chapter], hadiths: [verified], categories: []);
      final text = formatHadithText(verified, r);
      expect(text, contains('Darajada: Saxiix'));
      expect(text, contains('Kitaab · Kitaab 7'));
      expect(text, isNot(contains('tusaale')));
    });
  });

  group('Favorites screen', () {
    testWidgets('empty state explains and links to search', (tester) async {
      await _pump(tester, AppRoutes.favorites);
      expect(find.widgetWithText(AppBar, FavoritesScreen.title), findsOneWidget);
      expect(find.text(FavoritesEmptyState.title), findsOneWidget);
      await _tap(tester, find.text('Raadi Xadiisyo'));
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
    });

    testWidgets('count, local-storage note, sort and open detail', (tester) async {
      await _pump(
        tester,
        AppRoutes.favorites,
        store: InMemorySettingsStore(_session(['muslim-c1-h1', 'bukhari-c1-h1'])),
      );
      expect(find.text('2 xadiis ayaa la keydiyay'), findsOneWidget);
      expect(find.text(OfflineAvailability.savedOnDevice.label), findsOneWidget);

      String firstSource() => tester.widget<FavoriteHadithCard>(find.byType(FavoriteHadithCard).first).source;
      expect(firstSource(), 'Saxiix Muslim', reason: 'most recently saved first');
      await _tap(tester, find.text('Magaca kitaabka'));
      expect(firstSource(), 'Saxiix al-Bukhaari');

      await _tap(tester, find.text('Akhri xadiiska').first);
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, FavoritesScreen.title), findsOneWidget);
    });

    testWidgets('remove with confirmation updates the list', (tester) async {
      final s = await _pump(
        tester,
        AppRoutes.favorites,
        store: InMemorySettingsStore(_session(['muslim-c1-h1', 'bukhari-c1-h1'])),
      );
      await _tap(tester, find.byTooltip('Ka saar').first);
      await _tap(tester, find.widgetWithText(FilledButton, 'Ka saar'));
      expect(s.favorites.ids, ['bukhari-c1-h1']);
      expect(find.text('1 xadiis ayaa la keydiyay'), findsOneWidget);
    });

    testWidgets('missing saved IDs are reported and can be cleaned up', (tester) async {
      final s = await _pump(
        tester,
        AppRoutes.favorites,
        store: InMemorySettingsStore(_session(['ghost-id', 'muslim-c1-h1'])),
      );
      expect(find.textContaining('1 xadiis oo la keydiyay hadda kuma jiraan'), findsOneWidget);
      await _tap(tester, find.text('Ka saar kuwa maqan'));
      expect(s.favorites.ids, ['muslim-c1-h1']);
      expect(find.textContaining('kuma jiraan xogta'), findsNothing);
    });

    testWidgets('storage read failure shows retry instead of crashing', (tester) async {
      final store = _FlakyStore(_session(['muslim-c1-h1']))..failReads = true;
      await _pump(tester, AppRoutes.favorites, store: store);
      expect(find.text('Kuwa la keydiyay lama soo rari karin'), findsOneWidget);
      store.failReads = false;
      await _tap(tester, find.text('Isku day mar kale'));
      expect(find.text('1 xadiis ayaa la keydiyay'), findsOneWidget);
    });
  });

  group('Bookmarking from the reader', () {
    testWidgets('save shows confirmation, undo restores, favorites screen syncs', (tester) async {
      final s = await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      await _tap(tester, find.byTooltip('Ku dar kuwa la jecel yahay').first);
      expect(find.text('Waa la keydiyay'), findsOneWidget);
      expect(s.favorites.ids, ['muslim-c1-h1']);

      await _tap(tester, find.byTooltip('Ka saar kuwa la jecel yahay').first);
      expect(s.favorites.ids, isEmpty);
      await _tap(tester, find.text('Celi'));
      expect(s.favorites.ids, ['muslim-c1-h1'], reason: 'undo');

      // Reading-actions button reflects the same state.
      expect(find.text('La keydiyay'), findsOneWidget);
    });

    testWidgets('bookmark from search appears in favorites', (tester) async {
      final s = await _pump(tester, AppRoutes.searchWith(query: 'Muslim'));
      await _tap(tester, find.byTooltip('Ku dar kuwa la jecel yahay').first);
      expect(s.favorites.count, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(XadiisApp(services: s, initialLocation: AppRoutes.favorites));
      await tester.pumpAndSettle();
      expect(find.text('1 xadiis ayaa la keydiyay'), findsOneWidget);
    });
  });

  group('Reading actions, audio and offline status', () {
    testWidgets('"Koobiyee dhammaan" copies the formatted text', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final s = await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      await _tap(tester, find.text('Koobiyee dhammaan'));
      final h = s.repository.hadithById('muslim-c1-h1')!;
      expect(copied.single, formatHadithText(h, s.repository));
      expect(find.text('Xadiiska waa la koobiyeeyay'), findsOneWidget);
    });

    testWidgets('audio player shows an honest unavailable state', (tester) async {
      await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      await tester.scrollUntilVisible(
        find.text(HadithAudioPlayer.unavailableLabel),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final play = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.play_arrow_rounded));
      expect(play.onPressed, isNull, reason: 'never pretends to play');
      final speeds = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      expect(speeds.every((c) => c.onSelected == null), isTrue);
      expect(find.text('--:--'), findsOneWidget);
    });

    testWidgets('offline status: bundled hadith vs book without content', (tester) async {
      await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      expect(find.text(OfflineAvailability.availableLocally.label), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, AppRoutes.book('abudawud'));
      expect(find.text(OfflineAvailability.notDownloaded.label), findsOneWidget);
    });

    testWidgets('Arabic font size respects the minimum', (tester) async {
      final s = await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      await s.settings.setArabicFontSize(ArabicFontSize.min);
      await tester.pumpAndSettle();
      final shrink = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.text_decrease_rounded));
      expect(shrink.onPressed, isNull);
      await s.settings.setArabicFontSize(ArabicFontSize.min - 10);
      expect(s.settings.arabicFontSize, ArabicFontSize.min);
    });
  });

  group('Responsive', () {
    for (final route in [AppRoutes.favorites, AppRoutes.hadith('muslim-c1-h1')]) {
      testWidgets('$route: no overflow at 320×568, dark, 1.5×', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(
          tester,
          route,
          size: const Size(320, 568),
          store: InMemorySettingsStore({
            ..._session(['muslim-c1-h1', 'bukhari-c1-h1']),
            'settings.themeMode': 'dark',
          }),
        );
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
