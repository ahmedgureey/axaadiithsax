import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/auth_controller.dart';

/// Tab 5 — Aniga. Demo profile from the local demo session; statistics come
/// from the existing favourites and memorisation controllers.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const title = 'Aniga';

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final auth = services.auth;
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleProfile), showOrnament: true),
      body: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          final isGuest = auth.isGuest;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              AppPageBody(child: _ProfileHeader(auth: auth)),
              if (auth.isSignedIn && !auth.emailVerified && !auth.usesRealAccounts) ...[
                AppSpacing.gapMd,
                AppPageBody(
                  child: SecondaryButton(
                    label: 'Xaqiiji email-ka (demo)',
                    icon: Icons.mark_email_unread_outlined,
                    onPressed: () => context.push(AppRoutes.verifyEmail),
                  ),
                ),
              ],
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
              AppSpacing.gapLg,
              AppPageBody(
                child: AppTextButton(
                  label: isGuest ? 'Ka bax habka martida' : context.tr(AppText.signOut),
                  icon: Icons.logout_rounded,
                  color: context.colors.error,
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Ka bax?',
                      message:
                          'Waxaad ku laaban doontaa bogga soo dhaweynta. Kuwa la keydiyay iyo xifdintu way sii jiraan.',
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
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.auth});

  final AuthController auth;

  Future<void> _editName(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: auth.displayName ?? ''),
    );
    if (name != null && await auth.updateDisplayName(name) && context.mounted) {
      AppSnackbar.show(context, 'Magaca waa la beddelay (qalabkan oo keliya)', type: AppSnackType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = auth.displayName ?? 'Marti';
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: context.colors.primaryContainer,
            foregroundColor: context.colors.onPrimaryContainer,
            child: auth.isGuest
                ? const Icon(Icons.person_outline_rounded)
                : Text(
                    name.characters.first.toUpperCase(),
                    style: context.textStyles.titleLarge?.copyWith(color: context.colors.onPrimaryContainer),
                  ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.textStyles.titleMedium),
                // Email only when the demo session has one — never invented.
                Text(auth.email ?? 'Ma gelin (marti)', style: context.textStyles.bodySmall),
                AppSpacing.gapXxs,
                if (auth.isGuest)
                  const DemoContentBadge(label: 'Marti — akoon ma jiro')
                else if (auth.emailVerified)
                  MetaChip(
                    label: auth.usesRealAccounts ? 'Email la xaqiijiyay' : 'Email la xaqiijiyay (demo)',
                    icon: Icons.verified_outlined,
                    color: context.appColors.success,
                  )
                else
                  DemoContentBadge(
                    label: auth.usesRealAccounts ? 'Email-ka weli lama xaqiijin' : 'Akoon demo · email lama xaqiijin',
                  ),
                AppSpacing.gapXxs,
                Text(
                  auth.isGuest
                      ? 'Ku soo dhowow! Horumarkaagu wuxuu ku kaydsan yahay qalabkan.'
                      : auth.usesRealAccounts
                      ? 'Ku soo dhowow, $name! Akoonkaagu waa Supabase; kuwa la keydiyay iyo xifdintu weli qalabkan ayay ku jiraan.'
                      : 'Ku soo dhowow, $name! Xogtan waxay ku kaydsan tahay qalabkan oo keliya.',
                  style: context.textStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (auth.isSignedIn)
            IconActionButton(icon: Icons.edit_outlined, tooltip: 'Beddel magaca', onPressed: () => _editName(context)),
        ],
      ),
    );
  }
}

/// Owns its controller so it is disposed only after the dialog's exit
/// animation has finished.
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Beddel magaca'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: AuthController.maxNameLength,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        decoration: const InputDecoration(labelText: 'Magaca la muujiyo'),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Magacu waa qasab.' : null,
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Jooji')),
      FilledButton(onPressed: _submit, child: const Text('Keydi')),
    ],
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
