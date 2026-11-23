import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';
import 'domain/memorization_models.dart';
import 'domain/review_schedule.dart';

/// Single source of truth for memorisation progress, reviews and quiz
/// history. Everything shown on the dashboard is computed from recorded
/// activity — nothing is pre-filled.
///
/// Persisted as one JSON document in the app's existing `SettingsStore`.
class MemorizationController extends ChangeNotifier {
  MemorizationController(
    this._store, {
    List<String> candidateIds = const [],
    this.candidatesProvider,
    bool Function(String id)? exists,
    DateTime Function()? clock,
    this.schedule = const ReviewSchedule(),
  }) : _fixedCandidates = List.unmodifiable(candidateIds),
       _exists = exists ?? ((_) => true),
       _clock = clock ?? DateTime.now;

  static const storageKey = 'memorization.v1';
  static const targetOptions = [1, 3, 5, 10];
  static const defaultTarget = 3;
  static const maxQuizHistory = 30;

  final SettingsStore _store;

  /// All hadith IDs that can be memorised, in reading order. With a backend
  /// the provider returns the records loaded so far (the list grows as the
  /// user browses); offline/bundled data uses the fixed list.
  final List<String> _fixedCandidates;
  final List<String> Function()? candidatesProvider;
  List<String> get _candidates => candidatesProvider?.call() ?? _fixedCandidates;
  final bool Function(String id) _exists;
  final DateTime Function() _clock;
  final ReviewSchedule schedule;

  int _target = defaultTarget;
  final LinkedHashMap<String, MemorizationRecord> _records = LinkedHashMap();
  final Map<String, DayActivity> _activity = {};
  final List<QuizAttempt> _quizzes = [];
  bool _loaded = false;
  bool _loadFailed = false;

  // ── Basic state ──────────────────────────────────────────────────────────
  bool get isLoaded => _loaded;
  bool get loadFailed => _loadFailed;
  String get today => LocalDay.of(_clock());
  int get dailyTarget => _target;
  bool isMemorized(String id) => _records.containsKey(id);
  MemorizationRecord? recordOf(String id) => _records[id];

  /// Records whose hadith still exists (outdated IDs are ignored).
  Iterable<MemorizationRecord> get _validRecords => _records.values.where((r) => _exists(r.hadithId));

  int get memorizedCount => _validRecords.length;
  int get totalAvailable => _candidates.length;
  double get overallProgress => totalAvailable == 0 ? 0 : memorizedCount / totalAvailable;

  // ── Daily plan ───────────────────────────────────────────────────────────
  List<String> get _memorizedToday => [
    for (final r in _validRecords)
      if (r.memorizedOn == today) r.hadithId,
  ];

  int get completedToday => _memorizedToday.length;

  /// Today's plan: what was already memorised today, topped up with the next
  /// unmemorised hadith (reading order) until the target is reached. Never
  /// invents items — it may be shorter than the target when data runs out.
  List<String> get todayPlan {
    final done = _memorizedToday;
    final remaining = math.max(0, _target - done.length);
    final next = _candidates.where((id) => !_records.containsKey(id) && _exists(id)).take(remaining);
    return [...done, ...next];
  }

  /// Planned items for today (≤ target when data is short).
  int get plannedToday => math.max(todayPlan.length, completedToday);

  /// True when the target can't be met because no unmemorised hadith remain.
  bool get planLimitedByData => todayPlan.length < _target;

  bool get isTodayComplete => plannedToday > 0 && todayPlan.every(isMemorized);

  double get dailyProgress => plannedToday == 0 ? 0 : math.min(1, completedToday / plannedToday);

  /// Next unmemorised item in today's plan (after [afterId] if given).
  String? nextPlanned({String? afterId}) {
    final plan = todayPlan;
    final start = afterId == null ? 0 : plan.indexOf(afterId) + 1;
    for (var i = 0; i < plan.length; i++) {
      final id = plan[(start + i) % plan.length];
      if (!isMemorized(id) && id != afterId) return id;
    }
    return null;
  }

  Future<void> setDailyTarget(int target) async {
    final t = targetOptions.contains(target) ? target : defaultTarget;
    if (t == _target) return;
    _target = t;
    notifyListeners();
    await _persist();
  }

  /// Marks [id] memorised today. Returns false (no-op) if already memorised,
  /// so repeated taps or rebuilds never create duplicate records.
  Future<bool> markMemorized(String id) async {
    if (_records.containsKey(id)) return false;
    final day = today;
    _records[id] = MemorizationRecord(hadithId: id, memorizedOn: day, stage: 0, nextReviewOn: schedule.nextDue(day, 0));
    _day(day).memorized++;
    notifyListeners();
    await _persist();
    return true;
  }

  /// Undoes memorisation (e.g. tapped by mistake).
  Future<bool> undoMemorized(String id) async {
    final record = _records.remove(id);
    if (record == null) return false;
    final act = _activity[record.memorizedOn];
    if (act != null && act.memorized > 0) act.memorized--;
    notifyListeners();
    await _persist();
    return true;
  }

