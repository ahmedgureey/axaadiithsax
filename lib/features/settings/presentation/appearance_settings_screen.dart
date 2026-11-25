import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import 'widgets/theme_selector.dart';

/// Theme choice with a live preview of common elements.
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  static const title = 'Muuqaalka';

  @override
  Widget build(BuildContext context) {
    final settings = context.services.settings;
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleAppearance), leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          AppPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Theme'),
                AppSpacing.gapXs,
                ThemeSelector(settings: settings),
                AppSpacing.gapXs,
                Text(
                  '"Nidaamka" wuxuu raacaa dejinta telefoonkaaga (iftiin ama mugdi).',
                  style: context.textStyles.bodySmall,
                ),
                AppSpacing.gapXl,
                Text('Muuqaal tusaale ah', style: context.textStyles.labelMedium),
                AppSpacing.gapXs,
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Cinwaan', style: context.textStyles.titleMedium),
                      Text('Qoraal caadi ah oo Af-Soomaali ah.', style: context.textStyles.bodyMedium),
                      AppSpacing.gapSm,
                      const ArabicText('نص عربي للعرض'),
                      AppSpacing.gapSm,
                      PrimaryButton(label: 'Badhan', onPressed: () {}),
                    ],
                  ),
                ),
                AppSpacing.gapLg,
                SecondaryButton(
                  label: 'Habka akhriska',
                  icon: Icons.text_fields_rounded,
                  onPressed: () => context.push(AppRoutes.settingsReading),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
