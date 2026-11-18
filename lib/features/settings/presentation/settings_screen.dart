import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.palette_outlined,
        'Muuqaalka',
        'Theme iyo cabbirka qoraalka Carabiga',
        AppRoutes.settingsAppearance,
      ),
      (Icons.language_rounded, 'Luqadda', 'Af-Soomaali', AppRoutes.settingsLanguage),
      (
        Icons.notifications_none_rounded,
        'Ogeysiisyada',
        'Xasuusinta akhriska iyo xifdinta',
        AppRoutes.settingsNotifications,
      ),
      (Icons.shield_outlined, 'Arrimaha gaarka ah', 'Sida xogtaada loo maareeyo', AppRoutes.settingsPrivacy),
      (Icons.info_outline_rounded, 'Ku saabsan', 'Nooca app-ka iyo shatiyada', AppRoutes.about),
    ];
    return Scaffold(
      appBar: AppTopBar(title: 'Dejinta', leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          for (final (icon, title, subtitle, route) in items)
            AppPageBody(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(route),
              ),
            ),
        ],
      ),
    );
  }
}
