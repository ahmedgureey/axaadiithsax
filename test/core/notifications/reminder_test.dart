import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/notifications/notification_gateway.dart';
import 'package:xadiithapp/core/notifications/reminder_planner.dart';
import 'package:xadiithapp/core/notifications/reminder_service.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/widgets/widgets.dart';
import 'package:xadiithapp/features/memorization/memorization_controller.dart';
import 'package:xadiithapp/features/settings/notification_preferences_controller.dart';
import 'package:xadiithapp/features/settings/presentation/notification_settings_screen.dart';

import '../../support/test_library.dart';

/// Device stand-in: records permission prompts and scheduled reminders.
class FakeGateway implements NotificationGateway {
  FakeGateway({this.granted = false, this.grantOnRequest = true, this.launch});

  bool granted;
  bool grantOnRequest;
  String? launch;
  int requests = 0;
  int settingsOpened = 0;
  int replaceCalls = 0;
  List<PlannedReminder> scheduled = const [];
  void Function(String payload)? tap;

  @override
  bool get isSupported => true;
  @override
  Future<void> initialize(void Function(String payload) onTap) async => tap = onTap;
  @override
  Future<String?> launchPayload() async => launch;
  @override
  Future<bool> permissionGranted() async => granted;
  @override
  Future<bool> requestPermission() async {
    requests++;
    granted = grantOnRequest;
    return granted;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    replaceCalls++;
    scheduled = List.of(reminders);
  }

  List<PlannedReminder> of(ReminderKind k) => scheduled.where((r) => r.kind == k).toList();
}

// 10:00 on 18 Nov 2026 (local).
DateTime _now = DateTime(2026, 11, 18, 10);

