import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/auth_controller.dart';

/// Tab 5 — Aniga.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.services.auth;
    return Scaffold(
      appBar: const AppTopBar(title: 'Aniga', showOrnament: true),
      body: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          final isGuest = auth.status == AuthStatus.guest;
          final name = auth.displayName ?? 'Marti';
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              AppPageBody(
                child: AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: context.colors.primaryContainer,
                        foregroundColor: context.colors.onPrimaryContainer,
                        child: Text(
                          name.characters.first.toUpperCase(),
                          style: context.textStyles.titleLarge?.copyWith(
                            color: context.colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      AppSpacing.gapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: context.textStyles.titleMedium),
                            Text(auth.email ?? 'Akoon la\'aan (marti)', style: context.textStyles.bodySmall),
                            AppSpacing.gapXxs,
                            const DemoContentBadge(label: 'Akoon tusaale ah'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isGuest) ...[
                AppSpacing.gapMd,
                AppPageBody(
                  child: PrimaryButton(
                    label: 'Gal ama is diiwaangeli',
                    icon: Icons.login_rounded,
                    onPressed: () => context.push(AppRoutes.login),
                  ),
                ),
              ],
              AppSpacing.gapXl,
              const AppPageBody(child: SectionHeader(title: 'Akhriska')),
              _tile(context, Icons.bookmarks_outlined, 'Kuwa la jecel yahay', AppRoutes.favorites),
              _tile(
                context,
                Icons.text_fields_rounded,
                'Muuqaalka iyo qoraalka',
                AppRoutes.settingsAppearance,
              ),
              AppSpacing.gapLg,
              const AppPageBody(child: SectionHeader(title: 'Dejinta')),
              _tile(context, Icons.language_rounded, 'Luqadda', AppRoutes.settingsLanguage),
              _tile(
                context,
                Icons.notifications_none_rounded,
                'Ogeysiisyada',
                AppRoutes.settingsNotifications,
              ),
              _tile(context, Icons.settings_outlined, 'Dejinta oo dhan', AppRoutes.settings),
              _tile(context, Icons.shield_outlined, 'Arrimaha gaarka ah', AppRoutes.settingsPrivacy),
              _tile(context, Icons.info_outline_rounded, 'Ku saabsan app-ka', AppRoutes.about),
              AppSpacing.gapLg,
              AppPageBody(
                child: AppTextButton(
                  label: isGuest ? 'Ka bax habka martida' : 'Ka bax',
                  icon: Icons.logout_rounded,
                  color: context.colors.error,
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Ka bax?',
                      message: 'Waxaad ku laaban doontaa bogga soo dhaweynta.',
                      confirmLabel: 'Ka bax',
                      isDestructive: true,
                    );
                    if (!ok) return;
                    await auth.signOut();
                    if (context.mounted) context.go(AppRoutes.welcome);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String route) {
    return AppPageBody(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(route),
      ),
    );
  }
}
