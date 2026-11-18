import 'package:flutter/foundation.dart';

/// Calendar-day helpers. Days are stored as local `yyyy-MM-dd` strings so a
/// day boundary is always local midnight and DST never shifts a date.
abstract final class LocalDay {
  static String of(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  static DateTime parse(String day) {
    final p = day.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  /// Calendar arithmetic (uses day components, not 24h steps).
  static String add(String day, int days) {
    final d = parse(day);
    return of(DateTime(d.year, d.month, d.day + days));
  }

  /// Whole days from [from] to [to] (negative if [to] is earlier).
  static int between(String from, String to) => DateTime.utc(
    parse(to).year,
    parse(to).month,
    parse(to).day,
  ).difference(DateTime.utc(parse(from).year, parse(from).month, parse(from).day)).inDays;
}

/// One memorised hadith. Exactly one record per hadith ID.
@immutable
class MemorizationRecord {
  const MemorizationRecord({
    required this.hadithId,
    required this.memorizedOn,
    required this.stage,
    required this.nextReviewOn,
    this.lastReviewedOn,
    this.flagged = false,
  });

  final String hadithId;
  final String memorizedOn;

  /// Number of completed reviews (0 right after memorising).
  final int stage;
  final String nextReviewOn;
  final String? lastReviewedOn;

  /// User asked to see it again regardless of the schedule.
  final bool flagged;

  MemorizationRecord copyWith({int? stage, String? nextReviewOn, String? lastReviewedOn, bool? flagged}) =>
      MemorizationRecord(
        hadithId: hadithId,
        memorizedOn: memorizedOn,
        stage: stage ?? this.stage,
        nextReviewOn: nextReviewOn ?? this.nextReviewOn,
        lastReviewedOn: lastReviewedOn ?? this.lastReviewedOn,
        flagged: flagged ?? this.flagged,
      );

  Map<String, Object?> toJson() => {
    'id': hadithId,
    'on': memorizedOn,
    'stage': stage,
    'next': nextReviewOn,
    'last': lastReviewedOn,
    'flag': flagged,
  };

  static MemorizationRecord fromJson(Map<String, Object?> j) => MemorizationRecord(
    hadithId: j['id']! as String,
    memorizedOn: j['on']! as String,
    stage: (j['stage'] as num?)?.toInt() ?? 0,
    nextReviewOn: j['next']! as String,
    lastReviewedOn: j['last'] as String?,
    flagged: j['flag'] as bool? ?? false,
  );
}

/// Activity counted per local day (drives streak and the weekly chart).
class DayActivity {
  DayActivity({this.memorized = 0, this.reviewed = 0, this.quizzes = 0});

  int memorized;
  int reviewed;
  int quizzes;

  int get total => memorized + reviewed + quizzes;
  bool get isEmpty => total == 0;

  Map<String, Object?> toJson() => {'m': memorized, 'r': reviewed, 'q': quizzes};

  static DayActivity fromJson(Map<String, Object?> j) => DayActivity(
    memorized: (j['m'] as num?)?.toInt() ?? 0,
    reviewed: (j['r'] as num?)?.toInt() ?? 0,
    quizzes: (j['q'] as num?)?.toInt() ?? 0,
  );
}

/// A finished quiz (kept separately from memorisation status).
@immutable
class QuizAttempt {
  const QuizAttempt({required this.day, required this.total, required this.correct, this.seconds});

  final String day;
  final int total;
  final int correct;
  final int? seconds;

  int get percentage => total == 0 ? 0 : (correct * 100 / total).round();

  Map<String, Object?> toJson() => {'day': day, 'total': total, 'correct': correct, 'sec': seconds};

  static QuizAttempt fromJson(Map<String, Object?> j) => QuizAttempt(
    day: j['day']! as String,
    total: (j['total']! as num).toInt(),
    correct: (j['correct']! as num).toInt(),
    seconds: (j['sec'] as num?)?.toInt(),
  );
}
