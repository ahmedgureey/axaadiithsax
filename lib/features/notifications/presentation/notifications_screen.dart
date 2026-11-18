import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/widgets/widgets.dart';

/// Notifications inbox. No notification system exists yet, so this shows an
/// honest empty state instead of invented notifications.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Ogeysiisyada', leading: backOrHomeLeading(context)),
      body: EmptyStateWidget(
        icon: Icons.notifications_none_rounded,
        title: 'Ogeysiis ma jiro',
        message:
            'Halkan waxaa ka soo muuqan doona xasuusinta xadiiska maalinta iyo xifdinta '
            'marka ogeysiisyadu diyaar noqdaan.',
        actionLabel: 'Dejinta ogeysiisyada',
        onAction: () => context.push(AppRoutes.settingsNotifications),
      ),
    );
  }
}
