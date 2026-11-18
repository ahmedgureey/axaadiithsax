import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/features/memorization/domain/memorization_models.dart';
import 'package:xadiithapp/features/memorization/domain/review_schedule.dart';
import 'package:xadiithapp/features/memorization/memorization_controller.dart';

/// Mutable clock for date-dependent tests.
class _Clock {
  DateTime now = DateTime(2026, 11, 18, 10);
  DateTime call() => now;
  void nextDay([int days = 1]) => now = DateTime(now.year, now.month, now.day + days, 10);
}

const _ids = ['h1', 'h2', 'h3', 'h4', 'h5'];

Future<MemorizationController> _make({
  SettingsStore? store,
  _Clock? clock,
  List<String> ids = _ids,
  bool Function(String)? exists,
}) async {
  final c = MemorizationController(
    store ?? InMemorySettingsStore(),
    candidateIds: ids,
    clock: (clock ?? _Clock()).call,
    exists: exists,
  );
  await c.load();
  return c;
}

void main() {
  group('Daily plan', () {
    test('first-time defaults have no invented progress', () async {
      final c = await _make();
      expect(c.dailyTarget, MemorizationController.defaultTarget);
      expect(c.todayPlan, ['h1', 'h2', 'h3']);
      expect(c.completedToday, 0);
      expect(c.memorizedCount, 0);
      expect(c.streak, 0);
      expect(c.hasAnyActivity, isFalse);
      expect(c.quizHistory, isEmpty);
    });

    test('daily target is configurable and validated', () async {
      final store = InMemorySettingsStore();
      final c = await _make(store: store);
      await c.setDailyTarget(5);
      expect(c.todayPlan, hasLength(5));
      await c.setDailyTarget(7); // not an option → default
      expect(c.dailyTarget, MemorizationController.defaultTarget);
      await c.setDailyTarget(1);
      final restored = await _make(store: store);
      expect(restored.dailyTarget, 1);
    });

    test('mark, duplicate prevention, undo and progress', () async {
      final c = await _make();
      expect(await c.markMemorized('h1'), isTrue);
      expect(await c.markMemorized('h1'), isFalse, reason: 'no duplicate record');
      expect(c.completedToday, 1);
      expect(c.dailyProgress, closeTo(1 / 3, 0.001));
      expect(c.todayPlan, ['h1', 'h2', 'h3'], reason: 'completed items stay in today\'s plan');
      expect(c.nextPlanned(), 'h2');
      expect(c.nextPlanned(afterId: 'h2'), 'h3');

      expect(await c.undoMemorized('h1'), isTrue);
      expect(c.completedToday, 0);
      expect(c.isMemorized('h1'), isFalse);
      expect(await c.undoMemorized('h1'), isFalse);
    });

    test('completing the plan; a new day brings new items', () async {
      final clock = _Clock();
      final c = await _make(clock: clock);
      for (final id in c.todayPlan.toList()) {
        await c.markMemorized(id);
      }
      expect(c.isTodayComplete, isTrue);
      expect(c.nextPlanned(), isNull);

      clock.nextDay();
      expect(c.completedToday, 0);
      expect(c.todayPlan, ['h4', 'h5'], reason: 'only two left — plan is shorter, nothing invented');
      expect(c.planLimitedByData, isTrue);
    });

    test('target larger than data is handled', () async {
      final c = await _make(ids: ['only']);
      await c.setDailyTarget(10);
      expect(c.todayPlan, ['only']);
      expect(c.planLimitedByData, isTrue);
    });
  });

  group('Reviews', () {
    test('schedule: due after 1 day, then 3 days; no double completion', () async {
      final clock = _Clock();
      final c = await _make(clock: clock);
      await c.markMemorized('h1');
      expect(c.dueForReview, isEmpty, reason: 'not due on the same day');

      clock.nextDay();
      expect(c.dueForReview.map((r) => r.hadithId), ['h1']);
      expect(await c.completeReview('h1'), isTrue);
      expect(await c.completeReview('h1'), isFalse, reason: 'rebuilds/double taps do not count twice');
      expect(c.reviewsCompletedToday, 1);
      expect(c.recordOf('h1')!.stage, 1);
      expect(c.recordOf('h1')!.nextReviewOn, LocalDay.add(LocalDay.of(clock.now), 3));

      clock.nextDay(2);
      expect(c.dueForReview, isEmpty);
      clock.nextDay();
      expect(c.dueForReview, hasLength(1));
    });

    test('mark for review makes it due now; completing clears the flag', () async {
      final c = await _make();
      await c.markMemorized('h1');
      expect(await c.markForReview('h1'), isTrue);
      expect(await c.markForReview('h1'), isFalse);
      expect(c.dueForReview, hasLength(1));
      await c.completeReview('h1');
      expect(c.recordOf('h1')!.flagged, isFalse);
      expect(c.dueForReview, isEmpty);
      expect(await c.markForReview('never-memorized'), isFalse);
    });

    test('day boundary is local midnight', () async {
      final clock = _Clock()..now = DateTime(2026, 11, 18, 23, 59);
      final c = await _make(clock: clock);
      await c.markMemorized('h1');
      clock.now = DateTime(2026, 11, 19, 0, 1);
      expect(c.dueForReview, hasLength(1));
      expect(c.completedToday, 0);
    });

    test('schedule is configurable and described honestly', () {
      const s = ReviewSchedule([2, 5]);
      expect(s.nextDue('2026-11-18', 0), '2026-11-20');
      expect(s.nextDue('2026-11-18', 9), '2026-11-23', reason: 'last interval repeats');
      expect(const ReviewSchedule().description, contains('1 → 3 → 7 → 14 → 30'));
    });
  });

  group('Activity', () {
    test('streak counts consecutive active days only', () async {
      final clock = _Clock();
      final c = await _make(clock: clock);
      await c.markMemorized('h1');
      clock.nextDay();
      await c.markMemorized('h2');
      expect(c.streak, 2);
      clock.nextDay();
      expect(c.streak, 2, reason: 'today not active yet — streak still alive');
      clock.nextDay();
      expect(c.streak, 0);
    });

    test('weekly activity reflects recorded events', () async {
      final c = await _make();
      await c.markMemorized('h1');
      await c.recordQuiz(total: 5, correct: 4);
      final days = c.recentDays();
      expect(days, hasLength(7));
      expect(days.last.$2.memorized, 1);
      expect(days.last.$2.quizzes, 1);
      expect(days.first.$2.isEmpty, isTrue);
    });

    test('quiz history: newest first, zero-question quizzes ignored', () async {
      final c = await _make();
      await c.recordQuiz(total: 0, correct: 0);
      expect(c.quizHistory, isEmpty);
      await c.recordQuiz(total: 5, correct: 3, seconds: 40);
      await c.recordQuiz(total: 10, correct: 10);
      expect(c.quizHistory.map((q) => q.percentage), [100, 60]);
    });
  });

  group('Persistence', () {
    test('restores after restart', () async {
      final store = InMemorySettingsStore();
      final clock = _Clock();
      final c = await _make(store: store, clock: clock);
      await c.setDailyTarget(5);
      await c.markMemorized('h2');
      await c.recordQuiz(total: 5, correct: 2);

      final restored = await _make(store: store, clock: clock);
      expect(restored.dailyTarget, 5);
      expect(restored.isMemorized('h2'), isTrue);
      expect(restored.completedToday, 1);
      expect(restored.quizHistory.single.correct, 2);
    });

    test('corrupted storage falls back to defaults and reports it', () async {
      final c = await _make(store: InMemorySettingsStore({MemorizationController.storageKey: '{not json'}));
      expect(c.loadFailed, isTrue);
      expect(c.memorizedCount, 0);
      expect(c.dailyTarget, MemorizationController.defaultTarget);
    });

    test('outdated hadith IDs are ignored in counts and reviews', () async {
      final store = InMemorySettingsStore();
      final clock = _Clock();
      final c = await _make(store: store, clock: clock);
      await c.markMemorized('ghost');
      await c.markMemorized('h1');
      clock.nextDay();
      final filtered = await _make(store: store, clock: clock, exists: (id) => id != 'ghost');
      expect(filtered.memorizedCount, 1);
      expect(filtered.dueForReview.map((r) => r.hadithId), ['h1']);
    });
  });
}
