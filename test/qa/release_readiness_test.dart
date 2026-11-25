import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/widgets/arabic_text.dart';

import '../support/test_library.dart';

/// Cross-cutting release checks: keyboard overlap, accessibility guidelines,
/// RTL rendering of hadith text and startup with an empty store.

InMemorySettingsStore _store({String theme = 'light', String? language}) =>
    InMemorySettingsStore({'auth.onboardingSeen': true, 'settings.themeMode': theme, 'settings.language': ?language});

Future<AppServices> _pump(
  WidgetTester tester,
  String route, {
  InMemorySettingsStore? store,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final services = await createTestServices(store ?? _store(), clock: () => DateTime(2026, 11, 18, 10));
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: route));
  await tester.pumpAndSettle();
  return services;
}

void main() {
  group('Startup', () {
    testWidgets('empty storage starts at onboarding without errors', (tester) async {
      final services = await createTestServices(InMemorySettingsStore());
      await tester.pumpWidget(XadiisApp(services: services));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(services.onboarding.onboardingSeen, isFalse);
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('Keyboard overlap (320×568 with a 260 dp keyboard)', () {
    testWidgets('search stays usable without overflow', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 260 * 3);
      addTearDown(tester.view.resetViewInsets);
      await _pump(tester, AppRoutes.search, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Accessibility guidelines', () {
    const screens = [
      AppRoutes.home,
      AppRoutes.books,
      AppRoutes.search,
      AppRoutes.memorization,
      AppRoutes.profile,
      AppRoutes.settings,
      AppRoutes.favorites,
      AppRoutes.quiz,
      AppRoutes.memorizationPlan,
      AppRoutes.categories,
      AppRoutes.settingsReading,
      AppRoutes.settingsNotifications,
      AppRoutes.about,
      AppRoutes.help,
    ];
    for (final theme in ['light', 'dark']) {
      for (final route in screens) {
        testWidgets('$route ($theme): tap targets, labels and text contrast', (tester) async {
          final handle = tester.ensureSemantics();
          await _pump(tester, route, store: _store(theme: theme));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }

    for (final theme in ['light', 'dark']) {
      testWidgets('hadith reader ($theme): guidelines pass', (tester) async {
        final handle = tester.ensureSemantics();
        final probe = await createTestServices(InMemorySettingsStore());
        final id = probe.repository.dailyHadith(DateTime(2026, 11, 18))!.id;
        await _pump(tester, AppRoutes.hadith(id), store: _store(theme: theme));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('Arabic text integrity and direction', () {
    testWidgets('hadith Arabic is RTL and unchanged in every interface language', (tester) async {
      for (final lang in ['so', 'en', 'ar']) {
        final services = await _pump(tester, AppRoutes.home, store: _store(language: lang));
        final hadith = services.repository.dailyHadith(DateTime(2026, 11, 18))!;
        await tester.pumpWidget(
          XadiisApp(key: UniqueKey(), services: services, initialLocation: AppRoutes.hadith(hadith.id)),
        );
        await tester.pumpAndSettle();
        final arabic = find.byType(ArabicText);
        expect(arabic, findsWidgets);
        final rendered = <(String, TextDirection?)>[
          for (final t in tester.widgetList<Text>(find.descendant(of: arabic, matching: find.byType(Text))))
            (t.data ?? t.textSpan?.toPlainText() ?? '', t.textDirection),
          for (final t in tester.widgetList<SelectableText>(
            find.descendant(of: arabic, matching: find.byType(SelectableText)),
          ))
            (t.data ?? t.textSpan?.toPlainText() ?? '', t.textDirection),
        ];
        final body = rendered.where((r) => r.$1 == hadith.arabicText).toList();
        expect(body, isNotEmpty, reason: 'exact Arabic text, language=$lang');
        expect(body.every((r) => r.$2 == TextDirection.rtl), isTrue, reason: 'language=$lang');
        expect(tester.takeException(), isNull);
      }
    });
  });
}
