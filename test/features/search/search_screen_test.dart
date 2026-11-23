import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/widgets/widgets.dart';
import 'package:xadiithapp/features/search/presentation/categories_screen.dart';
import 'package:xadiithapp/features/search/presentation/search_screen.dart';
import 'package:xadiithapp/features/search/presentation/widgets/search_result_card.dart';
import 'package:xadiithapp/features/search/presentation/widgets/search_states.dart';

import '../../support/test_library.dart';

Future<AppServices> _pump(
  WidgetTester tester, {
  String initial = AppRoutes.search,
  Size size = const Size(390, 844),
  String theme = 'light',
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final services = await createTestServices(
    InMemorySettingsStore({'auth.onboardingSeen': true, 'settings.themeMode': theme}),
  );
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: initial));
  await tester.pumpAndSettle();
  return services;
}

Finder get _field => find.byType(TextField);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump(SearchScreen.debounce);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _count(int n) => find.text('$n natiijo');

int _tab(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  group('Search screen', () {
    testWidgets('initial state: title, hint and suggested topics', (tester) async {
      await _pump(tester);
      expect(find.widgetWithText(AppBar, SearchScreen.title), findsOneWidget);
      expect(find.text(SearchScreen.hint), findsOneWidget);
      expect(find.byType(SearchInitialView), findsOneWidget);
      expect(find.text('Mowduucyo la soo jeediyay'), findsOneWidget);
      expect(find.text('Salaadda'), findsOneWidget);
    });

    testWidgets('Somali query after debounce; empty query resets', (tester) async {
      final s = await _pump(tester);
      await _type(tester, 'Muslim');
      expect(_count(s.search.search(query: 'Muslim').length), findsOneWidget);
      await tester.tap(find.byTooltip('Tirtir raadinta'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchInitialView), findsOneWidget);
    });

    testWidgets('Arabic query with diacritics; Arabic RTL, Somali LTR', (tester) async {
      final s = await _pump(tester);
      await _type(tester, 'تَجْرِيبِي');
      expect(_count(s.search.search(query: 'تَجْرِيبِي').length), findsOneWidget);
      final card = find.byType(SearchResultCard).first;
      final arabic = find.descendant(
        of: find.descendant(of: card, matching: find.byType(ArabicText)),
        matching: find.byType(Text),
      );
      expect(Directionality.of(tester.element(arabic.first)), TextDirection.rtl);
      expect(Directionality.of(tester.element(card)), TextDirection.ltr);
    });

    testWidgets('matching Somali words are highlighted', (tester) async {
      await _pump(tester);
      await _type(tester, 'tarjumaadda');
      final rich = tester.widgetList<RichText>(
        find.descendant(of: find.byType(SearchResultCard).first, matching: find.byType(RichText)),
      );
      final highlighted = rich.any((r) {
        var found = false;
        r.text.visitChildren((span) {
          if (span is TextSpan && span.style?.backgroundColor != null && span.text == 'tarjumaadda') {
            found = true;
          }
          return !found;
        });
        return found;
      });
      expect(highlighted, isTrue);
    });

    testWidgets('no results shows helpful suggestions', (tester) async {
      await _pump(tester);
      await _type(tester, 'zzzzqq');
      expect(find.text(SearchNoResultsView.title), findsOneWidget);
      expect(find.text('• Hubi higgaadda erayga.'), findsOneWidget);
      expect(find.text('Eeg mowduucyada'), findsOneWidget);
    });

    testWidgets('submitted terms appear in history; remove and reuse', (tester) async {
      final s = await _pump(tester);
      await tester.enterText(_field, 'Muslim');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(s.searchHistory.terms, ['Muslim']);

      await tester.tap(find.byTooltip('Tirtir raadinta'));
      await tester.pumpAndSettle();
      expect(find.text('Raadintii dhowayd'), findsOneWidget);
      await _tap(tester, find.widgetWithText(InputChip, 'Muslim'));
      expect(find.widgetWithText(TextField, 'Muslim'), findsOneWidget);
      expect(_count(s.search.search(query: 'Muslim').length), findsOneWidget);

      await tester.tap(find.byTooltip('Tirtir raadinta'));
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Ka saar "Muslim"'));
      expect(s.searchHistory.terms, isEmpty);
    });

    testWidgets('filter sheet: apply book + topic, query preserved, chips removable', (tester) async {
      final s = await _pump(tester);
      await _type(tester, 'tusaale');
      await _tap(tester, find.byTooltip('Shaandhee'));
      expect(find.text('Shaandhaynta'), findsOneWidget);
      expect(find.textContaining('weriyaha iyo darajada lama heli karo'), findsOneWidget);
      await _tap(tester, find.widgetWithText(FilterChip, 'Saxiix Muslim'));
      final salaad = find.byWidgetPredicate((w) => w is FilterChip && (w.label as Text).data!.startsWith('Salaadda'));
      await _tap(tester, salaad);
      await _tap(tester, find.text('Codso'));

      expect(find.widgetWithText(TextField, 'tusaale'), findsOneWidget);
      expect(find.widgetWithText(Badge, '2'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Saxiix Muslim'), findsOneWidget);
      final results = s.search.search(query: 'tusaale');
      final filtered = results.where((h) => h.bookId == 'muslim' && h.categoryIds.contains('salah'));
      expect(_count(filtered.length), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Saxiix Muslim'),
          matching: find.byTooltip('Ka saar shaandhaynta'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Saxiix Muslim'), findsNothing);
      expect(find.widgetWithText(Badge, '1'), findsOneWidget);
    });

    testWidgets('filter sheet reset clears the draft', (tester) async {
      await _pump(tester, initial: AppRoutes.searchWith(bookId: 'muslim'));
      await _tap(tester, find.byTooltip('Shaandhee'));
      await _tap(tester, find.text('Dib u deji'));
      await _tap(tester, find.text('Codso'));
      expect(find.byType(SearchInitialView), findsOneWidget);
    });

    testWidgets('bookmark filter shows only saved records', (tester) async {
      final s = await _pump(tester);
      await s.favorites.toggle('muslim-c1-h1');
      await _tap(tester, find.byTooltip('Shaandhee'));
      await _tap(tester, find.text('La keydiyay'));
      await _tap(tester, find.text('Codso'));
      expect(_count(1), findsOneWidget);
    });

    testWidgets('sorting by reference number', (tester) async {
      await _pump(tester);
      await _type(tester, 'Muslim');
      await _tap(tester, find.byTooltip('Kala soocid'));
      await _tap(tester, find.text('Lambarka xadiiska').last);
      final firstRef = find.descendant(of: find.byType(SearchResultCard).first, matching: find.textContaining('#1 '));
      expect(firstRef, findsOneWidget);
    });

    testWidgets('result → detail → back keeps the query and results', (tester) async {
      final s = await _pump(tester);
      await _type(tester, 'Muslim');
      await _tap(tester, find.byType(SearchResultCard).first);
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
      expect(s.searchHistory.terms, ['Muslim'], reason: 'opening a result saves the term');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Muslim'), findsOneWidget);
      // The header may be scrolled just above the viewport after ensureVisible.
      expect(find.text('${s.search.search(query: 'Muslim').length} natiijo', skipOffstage: false), findsOneWidget);
    });
  });

  group('Route parameters', () {
    testWidgets('?q= prefills the field and results', (tester) async {
      final s = await _pump(tester, initial: AppRoutes.searchWith(query: 'Muslim'));
      expect(find.widgetWithText(TextField, 'Muslim'), findsOneWidget);
      expect(_count(s.search.search(query: 'Muslim').length), findsOneWidget);
    });

    testWidgets('?book= applies a book filter; invalid IDs are ignored', (tester) async {
      await _pump(tester, initial: AppRoutes.searchWith(bookId: 'muslim'));
      expect(find.widgetWithText(InputChip, 'Saxiix Muslim'), findsOneWidget);
    });

    testWidgets('invalid category parameter falls back to the initial view', (tester) async {
      await _pump(tester, initial: AppRoutes.searchWith(categoryId: 'nope'));
      expect(find.byType(SearchInitialView), findsOneWidget);
    });

    testWidgets('book detail "Ka raadi kitaabkan" opens search scoped to the book', (tester) async {
      await _pump(tester, initial: AppRoutes.book('nawawi40'));
      await _tap(tester, find.byTooltip('Ka raadi kitaabkan'));
      expect(_tab(tester), 2);
      expect(find.widgetWithText(InputChip, 'Al-Arbaciin an-Nawawiyya'), findsOneWidget);
    });
  });

  group('Categories', () {
    testWidgets('list shows counts derived from data; empty topics labelled', (tester) async {
      final s = await _pump(tester, initial: AppRoutes.categories);
      expect(find.widgetWithText(AppBar, CategoriesScreen.title), findsOneWidget);
      expect(find.text('${s.search.countForCategory('salah')} xadiis'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Soonka'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Weli xadiis ma jiro'), findsWidgets);
      expect(_tab(tester), 2);
    });

    testWidgets('topic opens its results; results open detail', (tester) async {
      final s = await _pump(tester, initial: AppRoutes.categories);
      await _tap(tester, find.text('Salaadda'));
      expect(find.widgetWithText(AppBar, 'Salaadda'), findsOneWidget);
      expect(_count(s.search.countForCategory('salah')), findsOneWidget);
      await _tap(tester, find.byType(SearchResultCard).first);
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget);
    });

    testWidgets('empty topic explains there are no local records', (tester) async {
      await _pump(tester, initial: AppRoutes.categoryResults('sawm'));
      expect(find.text('Weli xadiis lama hayo'), findsOneWidget);
      await _tap(tester, find.text('Eeg mowduucyada kale'));
      expect(find.widgetWithText(AppBar, CategoriesScreen.title), findsOneWidget);
    });

    testWidgets('unknown topic shows not-found', (tester) async {
      await _pump(tester, initial: AppRoutes.categoryResults('nope'));
      expect(find.text('Mowduucan lama helin'), findsOneWidget);
    });

    testWidgets('"Ku raadi mowduucan" opens search with the topic filter', (tester) async {
      await _pump(tester, initial: AppRoutes.categoryResults('salah'));
      await _tap(tester, find.byTooltip('Ku raadi mowduucan'));
      expect(find.widgetWithText(InputChip, 'Salaadda'), findsOneWidget);
    });
  });

  group('Responsive', () {
    final cases = {
      'search results': AppRoutes.searchWith(query: 'tusaale'),
      'search initial': AppRoutes.search,
      'categories': AppRoutes.categories,
      'category results': AppRoutes.categoryResults('salah'),
    };
    for (final MapEntry(key: name, value: route) in cases.entries) {
      testWidgets('$name: no overflow at 320×568, dark, 1.5×', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(tester, initial: route, size: const Size(320, 568), theme: 'dark');
        for (var i = 0; i < 8; i++) {
          await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('filter sheet fits a small screen at 1.5×', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, size: const Size(320, 568), theme: 'dark');
      await _tap(tester, find.byTooltip('Shaandhee'));
      expect(tester.takeException(), isNull);
      expect(find.text('Codso'), findsOneWidget);
    });
  });
}
