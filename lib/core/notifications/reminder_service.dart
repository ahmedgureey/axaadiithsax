import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../features/memorization/memorization_controller.dart';
import '../../features/settings/notification_preferences_controller.dart';
import '../routing/app_routes.dart';
import 'notification_gateway.dart';
import 'reminder_planner.dart';

/// Result of turning a reminder on.
enum ReminderEnableResult { enabled, denied, unsupported }

/// Keeps the device's scheduled reminders in step with the app's real data
/// and the user's preferences. UI only calls [enable] / [disable] /
/// [setTime] and [openSettings]; everything else happens here.
class ReminderService with WidgetsBindingObserver {
  ReminderService({
    required this.gateway,
    required this.preferences,
    required MemorizationController memorization,
    required HadithRepository repository,
    DateTime Function()? clock,
  }) : _data = _AppReminderData(repository, memorization),
       _memorization = memorization,
       _clock = clock ?? DateTime.now;

  final NotificationGateway gateway;
  final NotificationPreferencesController preferences;
  final MemorizationController _memorization;
  final _AppReminderData _data;
  final DateTime Function() _clock;

  void Function(String route)? _navigator;
  String? _pendingRoute;
  bool _started = false;
  Future<void> _queue = Future.value();
  bool _dirty = false;

  /// Reminders scheduled by the last plan (for tests and diagnostics).
  List<PlannedReminder> lastPlan = const [];

  bool get isSupported => gateway.isSupported;

  /// Initialises the plugin, listens for changes and schedules once.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await gateway.initialize(_onTap);
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
    preferences.addListener(reschedule);
    // Completing today's plan or a review re-plans (and cancels reminders
    // that no longer apply).
    _memorization.addListener(reschedule);
    WidgetsBinding.instance.addObserver(this);
    reschedule();
  }

  /// Route to open first, when the app was launched from a notification.
  Future<String?> launchRoute() async {
    try {
      return _validRoute(await gateway.launchPayload());
    } catch (_) {
      return null;
    }
  }

  /// The app's router; a tap that arrived earlier is delivered now.
  void attachNavigator(void Function(String route) navigator) {
    _navigator = navigator;
    final pending = _pendingRoute;
    _pendingRoute = null;
    if (pending != null) navigator(pending);
  }

  void _onTap(String payload) {
    final route = _validRoute(payload);
    if (route == null) return;
    final nav = _navigator;
    if (nav == null) {
      _pendingRoute = route;
    } else {
      nav(route);
    }
  }

  /// Only the app's own reminder routes are accepted.
  static String? _validRoute(String? payload) {
    if (payload == null) return null;
    if (payload == AppRoutes.memorizationPlan || payload == AppRoutes.memorizationReview) return payload;
    if (payload.startsWith('/hadith/') && payload.length > '/hadith/'.length) return payload;
    return null;
  }

  /// Turns a reminder on. The system prompt is shown only the first time;
  /// after a refusal the UI explains and offers [openSettings].
  Future<ReminderEnableResult> enable(ReminderKind kind) async {
    if (!gateway.isSupported) {
      await preferences.setEnabled(kind, true);
      return ReminderEnableResult.unsupported;
    }
    var granted = await gateway.permissionGranted();
    if (!granted && !preferences.permissionAsked) {
      await preferences.markPermissionAsked();
      granted = await gateway.requestPermission();
    }
    if (!granted) return ReminderEnableResult.denied;
    await preferences.setEnabled(kind, true);
    return ReminderEnableResult.enabled;
  }

  Future<void> disable(ReminderKind kind) => preferences.setEnabled(kind, false);

  Future<void> setTime(ReminderKind kind, TimeOfDay time) => preferences.setTime(kind, time);

  Future<void> openSettings() => gateway.openSettings();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A new day may have started, or the permission changed in Settings.
    if (state == AppLifecycleState.resumed) reschedule();
  }

  /// Re-plans from the current data. Calls are coalesced and never overlap.
  void reschedule() {
    if (_dirty) return;
    _dirty = true;
    _queue = _queue.then((_) async {
      _dirty = false;
      await _apply();
    });
  }

  /// Awaitable re-plan (tests).
  Future<void> flush() async {
    reschedule();
    await _queue;
  }

  Future<void> _apply() async {
    try {
      final granted = gateway.isSupported && await gateway.permissionGranted();
      final plan = granted
          ? ReminderPlanner.plan(now: _clock(), enabled: preferences.isEnabled, timeOf: preferences.timeOf, data: _data)
          : const <PlannedReminder>[];
      lastPlan = plan;
      await gateway.replaceAll(plan);
    } catch (e) {
      debugPrint('Scheduling reminders failed: $e');
    }
  }

  void dispose() {
    preferences.removeListener(reschedule);
    _memorization.removeListener(reschedule);
    if (_started) WidgetsBinding.instance.removeObserver(this);
  }
}

class _AppReminderData implements ReminderData {
  _AppReminderData(this._repo, this._m);

  final HadithRepository _repo;
  final MemorizationController _m;

  @override
  Hadith? dailyHadith(DateTime day) => _repo.dailyHadith(day);
  @override
  String? bookName(String bookId) => _repo.bookById(bookId)?.nameSomali;
  @override
  bool get todayPlanComplete => _m.isTodayComplete;
  @override
  bool get todayHasPlan => _m.plannedToday > 0;
  @override
  bool get hasUnmemorizedLeft => _m.hasUnmemorizedLeft;
  @override
  int dueCountOn(String day) => _m.dueCountOn(day);
}
