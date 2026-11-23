import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../notification_preferences_controller.dart';

/// Reminder preferences. No notification service exists yet: preferences are
/// saved, but nothing is scheduled and no permission is requested.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  static const title = 'Ogeysiisyada';
  static const notice = 'Doorbid oo keliya: weli xasuusin lama diro. Doorashadaada waa la keydiyaa.';

  @override
  Widget build(BuildContext context) {
    final prefs = context.services.notifications;
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
                  const FormValidationMessage(type: FormMessageType.info, message: notice),
                  AppSpacing.gapLg,
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                    child: Column(
                      children: [
                        for (final kind in ReminderKind.values)
                          SwitchListTile(
                            title: Text(kind.label),
                            subtitle: Text('${kind.description}\n${prefs.isEnabled(kind) ? 'Shidan' : 'Dansan'}'),
                            isThreeLine: true,
                            value: prefs.isEnabled(kind),
                            onChanged: (v) => prefs.setEnabled(kind, v),
                          ),
                      ],
                    ),
                  ),
                  AppSpacing.gapLg,
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: SettingsTile(
                      icon: Icons.schedule_rounded,
                      title: 'Waqtiga xasuusinta',
                      subtitle: NotificationPreferencesController.formatTime(prefs.reminderTime),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: prefs.reminderTime);
                        if (picked != null) await prefs.setReminderTime(picked);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