Future<(ReminderService, FakeGateway, MemorizationController, NotificationPreferencesController)> _setUp({
  FakeGateway? gateway,
  Map<String, Object> store = const {},
}) async {
  final repo = testRepository();
  final settings = InMemorySettingsStore({...store});
  final prefs = NotificationPreferencesController(settings);
  await prefs.load();
  final ids = [for (final h in repo.allHadiths) h.id];
  final memo = MemorizationController(settings, candidateIds: ids, clock: () => _now);
  await memo.load();
  final g = gateway ?? FakeGateway(granted: true);
  final service = ReminderService(
    gateway: g,
    preferences: prefs,
    memorization: memo,
    repository: repo,
    clock: () => _now,
  );
  await service.start();
  await service.flush();
  return (service, g, memo, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => _now = DateTime(2026, 11, 18, 10));

  group('Permission', () {
    test('asked once when a reminder is first enabled; granted → scheduled', () async {
      final g = FakeGateway(granted: false, grantOnRequest: true);
      final (s, _, _, prefs) = await _setUp(gateway: g);
      expect(g.requests, 0, reason: 'never asked at app start');
      expect(await s.enable(ReminderKind.memorization), ReminderEnableResult.enabled);
      await s.flush();
      expect(g.requests, 1);
      expect(prefs.permissionAsked, isTrue);
      expect(g.of(ReminderKind.memorization), isNotEmpty);
    });

    test('denied → stays off, no repeated prompt, Settings offered by the UI', () async {
      final g = FakeGateway(granted: false, grantOnRequest: false);
      final (s, _, _, prefs) = await _setUp(gateway: g);
      expect(await s.enable(ReminderKind.review), ReminderEnableResult.denied);
      expect(await s.enable(ReminderKind.review), ReminderEnableResult.denied);
      expect(g.requests, 1, reason: 'the prompt is shown only once');
      expect(prefs.isEnabled(ReminderKind.review), isFalse);
      await s.openSettings();
      expect(g.settingsOpened, 1);
    });

    test('permission revoked in Settings → nothing scheduled', () async {
      final (s, g, _, _) = await _setUp();
      await s.enable(ReminderKind.memorization);
      await s.flush();
      expect(g.scheduled, isNotEmpty);
      g.granted = false;
      await s.flush();
      expect(g.scheduled, isEmpty);
    });
  });

  group('Hadith of the day (shown in the app only)', () {
    test('never sends a notification, even when asked to enable it', () async {
      final (s, g, _, prefs) = await _setUp();
      await s.enable(ReminderKind.dailyHadith);
      await s.flush();
      expect(prefs.isEnabled(ReminderKind.dailyHadith), isFalse);
      expect(g.of(ReminderKind.dailyHadith), isEmpty);
      expect(ReminderKind.offered, isNot(contains(ReminderKind.dailyHadith)));
    });

    test('an "on" flag from an older version is switched off', () async {
      final (s, g, _, prefs) = await _setUp(store: {'notifications.dailyHadith': true});
      await s.flush();
      expect(prefs.isEnabled(ReminderKind.dailyHadith), isFalse);
      expect(g.of(ReminderKind.dailyHadith), isEmpty);
    });

    test('memorization: changing the time reschedules; disabling removes; enabling again restores', () async {
      final (s, g, _, _) = await _setUp();
      await s.enable(ReminderKind.memorization);
      await s.setTime(ReminderKind.memorization, const TimeOfDay(hour: 21, minute: 30));
      await s.flush();
      expect(g.of(ReminderKind.memorization).first.at, DateTime(2026, 11, 18, 21, 30), reason: 'today, still ahead');
      await s.disable(ReminderKind.memorization);
      await s.flush();
      expect(g.of(ReminderKind.memorization), isEmpty);
      await s.enable(ReminderKind.memorization);
      await s.flush();
      expect(g.of(ReminderKind.memorization), isNotEmpty);
    });
  });

  group('Daily hadith order', () {
    test('first day → hadith 1, then 2, 3 … and back to 1 after the last', () {
      final repo = testRepository();
      final order = [for (final b in repo.books) ...repo.readingOrderOf(b.id)];
      repo.dailyStart = DateTime(2026, 11, 18);
      expect(repo.dailyHadith(DateTime(2026, 11, 18))!.id, order[0].id);
      expect(repo.dailyHadith(DateTime(2026, 11, 19, 23, 59))!.id, order[1].id);
      expect(repo.dailyHadith(DateTime(2026, 11, 20))!.id, order[2].id);
      final afterLast = DateTime(2026, 11, 18 + order.length);
      expect(repo.dailyHadith(afterLast)!.id, order[0].id, reason: 'starts again from hadith 1');
    });

    test('the first day is saved on first use and kept', () async {
      final store = InMemorySettingsStore();
      final first = await AppServices.loadDailyStart(store, DateTime(2026, 11, 18, 15));
      expect(first, DateTime(2026, 11, 18));
      final later = await AppServices.loadDailyStart(store, DateTime(2026, 12, 1));
      expect(later, DateTime(2026, 11, 18), reason: 'not reset on later launches');
    });
  });

  group('Memorization (real plan data)', () {
    test('today\'s plan incomplete → reminder today; completing it cancels today\'s only', () async {
      final (s, g, memo, _) = await _setUp();
      await s.enable(ReminderKind.memorization); // 19:00
      await s.flush();
      expect(g.of(ReminderKind.memorization).first.at, DateTime(2026, 11, 18, 19));
      expect(g.of(ReminderKind.memorization).first.payload, AppRoutes.memorizationPlan);
      for (final id in memo.todayPlan) {
        await memo.markMemorized(id);
      }
      expect(memo.isTodayComplete, isTrue);
      await s.flush();
      final memoReminders = g.of(ReminderKind.memorization);
      expect(memoReminders.any((r) => r.at.day == 18), isFalse, reason: 'plan done → no reminder today');
      expect(memoReminders.first.at, DateTime(2026, 11, 19, 19), reason: 'tomorrow has a new plan');
    });

    test('nothing left to memorise → no memorization reminders', () async {
      final (s, g, memo, _) = await _setUp();
      await memo.setDailyTarget(10);
      while (memo.todayPlan.any((id) => !memo.isMemorized(id))) {
        for (final id in memo.todayPlan) {
          await memo.markMemorized(id);
        }
        _now = _now.add(const Duration(days: 1));
      }
      await s.enable(ReminderKind.memorization);
      await s.flush();
      expect(memo.hasUnmemorizedLeft, isFalse);
      expect(g.of(ReminderKind.memorization), isEmpty);
    });
  });

  group('Revision (real review schedule)', () {
    test('no memorised hadith → no revision reminders', () async {
      final (s, g, _, _) = await _setUp();
      await s.enable(ReminderKind.review);
      await s.flush();
      expect(g.of(ReminderKind.review), isEmpty);
    });

    test('reminders only on days with pending reviews, with the count; completing them updates', () async {
      final (s, g, memo, _) = await _setUp();
      final id = memo.todayPlan.first;
      await memo.markMemorized(id); // first review is due later
      await s.enable(ReminderKind.review); // 17:00
      await s.flush();
      final reviews = g.of(ReminderKind.review);
      expect(reviews, isNotEmpty);
      for (final r in reviews) {
        expect(
          memo.dueCountOn(
            '${r.at.year}-${r.at.month.toString().padLeft(2, '0')}-${r.at.day.toString().padLeft(2, '0')}',
          ),
          greaterThan(0),
        );
        expect(r.payload, AppRoutes.memorizationReview);
        expect(r.body, contains('1 xadiis'));
      }
      final firstDue = reviews.first.at;
      expect(firstDue.isAfter(DateTime(2026, 11, 18, 17)), isTrue, reason: 'nothing due today');

      await memo.markForReview(id); // due now
      await s.flush();
      expect(g.of(ReminderKind.review).first.at, DateTime(2026, 11, 18, 17));
      await memo.completeReview(id);
      await s.flush();
      expect(g.of(ReminderKind.review).any((r) => r.at.day == 18), isFalse, reason: 'review done today');
    });
  });

  group('No duplicates', () {
    test('ids are unique and stable; replanning replaces instead of adding', () async {
      final (s, g, memo, _) = await _setUp();
      await memo.markMemorized(memo.todayPlan.first);
      await memo.markForReview(memo.todayPlan.first);
      for (final k in ReminderKind.values) {
        await s.enable(k);
      }
      await s.flush();
      final first = g.scheduled.map((r) => r.id).toList();
      expect(first.toSet().length, first.length);
      expect(first.every(ReminderPlanner.allIds.contains), isTrue);
      await s.flush();
      await s.flush();
      expect(g.scheduled.map((r) => r.id).toList(), first, reason: 'same plan, same ids');
      expect(g.scheduled.every((r) => r.at.isAfter(_now)), isTrue, reason: 'never in the past');
    });

    test('a burst of changes is coalesced into few replans', () async {
      final (s, g, _, _) = await _setUp();
      await s.enable(ReminderKind.dailyHadith);
      await s.flush();
      final before = g.replaceCalls;
      for (var i = 0; i < 10; i++) {
        s.reschedule();
      }
      await s.flush();
      expect(g.replaceCalls - before, lessThanOrEqualTo(2));
    });
  });

  group('Tapping a reminder', () {
    test('opens the payload route; arrives before the router → delivered on attach', () async {
      final (s, g, _, _) = await _setUp();
      final opened = <String>[];
      g.tap!('/hadith/nawawi40-7');
      s.attachNavigator(opened.add);
      g.tap!(AppRoutes.memorizationReview);
      g.tap!('https://evil.example'); // not an app route → ignored
      expect(opened, ['/hadith/nawawi40-7', AppRoutes.memorizationReview]);
    });

    test('launch from a notification gives the start route (validated)', () async {
      final (s, _, _, _) = await _setUp(gateway: FakeGateway(granted: true, launch: AppRoutes.memorizationPlan));
      expect(await s.launchRoute(), AppRoutes.memorizationPlan);
      final (s2, _, _, _) = await _setUp(gateway: FakeGateway(granted: true, launch: 'javascript:x'));
      expect(await s2.launchRoute(), isNull);
    });

    testWidgets('tap navigates to the hadith page inside the app', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final g = FakeGateway(granted: true);
      final services = await createTestServices(
        InMemorySettingsStore({'auth.onboardingSeen': true}),
        notificationGateway: g,
      );
      await services.reminders.start();
      await tester.pumpWidget(XadiisApp(services: services, initialLocation: AppRoutes.home));
      await tester.pumpAndSettle();
      final id = services.repository.allHadiths.first.id;
      g.tap!(AppRoutes.hadith(id));
      await tester.pumpAndSettle();
      expect(find.text('Tarjumaadda Af Soomaaliga'), findsOneWidget, reason: 'hadith detail is open');
    });
  });

  testWidgets('settings: denied permission shows a short message with a Settings button', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final g = FakeGateway(granted: false, grantOnRequest: false);
    final services = await createTestServices(
      InMemorySettingsStore({'auth.onboardingSeen': true}),
      notificationGateway: g,
    );
    await tester.pumpWidget(XadiisApp(services: services, initialLocation: AppRoutes.settingsNotifications));
    await tester.pumpAndSettle();
    expect(find.text(NotificationSettingsScreen.unsupportedNotice), findsNothing);
    await tester.tap(find.text(ReminderKind.memorization.label));
    await tester.pumpAndSettle();
    expect(find.text(NotificationSettingsScreen.deniedMessage), findsOneWidget);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Settings'));
    await tester.pumpAndSettle();
    expect(g.settingsOpened, 1);
    expect(services.notifications.isEnabled(ReminderKind.memorization), isFalse);
    expect(find.byType(AppCard), findsWidgets);
  });
}
