import 'package:flutter/material.dart';

import '../../data/models/hadith.dart';
import '../../features/memorization/domain/memorization_models.dart';
import '../../features/settings/notification_preferences_controller.dart';
import '../routing/app_routes.dart';

/// One notification to schedule on the device.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  /// Unique per kind and day ([ReminderPlanner.idFor]).
  final int id;
  final ReminderKind kind;

  /// Local wall-clock time.
  final DateTime at;
  final String title;
  final String body;

  /// Route opened when the notification is tapped.
  final String payload;

  @override
  String toString() => 'PlannedReminder($id, ${kind.name}, $at, $payload)';
}

/// The app data the planner reads (real data, no placeholders).
abstract class ReminderData {
  /// Hadith of the day for a calendar day (same rule as the Home screen).
  Hadith? dailyHadith(DateTime day);

  /// Display name of a collection.
  String? bookName(String bookId);

  /// Today's memorisation plan has items and all of them are done.
  bool get todayPlanComplete;

  /// Today has a plan (there was something to memorise).
  bool get todayHasPlan;

  /// Unmemorised hadith remain, so future days will have a plan.
  bool get hasUnmemorizedLeft;

  /// Hadith due for review on a day (`yyyy-mm-dd`).
  int dueCountOn(String day);
}

/// Decides which reminders to schedule for the next [days] days.
///
/// Reminders are one-shot per day (not a blind daily repeat), so each one
/// reflects the data at planning time:
/// * hadith of the day: that day's actual hadith (title, excerpt, id);
/// * memorisation: today only if today's plan is NOT complete; later days
///   only while hadith remain to memorise;
/// * revision: only on days with hadith due for review, with the count.
/// The service re-plans whenever the data or the preferences change, when
/// the app resumes and after a reboot, so completed plans/reviews cancel
/// their reminders.
abstract final class ReminderPlanner {
  static const days = 14;

  static const _base = {ReminderKind.dailyHadith: 1000, ReminderKind.memorization: 2000, ReminderKind.review: 3000};

  /// Unique, stable id: kind base + day offset (0 = today).
  static int idFor(ReminderKind kind, int dayOffset) => _base[kind]! + dayOffset;

  /// Every id the app may use (for cancelling).
  static Iterable<int> get allIds sync* {
    for (final k in ReminderKind.values) {
      for (var d = 0; d < days; d++) {
        yield idFor(k, d);
      }
    }
  }

  static List<PlannedReminder> plan({
    required DateTime now,
    required bool Function(ReminderKind) enabled,
    required TimeOfDay Function(ReminderKind) timeOf,
    required ReminderData data,
  }) {
    final result = <PlannedReminder>[];
    final today = DateTime(now.year, now.month, now.day);
    for (var d = 0; d < days; d++) {
      final day = DateTime(today.year, today.month, today.day + d);
      for (final kind in ReminderKind.values) {
        if (!kind.available || !enabled(kind)) continue;
        final t = timeOf(kind);
        final at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
        if (!at.isAfter(now)) continue; // never in the past
        final r = switch (kind) {
          ReminderKind.dailyHadith => _daily(d, day, at, data),
          ReminderKind.memorization => _memorization(d, at, data),
          ReminderKind.review => _review(d, day, at, data),
        };
        if (r != null) result.add(r);
      }
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  static PlannedReminder? _daily(int d, DateTime day, DateTime at, ReminderData data) {
    final h = data.dailyHadith(day);
    if (h == null) return null;
    final book = data.bookName(h.bookId);
    return PlannedReminder(
      id: idFor(ReminderKind.dailyHadith, d),
      kind: ReminderKind.dailyHadith,
      at: at,
      title: 'Xadiiska maalinta${book == null ? '' : ' · $book'}, ${h.displayNumber}',
      body: excerpt(h),
      payload: AppRoutes.hadith(h.id),
    );
  }

  static PlannedReminder? _memorization(int d, DateTime at, ReminderData data) {
    if (d == 0) {
      if (!data.todayHasPlan || data.todayPlanComplete) return null;
    } else if (!data.hasUnmemorizedLeft) {
      return null;
    }
    return PlannedReminder(
      id: idFor(ReminderKind.memorization, d),
      kind: ReminderKind.memorization,
      at: at,
      title: 'Xasuusinta xifdinta',
      body: 'Qorshaha xifdinta maanta weli lama dhammaystirin.',
      payload: AppRoutes.memorizationPlan,
    );
  }

  static PlannedReminder? _review(int d, DateTime day, DateTime at, ReminderData data) {
    final count = data.dueCountOn(LocalDay.of(day));
    if (count <= 0) return null;
    return PlannedReminder(
      id: idFor(ReminderKind.review, d),
      kind: ReminderKind.review,
      at: at,
      title: 'Dib-u-eegis',
      body: count == 1 ? '1 xadiis ayaa dib-u-eegis sugaya.' : '$count xadiis ayaa dib-u-eegis sugaya.',
      payload: AppRoutes.memorizationReview,
    );
  }

  /// Short excerpt: the start of the Prophet's words in the Somali
  /// translation, or the Arabic text when there is no translation.
  static String excerpt(Hadith h, {int max = 110}) {
    var s = h.somaliText ?? h.arabicText;
    final quote = s.indexOf('"');
    if (h.somaliText != null && quote >= 0 && quote < s.length - 1) s = s.substring(quote + 1);
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length <= max) return s;
    final cut = s.lastIndexOf(' ', max);
    return '${s.substring(0, cut > 40 ? cut : max).trimRight()}…';
  }
}
