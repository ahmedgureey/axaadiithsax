import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Tab 5 — Aniga. The app has no accounts: progress (bookmarks, memorisation,
/// quizzes) is stored on this device only.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const title = 'Aniga';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleProfile), showOrnament: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          const AppPageBody(child: _DeviceNotice()),
          AppSpacing.gapLg,
          const AppPageBody(child: _ProfileStatsCard()),
          AppSpacing.gapXl,
          AppPageBody(
            child: SettingsSection(
              title: 'Akhriska',
              children: [
                SettingsTile(
                  icon: Icons.bookmarks_outlined,
                  title: context.tr(AppText.titleFavorites),
                  onTap: () => context.push(AppRoutes.favorites),
                ),
                SettingsTile(
                  icon: Icons.text_fields_rounded,
                  title: context.tr(AppText.titleReading),
                  onTap: () => context.push(AppRoutes.settingsReading),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          AppPageBody(
            child: SettingsSection(
              title: 'Dejinta iyo macluumaad',
              children: [
                SettingsTile(
                  icon: Icons.settings_outlined,
                  title: context.tr(AppText.allSettings),
                  onTap: () => context.push(AppRoutes.settings),
                ),
                SettingsTile(
                  icon: Icons.shield_outlined,
                  title: context.tr(AppText.titlePrivacy),
                  onTap: () => context.push(AppRoutes.settingsPrivacy),
                ),
                SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: context.tr(AppText.titleHelp),
                  onTap: () => context.push(AppRoutes.help),
                ),
                SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: context.tr(AppText.aboutApp),
                  onTap: () => context.push(AppRoutes.about),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceNotice extends StatelessWidget {
  const _DeviceNotice();

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: context.colors.primaryContainer,
          foregroundColor: context.colors.onPrimaryContainer,
          child: const Icon(Icons.phone_android_rounded),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ku soo dhowow!', style: context.textStyles.titleMedium),
              AppSpacing.gapXxs,
              Text(
                'Akoon looma baahna. Kuwa aad keydisay, xifdintaada iyo imtixaannadu '
                'waxay ku kaydsan yihiin qalabkan oo keliya.',
                style: context.textStyles.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileStatsCard extends StatelessWidget {
  const _ProfileStatsCard();

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([services.favorites, services.memorization]),
      builder: (context, _) {
        final m = services.memorization;
        final stats = [
          (Icons.psychology_outlined, '${m.memorizedCount}', 'La xifdiyey'),
          (Icons.bookmarks_outlined, '${services.favorites.count}', 'La keydiyay'),
          (Icons.quiz_outlined, '${m.quizHistory.length}', 'Imtixaan'),
        ];
        return AppCard(
          child: Row(
            children: [
              for (final (icon, value, label) in stats)
                Expanded(
                  child: Semantics(
                    label: '$label: $value',
                    excludeSemantics: true,
                    child: Column(
                      children: [
                        Icon(icon, color: context.appColors.goldText),
                        Text(value, style: context.textStyles.titleLarge),
                        Text(label, style: context.textStyles.labelSmall, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
