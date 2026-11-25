import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import 'widgets/theme_selector.dart';

/// "Dejinta" — appearance, language, reading, notifications, info, resets.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const title = 'Dejinta';

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final settings = services.settings;
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleSettings), leading: backOrHomeLeading(context)),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, services.notifications]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            AppPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(title: context.tr(AppText.settingsAppearance)),
                  AppSpacing.gapXs,
                  ThemeSelector(settings: settings),
                  AppSpacing.gapXl,
                  SettingsSection(
                    title: context.tr(AppText.settingsLanguageReading),
                    children: [
                      SettingsTile(
                        icon: Icons.language_rounded,
                        title: context.tr(AppText.titleLanguage),
                        subtitle: settings.language.nativeName,
                        onTap: () => context.push(AppRoutes.settingsLanguage),
                      ),
                      SettingsTile(
                        icon: Icons.text_fields_rounded,
                        title: context.tr(AppText.titleReading),
                        subtitle:
                            'Carabi ${settings.arabicFontSize.round()} · tarjumaad ${(settings.translationScale * 100).round()}%',
                        onTap: () => context.push(AppRoutes.settingsReading),
                      ),
                      SettingsTile(
                        icon: Icons.notifications_none_rounded,
                        title: context.tr(AppText.titleNotifications),
                        subtitle: services.notifications.enabledCount == 0
                            ? 'Dhammaan way dansan yihiin (doorbid oo keliya)'
                            : '${services.notifications.enabledCount} shidan (doorbid oo keliya)',
                        onTap: () => context.push(AppRoutes.settingsNotifications),
                      ),
                    ],
                  ),
                  AppSpacing.gapXl,
                  SettingsSection(
                    title: context.tr(AppText.settingsInfo),
                    children: [
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
                  AppSpacing.gapXl,
                  SettingsSection(
                    title: context.tr(AppText.settingsReset),
                    footer: 'Xogtan waxay ku kaydsan tahay qalabkan oo keliya; dib-u-dejintu lagama noqon karo.',
                    children: [
                      SettingsTile(
                        icon: Icons.format_paint_outlined,
                        title: 'Dib u deji muuqaalka iyo akhriska',
                        subtitle: 'Theme, luqadda iyo cabbirrada qoraalka',
                        destructive: true,
                        onTap: () => _confirmThen(
                          context,
                          title: 'Dib u deji muuqaalka iyo akhriska?',
                          message:
                              'Theme-ka, luqadda iyo cabbirrada qoraalka waxay ku noqonayaan qiyamka asalka ah. '
                              'Kuwa la keydiyay iyo xifdintu isma beddelaan.',
                          action: settings.resetAppearanceAndReading,
                          done: 'Muuqaalka iyo akhriska waa la dib u dejiyay',
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.notifications_off_outlined,
                        title: 'Dib u deji ogeysiisyada',
                        destructive: true,
                        onTap: () => _confirmThen(
                          context,
                          title: 'Dib u deji ogeysiisyada?',
                          message: 'Dhammaan doorbidyada xasuusinta way dansanayaan, waqtiguna wuxuu noqonayaa 08:00.',
                          action: services.notifications.reset,
                          done: 'Ogeysiisyada waa la dib u dejiyay',
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.delete_forever_outlined,
                        title: 'Tirtir dhammaan xogta qalabka',
                        subtitle: 'Kuwa la keydiyay, xifdinta, imtixaannada, dejinta',
                        destructive: true,
                        onTap: () => _confirmThen(
                          context,
                          title: 'Tirtir dhammaan xogta?',
                          message:
                              'Qalabkan waxaa looga tirtirayaa: kuwa la keydiyay, xifdinta, dib-u-eegista, imtixaannada, '
                              'raadinta, akhriska, dejinta iyo session-ka demo-ga. '
                              'Waxaad ku laaban doontaa bogga hordhaca. Lagama noqon karo.',
                          confirmLabel: 'Tirtir',
                          action: services.resetAllLocalData,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmThen(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() action,
    String confirmLabel = 'Dib u deji',
    String? done,
  }) async {
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: 'Jooji',
      isDestructive: true,
    );
    if (!ok) return;
    await action();
    if (done != null && context.mounted) AppSnackbar.show(context, done, type: AppSnackType.success);
  }
}
