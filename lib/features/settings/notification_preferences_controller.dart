import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';

/// The reminders the app can schedule on the device. Each one is checked
/// against the app's real data before it is scheduled (see
/// `ReminderPlanner`).
enum ReminderKind {
  dailyHadith('Xadiiska maalinta', 'Maalin kasta xadiiska maanta', TimeOfDay(hour: 8, minute: 0)),
  memorization('Xasuusinta xifdinta', 'Haddii qorshaha maanta aan la dhammaystirin', TimeOfDay(hour: 19, minute: 0)),
  review('Xasuusinta dib-u-eegista', 'Marka xadiisyo dib-u-eegis sugayaan', TimeOfDay(hour: 17, minute: 0));

  const ReminderKind(this.label, this.description, this.defaultTime);
  final String label;
  final String description;
  final TimeOfDay defaultTime;

  /// The hadith of the day is shown only inside the app (no notification).
  bool get available => this != ReminderKind.dailyHadith;

  /// Reminders offered in the settings.
  static List<ReminderKind> get offered => [
    for (final k in values)
      if (k.available) k,
  ];
}

/// Reminder preferences (on/off and time per reminder), persisted locally.
/// Scheduling is done by `ReminderService`, which listens to this.
class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController(this._store);

  static const _prefix = 'notifications.';

  /// Time key of the daily hadith (kept from the single-time version).
  static const _legacyTimeKey = 'notifications.time';

  /// Set once the system permission prompt was shown (never asked again).
  static const permissionAskedKey = 'notifications.permissionAsked';

  final SettingsStore _store;
  final Map<ReminderKind, bool> _enabled = {for (final k in ReminderKind.values) k: false};
  final Map<ReminderKind, TimeOfDay> _times = {for (final k in ReminderKind.values) k: k.defaultTime};
  bool _permissionAsked = false;

  bool isEnabled(ReminderKind kind) => _enabled[kind] ?? false;
  TimeOfDay timeOf(ReminderKind kind) => _times[kind] ?? kind.defaultTime;
  int get enabledCount => _enabled.values.where((v) => v).length;
  bool get permissionAsked => _permissionAsked;

  /// Time of the daily hadith reminder (compatibility getter).
  TimeOfDay get reminderTime => timeOf(ReminderKind.dailyHadith);

  static String _timeKey(ReminderKind k) => k == ReminderKind.dailyHadith ? _legacyTimeKey : '$_prefix${k.name}.time';

  Future<void> load() async {
    try {
      for (final k in ReminderKind.values) {
        _enabled[k] = await _store.getBool('$_prefix${k.name}') ?? false;
        _times[k] = parseTime(await _store.getString(_timeKey(k))) ?? k.defaultTime;
      }
      _permissionAsked = await _store.getBool(permissionAskedKey) ?? false;
      // The hadith of the day no longer sends a notification: switch it off.
      if (_enabled[ReminderKind.dailyHadith] == true) {
        _enabled[ReminderKind.dailyHadith] = false;
        await _store.remove('$_prefix${ReminderKind.dailyHadith.name}');
      }
      // The removed "app news" reminder needed a server; clear its old flag.
      await _store.remove('${_prefix}announcements');
    } catch (_) {
      // Keep defaults (everything off) if storage is unreadable.
    }
    notifyListeners();
  }

  Future<void> setEnabled(ReminderKind kind, bool value) async {
    if (value && !kind.available) return;
    if (_enabled[kind] == value) return;
    _enabled[kind] = value;
    notifyListeners();
    await _safe(() => _store.setBool('$_prefix${kind.name}', value));
  }

  Future<void> setTime(ReminderKind kind, TimeOfDay time) async {
    _times[kind] = time;
    notifyListeners();
    await _safe(() => _store.setString(_timeKey(kind), formatTime(time)));
  }

  /// Daily hadith time (compatibility).
  Future<void> setReminderTime(TimeOfDay time) => setTime(ReminderKind.dailyHadith, time);

  Future<void> markPermissionAsked() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    await _safe(() => _store.setBool(permissionAskedKey, true));
  }

  Future<void> reset() async {
    for (final k in ReminderKind.values) {
      _enabled[k] = false;
      _times[k] = k.defaultTime;
    }
    notifyListeners();
    await _safe(() async {
      for (final k in ReminderKind.values) {
        await _store.remove('$_prefix${k.name}');
        await _store.remove(_timeKey(k));
      }
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
