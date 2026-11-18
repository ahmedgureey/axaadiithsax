import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Theme (system / light / dark) and Arabic reading size. Both persist.
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.services.settings;
    return Scaffold(
      appBar: AppTopBar(title: 'Muuqaalka', leading: backOrHomeLeading(context)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            AppPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(title: 'Theme'),
                  AppSpacing.gapSm,
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Iftiin'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Mugdi'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => settings.setThemeMode(s.first),
                  ),
                  AppSpacing.gapXl,
                  const SectionHeader(title: 'Qoraalka Carabiga'),
                  AppSpacing.gapSm,
                  Text('Cabbirka: ${settings.arabicFontSize.round()}', style: context.textStyles.titleSmall),
                  Slider(
                    value: settings.arabicFontSize,
                    min: ArabicFontSize.min,
                    max: ArabicFontSize.max,
                    divisions: (ArabicFontSize.max - ArabicFontSize.min).round() ~/ 2,
                    label: settings.arabicFontSize.round().toString(),
                    semanticFormatterCallback: (v) => 'Cabbirka qoraalka Carabiga ${v.round()}',
                    onChanged: settings.setArabicFontSize,
                  ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Tusaale', style: context.textStyles.labelMedium),
                        const ArabicText('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ'),
                      ],
                    ),
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