  // ── Reviews ──────────────────────────────────────────────────────────────
  bool isDue(MemorizationRecord r) => r.flagged || r.nextReviewOn.compareTo(today) <= 0;

  /// Memorised hadith due for review, earliest first.
  List<MemorizationRecord> get dueForReview =>
      _validRecords.where(isDue).toList()..sort((a, b) => a.nextReviewOn.compareTo(b.nextReviewOn));

  int get reviewsCompletedToday => _activity[today]?.reviewed ?? 0;

  /// Completes a due review and schedules the next one. Returns false if the
  /// item isn't due (prevents double counting).
  Future<bool> completeReview(String id) async {
    final r = _records[id];
    if (r == null || !isDue(r)) return false;
    final stage = r.stage + 1;
    _records[id] = r.copyWith(
      stage: stage,
      lastReviewedOn: today,
      nextReviewOn: schedule.nextDue(today, stage),
      flagged: false,
    );
    _day(today).reviewed++;
    notifyListeners();
    await _persist();
    return true;
  }

  /// Puts a memorised hadith (back) on the review list now.
  Future<bool> markForReview(String id) async {
    final r = _records[id];
    if (r == null || r.flagged) return false;
    _records[id] = r.copyWith(flagged: true);
    notifyListeners();
    await _persist();
    return true;
  }

  // ── History, streak, chart ───────────────────────────────────────────────
  /// Most recently memorised first.
  List<MemorizationRecord> get recentlyMemorized => _validRecords.toList().reversed.toList();

  /// Consecutive days with recorded activity, ending today (or yesterday if
  /// nothing happened yet today). 0 when nothing has been recorded.
  int get streak {
    var day = today;
    if (_activity[day]?.isEmpty ?? true) day = LocalDay.add(day, -1);
    var count = 0;
    while (!(_activity[day]?.isEmpty ?? true)) {
      count++;
      day = LocalDay.add(day, -1);
    }
    return count;
  }

  bool get hasAnyActivity => _activity.values.any((a) => !a.isEmpty);

  /// Last [days] days, oldest first: (day, activity).
  List<(String, DayActivity)> recentDays([int days = 7]) => [
    for (var i = days - 1; i >= 0; i--) (LocalDay.add(today, -i), _activity[LocalDay.add(today, -i)] ?? DayActivity()),
  ];

  List<QuizAttempt> get quizHistory => List.unmodifiable(_quizzes);

  Future<void> recordQuiz({required int total, required int correct, int? seconds}) async {
    if (total <= 0) return;
    _quizzes.insert(0, QuizAttempt(day: today, total: total, correct: correct.clamp(0, total), seconds: seconds));
    if (_quizzes.length > maxQuizHistory) _quizzes.removeRange(maxQuizHistory, _quizzes.length);
    _day(today).quizzes++;
    notifyListeners();
    await _persist();
  }

  DayActivity _day(String day) => _activity.putIfAbsent(day, DayActivity.new);

  // ── Persistence ──────────────────────────────────────────────────────────
  /// Deletes all memorisation progress, reviews and quiz history.
  Future<void> reset() async {
    _records.clear();
    _activity.clear();
    _quizzes.clear();
    _target = defaultTarget;
    _loadFailed = false;
    notifyListeners();
    try {
      await _store.remove(storageKey);
    } catch (_) {}
  }

  Future<void> load() async {
    _records.clear();
    _activity.clear();
    _quizzes.clear();
    _target = defaultTarget;
    try {
      final raw = await _store.getString(storageKey);
      if (raw != null) _decode(raw);
      _loadFailed = false;
    } catch (_) {
      // Unreadable storage: start fresh but tell the UI.
      _records.clear();
      _activity.clear();
      _quizzes.clear();
      _target = defaultTarget;
      _loadFailed = true;
    }
    _loaded = true;
    notifyListeners();
  }

  void _decode(String raw) {
    final json = jsonDecode(raw) as Map<String, Object?>;
    final t = (json['target'] as num?)?.toInt();
    _target = targetOptions.contains(t) ? t! : defaultTarget;
    for (final r in (json['records'] as List? ?? const [])) {
      final record = MemorizationRecord.fromJson((r as Map).cast<String, Object?>());
      _records.putIfAbsent(record.hadithId, () => record); // never duplicate
    }
    (json['activity'] as Map? ?? const {}).forEach((day, a) {
      _activity[day as String] = DayActivity.fromJson((a as Map).cast<String, Object?>());
    });
    for (final q in (json['quiz'] as List? ?? const [])) {
      _quizzes.add(QuizAttempt.fromJson((q as Map).cast<String, Object?>()));
    }
  }

  Future<void> _persist() async {
    final json = jsonEncode({
      'v': 1,
      'target': _target,
      'records': [for (final r in _records.values) r.toJson()],
      'activity': {
        for (final e in _activity.entries)
          if (!e.value.isEmpty) e.key: e.value.toJson(),
      },
      'quiz': [for (final q in _quizzes) q.toJson()],
    });
    try {
      await _store.setString(storageKey, json);
    } catch (_) {
      // Best effort: in-memory progress stays correct this session.
    }
  }
}
