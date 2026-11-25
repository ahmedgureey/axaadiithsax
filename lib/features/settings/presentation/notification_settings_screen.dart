import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../notification_preferences_controller.dart';

/// Reminder settings: each reminder can be switched on/off and has its own
/// time. Turning one on asks for the notification permission the first
/// time; scheduling is done by [ReminderService] from the app's real data.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  static const title = 'Ogeysiisyada';
  static const deniedMessage = 'Ogeysiisyada waa la xiray. Ka shid Settings-ka telefoonka.';
  static const unsupportedNotice = 'Ogeysiisyadu waxay ka shaqeeyaan telefoonka (Android) oo keliya.';

  Future<void> _toggle(BuildContext context, ReminderService reminders, ReminderKind kind, bool on) async {
    if (!on) return reminders.disable(kind);
    final result = await reminders.enable(kind);
    if (result == ReminderEnableResult.denied && context.mounted) {
      AppSnackbar.show(
        context,
        deniedMessage,
        type: AppSnackType.error,
        actionLabel: 'Settings',
        onAction: reminders.openSettings,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final prefs = services.notifications;
    final reminders = services.reminders;
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleNotifications), leading: backOrHomeLeading(context)),
      body: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            AppPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!reminders.isSupported) ...[
                    const FormValidationMessage(type: FormMessageType.info, message: unsupportedNotice),
                    AppSpacing.gapLg,
                  ],
                  for (final kind in ReminderKind.values) ...[
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: Text(kind.label),
                            subtitle: Text(kind.description),
                            value: prefs.isEnabled(kind),
                            onChanged: (v) => _toggle(context, reminders, kind, v),
                          ),
                          SettingsTile(
                            icon: Icons.schedule_rounded,
                            title: 'Waqtiga',
                            subtitle: NotificationPreferencesController.formatTime(prefs.timeOf(kind)),
                            onTap: () async {
                              final picked = await showTimePicker(context: context, initialTime: prefs.timeOf(kind));
                              if (picked != null) await reminders.setTime(kind, picked);
                            },
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapMd,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
