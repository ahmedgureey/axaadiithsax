import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/services/share_service.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/theme/theme.dart';
import 'package:xadiithapp/core/widgets/widgets.dart';
import 'package:xadiithapp/data/mock_data/mock_library.dart';
import 'package:xadiithapp/features/books/presentation/books_screen.dart';
import 'package:xadiithapp/features/hadith/hadith_actions.dart';

class _FakeShare implements ShareService {
  _FakeShare([this.outcome = ShareOutcome.shared]);
  final ShareOutcome outcome;
  final shared = <String>[];

  @override
  Future<ShareOutcome> shareText(String text, {String? subject}) async {
    shared.add(text);
    return outcome;
  }
}

class _Harness {
  _Harness(this.services, this.share);
  final AppServices services;
  final _FakeShare share;
}

Future<_Harness> _pump(
  WidgetTester tester,
  String initial, {
  Size size = const Size(390, 844),
  String theme = 'light',
  ShareOutcome shareOutcome = ShareOutcome.shared,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final share = _FakeShare(shareOutcome);
  final services = await AppServices.create(
    InMemorySettingsStore({'auth.onboardingSeen': true, 'auth.status': 'guest', 'settings.themeMode': theme}),
    share: share,
  );
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: initial));
  await tester.pumpAndSettle();
  return _Harness(services, share);
}

/// Captures Clipboard.setData calls.
List<String> _mockClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder get _arabicBody => find.descendant(
  of: find.byType(ArabicText).at(1), // [0] narrator, [1] matn
  matching: find.byType(SelectableText),
);

