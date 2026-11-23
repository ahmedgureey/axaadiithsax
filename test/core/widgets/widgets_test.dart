import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/features/design_system/design_system_screen.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/theme/theme.dart';
import 'package:xadiithapp/core/widgets/widgets.dart';

Widget _wrap(Widget child, {ThemeData? theme, double textScale = 1}) {
  return AppSettingsScope(
    controller: AppSettingsController(InMemorySettingsStore()),
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  group('HonorificText', () {
    testWidgets('renders only ﷺ with Amiri, keeps the rest in the UI font', (tester) async {
      await tester.pumpWidget(_wrap(const HonorificText('Nabiga ﷺ iyo asxaabtiisa')));
      final rich = tester.widget<Text>(find.text('Nabiga ﷺ iyo asxaabtiisa')).textSpan! as TextSpan;
      final spans = rich.children!.cast<TextSpan>();
      expect(spans.map((s) => s.text), ['Nabiga ', 'ﷺ', ' iyo asxaabtiisa']);
      expect(spans[1].style!.fontFamily, 'Amiri');
      expect(spans[0].style, isNull);
    });
    testWidgets('plain text without ﷺ stays a simple Text', (tester) async {
      await tester.pumpWidget(_wrap(const HonorificText('Xadiith App')));
      expect(tester.widget<Text>(find.text('Xadiith App')).data, 'Xadiith App');
    });
  });
  group('ArabicText', () {
    testWidgets('renders in an RTL region inside an LTR screen', (tester) async {
      await tester.pumpWidget(_wrap(const ArabicText('نص تجريبي')));
      final text = tester.widget<Text>(find.text('نص تجريبي'));
      expect(text.textDirection, TextDirection.rtl);
      final ctx = tester.element(find.text('نص تجريبي'));
      expect(Directionality.of(ctx), TextDirection.rtl);
      // Surrounding Somali UI remains LTR.
      expect(Directionality.of(tester.element(find.byType(Scaffold))), TextDirection.ltr);
    });

    testWidgets('uses bundled Amiri font, and font + license assets exist', (tester) async {
      await tester.pumpWidget(_wrap(const ArabicText('نص')));
      expect(tester.widget<Text>(find.text('نص')).style!.fontFamily, 'Amiri');
      for (final path in ['assets/fonts/Amiri-Regular.ttf', 'assets/fonts/Amiri-Bold.ttf']) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(100000), reason: path);
      }
      final license = await rootBundle.loadString('assets/fonts/Amiri-OFL.txt');
      expect(license, contains('SIL Open Font License'));
    });

    testWidgets('hadith variant follows reading size from settings', (tester) async {
      final settings = AppSettingsController(InMemorySettingsStore());
      await settings.setArabicFontSize(34);
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ArabicText('نص')),
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('نص')).style!.fontSize, 34);
    });
  });

  group('Buttons', () {
    testWidgets('PrimaryButton calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(PrimaryButton(label: 'Gal', onPressed: () => taps++)));
      await tester.tap(find.text('Gal'));
      expect(taps, 1);
    });

    testWidgets('PrimaryButton loading shows spinner and blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(PrimaryButton(label: 'Gal', isLoading: true, onPressed: () => taps++)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });

    testWidgets('buttons meet 48dp minimum touch target', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              PrimaryButton(label: 'A', onPressed: () {}),
              IconActionButton(icon: Icons.copy, tooltip: 'Koobiyee', onPressed: () {}),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.byType(IconButton)).height, greaterThanOrEqualTo(48));
    });
  });

  group('HadithCard', () {
    testWidgets('placeholder content shows demo badge and hides grade', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const HadithCard(arabicText: 'نص', somaliText: 'Tarjumaad', source: 'Kitaab', grade: 'Saxiix', isDemo: true),
        ),
      );
      expect(find.byType(DemoContentBadge), findsOneWidget);
      expect(find.text('Saxiix'), findsNothing);
    });

    testWidgets('real unreviewed content: no demo badge, no grade', (tester) async {
      await tester.pumpWidget(
        _wrap(const HadithCard(arabicText: 'نص', somaliText: 'Tarjumaad', source: 'Kitaab', grade: 'Saxiix')),
      );
      expect(find.byType(DemoContentBadge), findsNothing);
      expect(find.text('Saxiix'), findsNothing, reason: 'grades only for verified records');
    });

    testWidgets('verified content shows grade without demo badge', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const HadithCard(
            arabicText: 'نص',
            somaliText: 'Tarjumaad',
            source: 'Kitaab',
            grade: 'Saxiix',
            isVerified: true,
          ),
        ),
      );
      expect(find.byType(DemoContentBadge), findsNothing);
      expect(find.text('Saxiix'), findsOneWidget);
    });

    testWidgets('favorite toggle fires', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        _wrap(
          HadithCard(
            arabicText: 'نص',
            somaliText: 'Tarjumaad',
            source: 'Kitaab',
            onFavoriteToggle: () => toggled = true,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Ku dar kuwa la jecel yahay'));
      expect(toggled, isTrue);
    });
  });

  group('Search', () {
    testWidgets('clear button appears with text and clears it', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(AppSearchField(controller: controller)));
      expect(find.byTooltip('Tirtir raadinta'), findsNothing);
      await tester.enterText(find.byType(TextField), 'salaad');
      await tester.pump();
      await tester.tap(find.byTooltip('Tirtir raadinta'));
      await tester.pump();
      expect(controller.text, isEmpty);
    });

    testWidgets('filter chips single-select', (tester) async {
      Set<String> selected = {'a'};
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => SearchFilterChips<String>(
              options: const [
                SearchFilterOption(value: 'a', label: 'A'),
                SearchFilterOption(value: 'b', label: 'B'),
              ],
              selected: selected,
              onSelectionChanged: (s) => setState(() => selected = s),
            ),
          ),
        ),
      );
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(selected, {'b'});
    });
  });

  group('Forms', () {
    test('validators', () {
      expect(AppValidators.email(''), isNotNull);
      expect(AppValidators.email('a@b'), isNotNull);
      expect(AppValidators.email('a@b.so'), isNull);
      expect(AppValidators.password('123'), isNotNull);
      expect(AppValidators.password('12345678'), isNull);
    });

    testWidgets('password visibility toggles', (tester) async {
      await tester.pumpWidget(_wrap(const PasswordTextField()));
      EditableText field() => tester.widget<EditableText>(find.byType(EditableText));
      expect(field().obscureText, isTrue);
      await tester.tap(find.byTooltip('Muuji furaha'));
      await tester.pump();
      expect(field().obscureText, isFalse);
    });
  });

  group('Feedback', () {
    testWidgets('confirm dialog returns true on confirm', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showConfirmDialog(context, title: 'Ka saar?'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Haa'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('error state retry fires', (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(SizedBox(height: 500, child: ErrorStateWidget(onRetry: () => retried = true))));
      await tester.tap(find.text('Isku day mar kale'));
      expect(retried, isTrue);
    });
  });

  group('Navigation', () {
    testWidgets('bottom nav shows five tabs and reports selection', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(currentIndex: 0, onDestinationSelected: (i) => tapped = i),
          ),
        ),
      );
      for (final label in ['Guriga', 'Kutubta', 'Raadinta', 'Xifdinta', 'Aniga']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Xifdinta'));
      expect(tapped, 3);
    });
  });

  group('Design system screen', () {
    for (final entry in {'light': ThemeMode.light, 'dark': ThemeMode.dark}.entries) {
      testWidgets('renders without overflow in ${entry.key} mode at 1.0x and 1.5x text', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        for (final scale in [1.0, 1.5]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final settings = AppSettingsController(InMemorySettingsStore());
          await settings.setThemeMode(entry.value);
          // Reset the tree so each scale starts at the top of the gallery.
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(_gallery(settings));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          // Scroll through the whole gallery to build every section.
          // (pumpAndSettle can't be used: the LoadingIndicator spins forever.)
          for (var i = 0; i < 12; i++) {
            await tester.drag(find.byType(ListView).first, const Offset(0, -700));
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          }
          expect(tester.takeException(), isNull);
        }
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
    }

    testWidgets('theme toggle switches to dark', (tester) async {
      final settings = AppSettingsController(InMemorySettingsStore());
      await settings.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(_gallery(settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mugdi'));
      await tester.pumpAndSettle();
      expect(settings.themeMode, ThemeMode.dark);
      final ctx = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(ctx).brightness, Brightness.dark);
    });
  });
}

/// Hosts the design-system gallery with live theme switching.
Widget _gallery(AppSettingsController settings) {
  return AppSettingsScope(
    controller: settings,
    child: ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeMode,
        home: const DesignSystemScreen(),
      ),
    ),
  );
}
