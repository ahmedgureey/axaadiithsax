import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Interface language. Somali is complete; Arabic and English are partial —
/// the screen says exactly what changes.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const title = 'Luqadda';

  @override
  Widget build(BuildContext context) {
    final settings = context.services.settings;
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleLanguage), leading: backOrHomeLeading(context)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            AppPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                    child: Column(
                      children: [
                        for (final lang in AppLanguage.values) _LanguageTile(language: lang, settings: settings),
                      ],
                    ),
                  ),
                  AppSpacing.gapMd,
                  FormValidationMessage(
                    type: FormMessageType.info,
                    message: settings.language.isComplete
                        ? 'Af-Soomaaligu waa luqadda app-ka oo dhammaystiran.'
                        : '${settings.language.nativeName}: qayb ahaan. Waxaa la turjumay qoraallada muhiimka ah '
                              '(${AppStrings.translatedCount(settings.language)}/${AppStrings.totalKeys}): tab-yada, '
                              'cinwaannada shaashadaha, qaybaha Guriga, badhamada akhriska iyo dejinta, iyo '
                              'qoraallada nidaamka (dialogs, waqtiga)${settings.language == AppLanguage.arabic ? ', jihaduna waa midig-ilaa-bidix' : ''}. '
                              'Sharaxaadaha dhaadheer weli waa Af-Soomaali.',
                  ),
                  AppSpacing.gapSm,
                  Text(
                    'Qoraalka xadiiska wuxuu had iyo jeer ahaanayaa Carabi, tarjumaadduna Af-Soomaali — '
                    'luqadda interface-ka isma beddesho waxa xadiiska ku qoran.',
                    style: context.textStyles.bodySmall,
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

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.language, required this.settings});

  final AppLanguage language;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final selected = settings.language == language;
    return Semantics(
      selected: selected,
      button: true,
      child: ListTile(
        minTileHeight: AppSizes.minTouchTarget + AppSpacing.xs,
        title: Text(language.nativeName, textDirection: language.textDirection),
        subtitle: Text(language.isComplete ? 'Dhammaystiran' : 'Qayb ahaan (tijaabo)'),
        // Check icon + "La doortay" label: selection is not shown by colour alone.
        trailing: selected
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('La doortay', style: context.textStyles.labelSmall?.copyWith(color: context.colors.primary)),
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(Icons.check_circle_rounded, color: context.colors.primary),
                ],
              )
            : const Icon(Icons.radio_button_unchecked),
        onTap: () => settings.setLanguage(language),
      ),
    );
  }
}