void main() {
  group('Library and book detail', () {
    testWidgets('library shows counts derived from the local data', (tester) async {
      await _pump(tester, AppRoutes.books);
      expect(find.widgetWithText(AppBar, BooksScreen.title), findsOneWidget);
      expect(find.textContaining('mana aha kutubta oo dhammaystiran'), findsOneWidget);
      final bukhari = find.ancestor(of: find.text('Saxiix al-Bukhaari'), matching: find.byType(BookCard));
      expect(find.descendant(of: bukhari, matching: find.text('3 cutub')), findsOneWidget);
      expect(find.descendant(of: bukhari, matching: find.text('9 xadiis')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sunan Abi Daawuud'), 200, scrollable: find.byType(Scrollable).first);
      final abuDawud = find.ancestor(of: find.text('Sunan Abi Daawuud'), matching: find.byType(BookCard));
      expect(find.descendant(of: abuDawud, matching: find.text('Weli lama darin')), findsOneWidget);
    });

    testWidgets('book → chapter shows real counts and identifiers', (tester) async {
      await _pump(tester, AppRoutes.books);
      await _tap(tester, find.text('Saxiix al-Bukhaari'));
      expect(find.text('3 cutub (halkan)'), findsOneWidget);
      expect(find.text('9 xadiis (halkan)'), findsOneWidget);
      expect(find.text('Cutubka 2 · 3 xadiis'), findsOneWidget);
      await _tap(tester, find.text('Cutub tusaale 2'));
      expect(find.text('Saxiix al-Bukhaari · Cutubka 2 · 3 xadiis'), findsOneWidget);
      expect(find.byType(HadithCard), findsWidgets);
    });

    testWidgets('book without content shows an empty state with a way back', (tester) async {
      await _pump(tester, AppRoutes.book('abudawud'));
      expect(find.text('Cutub lama helin'), findsOneWidget);
      await _tap(tester, find.text('Ku noqo kutubta'));
      expect(find.widgetWithText(AppBar, BooksScreen.title), findsOneWidget);
    });
  });

  group('Hadith detail', () {
    testWidgets('renders header, narrator, Arabic (RTL), translation and reference', (tester) async {
      await _pump(tester, AppRoutes.hadith('bukhari-c1-h2'));
      expect(find.text('Cutub tusaale 1 · #2'), findsOneWidget);
      expect(find.text('Weriyaha'), findsWidgets);
      expect(Directionality.of(tester.element(_arabicBody)), TextDirection.rtl);
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
      expect(find.byType(DemoContentBadge), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Isha'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Lama xaqiijin — xogtani waa tusaale'), findsOneWidget);
      expect(find.text('Tusaale (lama xaqiijin)'), findsOneWidget);
      expect(find.text(MockLibrary.demoSource), findsOneWidget);
    });

    testWidgets('missing translation and narrator show explicit messages', (tester) async {
      await _pump(tester, AppRoutes.hadith('${MockLibrary.incompleteChapterId}-h3'));
      expect(find.text(missingTranslationText), findsOneWidget);
      expect(find.text('Weriyaha lama hayo.'), findsOneWidget);
      expect(find.text('Koobiyee tarjumaadda'), findsNothing);
    });

    testWidgets('bookmark uses the shared favorites state', (tester) async {
      final h = await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      await _tap(tester, find.byTooltip('Ku dar kuwa la jecel yahay'));
      expect(h.services.favorites.isFavorite('muslim-c1-h1'), isTrue);
      await _tap(tester, find.byTooltip('Ka saar kuwa la jecel yahay'));
      expect(h.services.favorites.isFavorite('muslim-c1-h1'), isFalse);
    });

    testWidgets('copy Arabic and copy Somali use the clipboard', (tester) async {
      final copied = _mockClipboard(tester);
      final h = await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      final record = h.services.repository.hadithById('muslim-c1-h1')!;
      await _tap(tester, find.text('Koobiyee Carabiga'));
      await _tap(tester, find.text('Koobiyee tarjumaadda'));
      expect(copied, [record.arabicText, record.somaliText]);
    });

    testWidgets('share sends text with a demo disclaimer', (tester) async {
      final h = await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      await _tap(tester, find.byTooltip('La wadaag'));
      expect(h.share.shared, hasLength(1));
      expect(h.share.shared.single, contains('Xog tusaale ah — ma aha xadiis la xaqiijiyay'));
      expect(h.share.shared.single, contains('Saxiix Muslim'));
    });

    testWidgets('share falls back to copying when unavailable', (tester) async {
      final copied = _mockClipboard(tester);
      await _pump(tester, AppRoutes.hadith('muslim-c1-h1'), shareOutcome: ShareOutcome.unavailable);
      await _tap(tester, find.byTooltip('La wadaag'));
      expect(copied, hasLength(1));
      expect(find.textContaining('waa la koobiyeeyay'), findsOneWidget);
    });

    testWidgets('font controls change only the Arabic text and persist', (tester) async {
      final h = await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      double arabicSize() => tester.widget<SelectableText>(_arabicBody).style!.fontSize!;
      final somaliBefore = Theme.of(tester.element(_arabicBody)).textTheme.bodyLarge!.fontSize;

      expect(arabicSize(), ArabicFontSize.defaultSize);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.restart_alt_rounded)).onPressed, isNull);

      await _tap(tester, find.byTooltip('Weyneey qoraalka Carabiga'));
      expect(arabicSize(), ArabicFontSize.defaultSize + 2);
      expect(h.services.settings.arabicFontSize, ArabicFontSize.defaultSize + 2);
      expect(Theme.of(tester.element(_arabicBody)).textTheme.bodyLarge!.fontSize, somaliBefore);

      await _tap(tester, find.byTooltip('Yaree qoraalka Carabiga'));
      await _tap(tester, find.byTooltip('Yaree qoraalka Carabiga'));
      expect(arabicSize(), ArabicFontSize.defaultSize - 2);

      await _tap(tester, find.byTooltip('Dib u deji cabbirka'));
      expect(arabicSize(), ArabicFontSize.defaultSize);

      await h.services.settings.setArabicFontSize(ArabicFontSize.max);
      await tester.pumpAndSettle();
      final grow = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.text_increase_rounded));
      expect(grow.onPressed, isNull, reason: 'disabled at the maximum');
    });

    testWidgets('previous / next page through the book, crossing chapters', (tester) async {
      await _pump(tester, AppRoutes.chapter('bukhari', 'bukhari-c1'));
      await _tap(tester, find.byType(HadithCard).last); // h3
      expect(find.text('Cutub tusaale 1 · #3'), findsOneWidget);

      await _tap(tester, find.text('Xadiiska xiga'));
      expect(find.text('Cutub tusaale 2 · #1'), findsOneWidget);
      await _tap(tester, find.text('Xadiiskii hore'));
      expect(find.text('Cutub tusaale 1 · #3'), findsOneWidget);

      // Paging replaces the page, so Back returns to the chapter list.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Cutub tusaale 1'), findsOneWidget);
    });

    testWidgets('first record has no previous', (tester) async {
      await _pump(tester, AppRoutes.hadith('bukhari-c1-h1'));
      final prev = find.ancestor(of: find.text('Xadiiskii hore'), matching: find.byType(TextButton));
      expect(tester.widget<TextButton>(prev).onPressed, isNull);
    });

    testWidgets('related hadith opens another detail', (tester) async {
      await _pump(tester, AppRoutes.hadith('muslim-c2-h1'));
      await tester.scrollUntilVisible(find.text('Xadiisyo la xiriira'), 200, scrollable: find.byType(Scrollable).first);
      final firstRelated = find.ancestor(of: find.textContaining('(tusaale)'), matching: find.byType(AppCard)).last;
      await _tap(tester, firstRelated);
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
      expect(find.text('Cutub tusaale 2 · #1'), findsNothing);
    });
  });

  group('Responsive reading', () {
    final routes = {
      'library': AppRoutes.books,
      'book detail': AppRoutes.book('nawawi40'),
      'chapter': AppRoutes.chapter('nawawi40', MockLibrary.incompleteChapterId),
      'hadith detail': AppRoutes.hadith('nawawi40-c1-h1'),
      'hadith without translation': AppRoutes.hadith('${MockLibrary.incompleteChapterId}-h3'),
    };
    for (final MapEntry(key: name, value: route) in routes.entries) {
      testWidgets('$name: no overflow at 320×568, dark, 1.5× text, max Arabic size', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = await _pump(tester, route, size: const Size(320, 568), theme: 'dark');
        await h.services.settings.setArabicFontSize(ArabicFontSize.max);
        await tester.pumpAndSettle();
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
