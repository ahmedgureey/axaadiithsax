import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/app_info.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/share_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Tab 5 — Aniga. The app has no accounts: progress (bookmarks, memorisation,
/// quizzes) is stored on this device only.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const title = 'Aniga';

  /// Text shared by "La wadaag app-ka".
  static const shareText =
      '${AppInfo.name} — Arbaciin Al-Nawawi: 42 xadiis oo Carabi ah iyo Af-Soomaali, '
      'xifdin iyo imtixaan. Waa bilaash, internet la\'aanna wuu shaqeeyaa.\n'
      'https://raw.githubusercontent.com/ahmedgureey/axaadiithsax/main/apk/Xadiith-App.apk';

  Future<void> _shareApp(BuildContext context) async {
    final outcome = await context.services.share.shareText(shareText, subject: AppInfo.name);
    if (outcome == ShareOutcome.unavailable) {
      await Clipboard.setData(const ClipboardData(text: shareText));
      if (context.mounted) AppSnackbar.show(context, 'Qoraalka waa la koobiyeeyay.', type: AppSnackType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleProfile), showOrnament: true),
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
        children: [
          const AppPageBody(child: _ProgressCard()),
          AppSpacing.gapLg,
          AppPageBody(
            child: SettingsSection(
              title: 'Akhris iyo xifdin',
              children: [
                SettingsTile(
                  icon: Icons.bookmarks_outlined,
                  title: context.tr(AppText.titleFavorites),
                  onTap: () => context.push(AppRoutes.favorites),
                ),
                SettingsTile(icon: Icons.quiz_outlined, title: 'Imtixaan', onTap: () => context.push(AppRoutes.quiz)),
              ],
            ),
          ),
          AppSpacing.gapLg,
          AppPageBody(
            child: SettingsSection(
              title: 'Guud',
              children: [
                SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Ogeysiisyada',
                  onTap: () => context.push(AppRoutes.settingsNotifications),
                ),
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
                SettingsTile(icon: Icons.share_outlined, title: 'La wadaag app-ka', onTap: () => _shareApp(context)),
                SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: context.tr(AppText.aboutApp),
                  onTap: () => context.push(AppRoutes.about),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          const _Footer(),
        ],
      ),
    );
  }
}

/// Numbers (memorised, saved, quizzes) and overall memorisation progress in
/// one card.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([services.favorites, services.memorization]),
      builder: (context, _) {
        final m = services.memorization;
        final c = context.appColors;
        final percent = (m.overallProgress * 100).round();
        final stats = [
          (Icons.psychology_outlined, '${m.memorizedCount}', 'La xifdiyey'),
          (Icons.bookmarks_outlined, '${services.favorites.count}', 'La keydiyay'),
          (Icons.quiz_outlined, '${m.quizHistory.length}', 'Imtixaan'),
        ];
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(stats[i].$1, size: 16, color: c.goldText),
                                  const SizedBox(width: AppSpacing.xxs),
                                  Text(
                                    stats[i].$2,
                                    style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
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
              AppSpacing.gapMd,
              const Divider(height: 1),
              AppSpacing.gapMd,
              Semantics(
                label: 'Horumarka xifdinta: $percent boqolkiiba',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Horumarka xifdinta', style: context.textStyles.titleSmall)),
                        Text(
                          '${m.memorizedCount} / ${m.totalAvailable}',
                          style: context.textStyles.labelMedium?.copyWith(color: context.colors.primary),
                        ),
                      ],
                    ),
                    AppSpacing.gapXs,
                    ClipRRect(
                      borderRadius: AppRadius.pillAll,
                      child: LinearProgressIndicator(value: m.overallProgress, minHeight: 6),
                    ),
                    AppSpacing.gapXs,
                    Row(
                      children: [
                        Expanded(child: Text('$percent% la dhammeeyay', style: context.textStyles.labelSmall)),
                        if (m.streak > 0) ...[
                          Icon(Icons.local_fire_department_rounded, size: 14, color: c.warning),
                          const SizedBox(width: AppSpacing.xxs),
                          Text('${m.streak} maalmood', style: context.textStyles.labelSmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// App name, version and a reminder that progress stays on this phone.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final style = context.textStyles.labelSmall?.copyWith(color: context.appColors.textSecondary);
    return Column(
      children: [
        const IslamicStar(size: 16),
        AppSpacing.gapXs,
        Text('${AppInfo.name} · Nooca ${AppInfo.version}', style: style),
        Text('Horumarkaagu wuxuu ku kaydsan yahay taleefankaaga.', style: style, textAlign: TextAlign.center),
      ],
    );
  }
}
