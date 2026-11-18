import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';

enum ReminderKind {
  dailyHadith('Xadiiska maalinta', 'Xasuusin maalinle ah oo ku tusaysa xadiiska maanta'),
  memorization('Xasuusinta xifdinta', 'Xasuusin si aad u gaarto hadafkaaga maalinlaha ah'),
  review('Xasuusinta dib-u-eegista', 'Marka xadiisyo dib-u-eegis sugayaan'),
  announcements('Wararka app-ka', 'Cusboonaysiinta iyo astaamaha cusub');

  const ReminderKind(this.label, this.description);
  final String label;
  final String description;
}

/// Notification PREFERENCES only. The app has no notification service yet,
/// so nothing is scheduled or delivered and no system permission is
/// requested — the UI says so explicitly.
class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController(this._store);

  static const defaultTime = TimeOfDay(hour: 8, minute: 0);
  static const _prefix = 'notifications.';
  static const _timeKey = 'notifications.time';

  final SettingsStore _store;
  final Map<ReminderKind, bool> _enabled = {for (final k in ReminderKind.values) k: false};
  TimeOfDay _time = defaultTime;

  bool isEnabled(ReminderKind kind) => _enabled[kind] ?? false;
  TimeOfDay get reminderTime => _time;
  int get enabledCount => _enabled.values.where((v) => v).length;

  Future<void> load() async {
    try {
      for (final k in ReminderKind.values) {
        _enabled[k] = await _store.getBool('$_prefix${k.name}') ?? false;
      }
      _time = parseTime(await _store.getString(_timeKey)) ?? defaultTime;
    } catch (_) {
      // Keep defaults (everything off) if storage is unreadable.
    }
    notifyListeners();
  }

  Future<void> setEnabled(ReminderKind kind, bool value) async {
    if (_enabled[kind] == value) return;
    _enabled[kind] = value;
    notifyListeners();
    await _safe(() => _store.setBool('$_prefix${kind.name}', value));
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    _time = time;
    notifyListeners();
    await _safe(() => _store.setString(_timeKey, formatTime(time)));
  }

  Future<void> reset() async {
    for (final k in ReminderKind.values) {
      _enabled[k] = false;
    }
    _time = defaultTime;
    notifyListeners();
    await _safe(() async {
      for (final k in ReminderKind.values) {
        await _store.remove('$_prefix${k.name}');
      }
      await _store.remove(_timeKey);
    });
  }

  static String formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Parses "HH:mm"; returns null for missing or corrupted values.
  static TimeOfDay? parseTime(String? s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s ?? '');
    if (m == null) return null;
    final h = int.parse(m[1]!), min = int.parse(m[2]!);
    if (h > 23 || min > 59) return null;
    return TimeOfDay(hour: h, minute: min);
  }

  Future<void> _safe(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {}
  }
}
