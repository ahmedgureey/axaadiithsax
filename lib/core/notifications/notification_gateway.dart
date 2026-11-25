import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_planner.dart';

/// Device notification access. Real implementation: [LocalNotificationGateway]
/// (Android/iOS). Web and tests use [NoopNotificationGateway] or a fake.
abstract class NotificationGateway {
  /// Sets up the plugin and the local timezone; [onTap] receives the payload
  /// of a tapped notification while the app is running.
  Future<void> initialize(void Function(String payload) onTap);

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload();

  Future<bool> permissionGranted();

  /// Shows the system permission prompt (Android 13+). Returns the result.
  Future<bool> requestPermission();

  /// Opens the app's notification settings.
  Future<void> openSettings();

  /// Cancels every scheduled reminder of the app and schedules [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);

  bool get isSupported;
}

/// No notifications (web, unsupported platforms, tests).
class NoopNotificationGateway implements NotificationGateway {
  const NoopNotificationGateway();

  @override
  bool get isSupported => false;
  @override
  Future<void> initialize(void Function(String payload) onTap) async {}
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<bool> permissionGranted() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}
}

/// flutter_local_notifications + timezone-aware scheduling.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'reminders';
  static const _settingsChannel = MethodChannel('com.xadiithapp.app/settings');
  static const _channelName = 'Xasuusinno';
  static const _channelDescription = 'Xadiiska maalinta, xifdinta iyo dib-u-eegista';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  bool get isSupported => true;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> initialize(void Function(String payload) onTap) async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Local timezone not detected, using UTC: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final p = response.payload;
        if (p != null && p.isNotEmpty) onTap(p);
      },
    );
    _initialized = true;
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details!.notificationResponse?.payload;
  }

  @override
  Future<bool> permissionGranted() async {
    final android = _android;
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    return true; // iOS asks in requestPermission
  }

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
  }

  @override
  Future<void> openSettings() async {
    try {
      // Android: MainActivity opens the app's notification settings.
      await _settingsChannel.invokeMethod<bool>('openNotificationSettings');
    } catch (e) {
      debugPrint('Could not open notification settings: $e');
    }
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    // Only scheduled (pending) reminders are replaced; notifications already
    // on screen stay. Same ids every time, so nothing is duplicated.
    await _plugin.cancelAllPendingNotifications();
    for (final r in reminders) {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          // Expanded view shows the whole excerpt.
          styleInformation: BigTextStyleInformation(r.body),
        ),
        iOS: const DarwinNotificationDetails(),
      );
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime(tz.local, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute),
        notificationDetails: details,
        // Inexact: no special "exact alarm" permission; may arrive a few
        // minutes late when the phone saves battery.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.payload,
      );
    }
  }
}
