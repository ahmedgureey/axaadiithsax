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
          const AppPageBody(child: _ProfileStatsCard()),
          AppSpacing.gapXl,
          AppPageBody(
            child: SettingsSection(
              title: 'Akhris',
              children: [
                SettingsTile(
                  icon: Icons.bookmarks_outlined,
                  title: context.tr(AppText.titleFavorites),
                  onTap: () => context.push(AppRoutes.favorites),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          AppPageBody(
            child: SettingsSection(
              title: 'Guud',
              children: [
                SettingsTile(
                  icon: Icons.settings_outlined,
                  title: context.tr(AppText.allSettings),
                  onTap: () => context.push(AppRoutes.settings),
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
        final c = context.appColors;
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) VerticalDivider(width: 1, color: context.colors.outlineVariant),
                  Expanded(
                    child: Semantics(
                      label: '${stats[i].$3}: ${stats[i].$2}',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(color: c.goldSubtle, shape: BoxShape.circle),
                            child: Icon(stats[i].$1, size: 20, color: c.goldText),
                          ),
                          AppSpacing.gapXs,
                          Text(
                            stats[i].$2,
                            style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(stats[i].$3, style: context.textStyles.labelSmall, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
