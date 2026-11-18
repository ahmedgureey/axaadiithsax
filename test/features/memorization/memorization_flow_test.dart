import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/features/memorization/memorization_controller.dart';
import 'package:xadiithapp/features/memorization/presentation/memorization_screen.dart';
import 'package:xadiithapp/features/memorization/presentation/review_screen.dart';
import 'package:xadiithapp/features/quiz/domain/quiz_models.dart';
import 'package:xadiithapp/features/quiz/presentation/widgets/quiz_question_card.dart';

final _day0 = DateTime(2026, 11, 18, 10);

Future<AppServices> _pump(
  WidgetTester tester,
  String initial, {
  InMemorySettingsStore? store,
  DateTime? now,
  Size size = const Size(390, 844),
  String theme = 'light',
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final s = store ?? _store(theme: theme);
  final services = await AppServices.create(s, clock: () => now ?? _day0);
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: initial));
  await tester.pumpAndSettle();
  return services;
}

InMemorySettingsStore _store({String theme = 'light'}) =>
    InMemorySettingsStore({'auth.onboardingSeen': true, 'auth.status': 'guest', 'settings.themeMode': theme});

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('Dashboard', () {
    testWidgets('new user sees honest zeros, no fake streak or quiz history', (tester) async {
      final s = await _pump(tester, AppRoutes.memorization);
      expect(find.widgetWithText(AppBar, MemorizationScreen.title), findsOneWidget);
      expect(find.text('0 / 3 xadiis ayaa la xifdiyey maanta'), findsOneWidget);
      expect(find.text('Weli silsilad ma jirto'), findsOneWidget);
      expect(find.text('0 / ${s.memorization.totalAvailable}'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Weli imtixaan ma aadan gelin.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Toddobaadkan weli wax dhaqdhaqaaq ah lama diiwaangelin.'), findsOneWidget);
    });

    testWidgets('daily target can be changed from the dashboard', (tester) async {
      final s = await _pump(tester, AppRoutes.memorization);
      await _tap(tester, find.text('3 maalintii'));
      await tester.tap(find.widgetWithText(ChoiceChip, '1'));
      await tester.pumpAndSettle();
      expect(s.memorization.dailyTarget, 1);
      expect(find.text('0 / 1 xadiis ayaa la xifdiyey maanta'), findsOneWidget);
    });
  });

  group('Daily plan and memorising', () {
    testWidgets('start → Waan Xifdiyey → next → undo; progress syncs', (tester) async {
      final s = await _pump(tester, AppRoutes.memorization);
      final first = s.memorization.todayPlan.first;
      await _tap(tester, find.text('Bilow qorshaha maanta'));
      expect(find.widgetWithText(AppBar, 'Xifdi'), findsOneWidget);

      await _tap(tester, find.text('Waan Xifdiyey'));
      expect(s.memorization.isMemorized(first), isTrue);
      expect(find.text('Waa la diiwaangeliyay'), findsOneWidget);

      await _tap(tester, find.text('Ka noqo'));
      expect(s.memorization.isMemorized(first), isFalse);
      await _tap(tester, find.text('Waan Xifdiyey'));

      await _tap(tester, find.text('Xadiiska xiga'));
      expect(find.text('Weli lama xifdin'), findsOneWidget);
      expect(s.memorization.completedToday, 1);
    });

    testWidgets('finishing the plan shows a completion message', (tester) async {
      final store = _store();
      final s = await _pump(tester, AppRoutes.memorizationPlan, store: store);
      await s.memorization.setDailyTarget(1);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Bilow qorshaha maanta'));
      await _tap(tester, find.text('Waan Xifdiyey'));
      expect(find.textContaining('Qorshaha maanta waa dhammaaday'), findsOneWidget);
      // Let the floating snack bar (which overlaps the bottom button) close.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Ku noqo Xifdintayda'));
      expect(find.text('Hambalyo! Waad dhammaysay qorshaha maanta.'), findsOneWidget);
    });

    testWidgets('memorising from the full reader uses the same record', (tester) async {
      final s = await _pump(tester, AppRoutes.hadith('muslim-c1-h1'));
      await _tap(tester, find.text('Calaamadee: Waan Xifdiyey'));
      expect(s.memorization.isMemorized('muslim-c1-h1'), isTrue);
    });

    testWidgets('unknown hadith in memorise route → not found', (tester) async {
      await _pump(tester, AppRoutes.memorizeHadith('nope'));
      expect(find.text('Xadiiskan lama helin'), findsOneWidget);
    });
  });

  group('Review and persistence', () {
    testWidgets('memorised yesterday → due today → review completes once', (tester) async {
      final store = _store();
      final first = await AppServices.create(store, clock: () => _day0);
      await first.memorization.markMemorized('bukhari-c1-h1');

      final s = await _pump(
        tester,
        AppRoutes.memorizationReview,
        store: store,
        now: _day0.add(const Duration(days: 1)),
      );
      expect(find.widgetWithText(AppBar, ReviewScreen.title), findsOneWidget);
      expect(find.text('Fadhigan: 0 dib-u-eegis · 1 ayaa haray'), findsOneWidget);
      await _tap(tester, find.text('Waan dib u eegay'));
      expect(find.text('Fadhigan: 1 dib-u-eegis · 0 ayaa haray'), findsOneWidget);
      expect(find.text('Hambalyo! Dib-u-eegistii waa dhammaatay.'), findsOneWidget);
      expect(s.memorization.reviewsCompletedToday, 1);
    });

    testWidgets('progress survives an app restart; outdated IDs ignored', (tester) async {
      final store = _store();
      await store.setString(
        MemorizationController.storageKey,
        '{"v":1,"target":5,"records":[{"id":"ghost","on":"2026-11-18","stage":0,"next":"2026-11-19"},'
        '{"id":"muslim-c1-h1","on":"2026-11-18","stage":0,"next":"2026-11-19"}],"activity":{},"quiz":[]}',
      );
      final s = await _pump(tester, AppRoutes.memorization, store: store);
      expect(s.memorization.dailyTarget, 5);
      expect(s.memorization.memorizedCount, 1);
      expect(find.text('1 / 5 xadiis ayaa la xifdiyey maanta'), findsOneWidget);
    });
  });

  group('Quiz', () {
    Future<void> answerAll(WidgetTester tester, int count) async {
      for (var i = 1; i <= count; i++) {
        await tester.ensureVisible(find.byType(QuizAnswerOption).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(QuizAnswerOption).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(i == count ? 'Arag natiijada' : "Su'aasha xigta"));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('setup → questions → results recorded on the dashboard', (tester) async {
      final s = await _pump(tester, AppRoutes.quiz);
      await _tap(tester, find.text('Bilow imtixaanka'));
      expect(find.widgetWithText(AppBar, "Su'aal 1 / 5"), findsOneWidget);
      await answerAll(tester, 5);

      final attempt = s.memorization.quizHistory.single;
      expect(attempt.total, 5);
      expect(find.text('${attempt.percentage}%'), findsOneWidget);
      expect(find.text('${attempt.correct} / 5 sax'), findsOneWidget);
      if (attempt.correct < 5) expect(find.text('Kuwii aad khaldantay'), findsOneWidget);

      await _tap(tester, find.text('Ku noqo Xifdinta'));
      await tester.scrollUntilVisible(
        find.text('${attempt.correct} / 5 sax (${attempt.percentage}%)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('${attempt.correct} / 5 sax (${attempt.percentage}%)'), findsOneWidget);
    });

    testWidgets('answers lock after submission and show Sax/Khalad in words', (tester) async {
      await _pump(tester, AppRoutes.quiz);
      await _tap(tester, find.text('Bilow imtixaanka'));
      await tester.ensureVisible(find.byType(QuizAnswerOption).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(QuizAnswerOption).first);
      await tester.pumpAndSettle();
      // The explanation sits below the options (may be outside the viewport).
      final feedback = find.textContaining(RegExp(r'^(Sax!|Khalad\.)'), skipOffstage: false);
      expect(feedback, findsOneWidget);
      final before = tester.widget<Text>(feedback).data;
      // Regression: the "next" bar once covered the whole screen after answering.
      expect(find.byType(QuizAnswerOption), findsWidgets, reason: 'options stay visible after answering');
      final screen = tester.getSize(find.byType(Scaffold).last);
      final bar = tester.getSize(find.widgetWithText(FilledButton, "Su'aasha xigta"));
      expect(bar.height, lessThan(screen.height / 4));
      final lastOption = find.byType(QuizAnswerOption, skipOffstage: false).last;
      await tester.ensureVisible(lastOption);
      await tester.pumpAndSettle();
      await tester.tap(lastOption, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(feedback).data, before, reason: 'second tap ignored');
      expect(find.text('Sax', skipOffstage: false), findsOneWidget, reason: 'correct option labelled in words');
    });

    testWidgets('favorites quiz with nothing saved shows an explanation', (tester) async {
      await _pump(tester, AppRoutes.quiz);
      await _tap(tester, find.text(QuizSource.favorites.label));
      await _tap(tester, find.text('Bilow imtixaanka'));
      expect(find.text('Imtixaan lama samayn karo'), findsOneWidget);
    });

    testWidgets('leaving mid-quiz asks for confirmation', (tester) async {
      await _pump(tester, AppRoutes.quiz);
      await _tap(tester, find.text('Bilow imtixaanka'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Ka bax imtixaanka?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Ka bax'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Imtixaanka Xadiiska'), findsOneWidget);
    });
  });

  group('Responsive', () {
    final routes = [AppRoutes.memorization, AppRoutes.memorizationPlan, AppRoutes.memorizationReview, AppRoutes.quiz];
    for (final route in routes) {
      testWidgets('$route: no overflow at 320×568, dark, 1.5×', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(tester, route, size: const Size(320, 568), theme: 'dark');
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('quiz question: no overflow at 320×568, 1.5×', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, AppRoutes.quizPlay, size: const Size(320, 568), theme: 'dark');
      await tester.ensureVisible(find.byType(QuizAnswerOption).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(QuizAnswerOption).first);
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
