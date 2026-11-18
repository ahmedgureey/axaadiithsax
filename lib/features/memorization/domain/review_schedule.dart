import 'memorization_models.dart';

/// Simple, transparent review rule — NOT a scientifically validated spaced-
/// repetition algorithm.
///
/// After memorising, a hadith is due again after `intervals[0]` days. Each
/// completed review moves it to the next interval; after the last one the
/// last interval repeats. Defaults: 1 → 3 → 7 → 14 → 30 days.
class ReviewSchedule {
  const ReviewSchedule([this.intervals = const [1, 3, 7, 14, 30]]);

  final List<int> intervals;

  /// Falls back to 1 day if configured with an empty list.
  int intervalForStage(int stage) => intervals.isEmpty ? 1 : intervals[stage.clamp(0, intervals.length - 1)];

  /// Due date after reaching [stage] on [day].
  String nextDue(String day, int stage) => LocalDay.add(day, intervalForStage(stage));

  /// Human-readable description shown in the app.
  String get description => 'Dib-u-eegistu waxay dhacdaa ${intervals.join(' → ')} maalmood kadib.';
}
