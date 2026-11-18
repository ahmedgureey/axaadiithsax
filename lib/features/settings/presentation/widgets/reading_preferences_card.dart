import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../hadith/presentation/widgets/arabic_font_controls.dart';

/// Arabic size (same control as the reader), translation size, Arabic line
/// spacing, a live preview and reset. All values persist and apply to every
/// reading screen; the rest of the app's typography is unchanged.
class ReadingPreferencesCard extends StatelessWidget {
  const ReadingPreferencesCard({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            label: 'Qoraalka Carabiga',
            control: ArabicFontControls(settings: settings),
          ),
          _Row(
            label: 'Tarjumaadda Soomaaliga',
            control: _Stepper(
              valueLabel: '${(settings.translationScale * 100).round()}%',
              semantic: 'Cabbirka tarjumaadda',
              onMinus: settings.translationScale > TranslationScale.min
                  ? () => settings.setTranslationScale(settings.translationScale - TranslationScale.step)
                  : null,
              onPlus: settings.translationScale < TranslationScale.max
                  ? () => settings.setTranslationScale(settings.translationScale + TranslationScale.step)
                  : null,
            ),
          ),
          _Row(
            label: 'Masaafada sadarrada Carabiga',
            control: _Stepper(
              valueLabel: settings.arabicLineHeight.toStringAsFixed(1),
              semantic: 'Masaafada sadarrada',
              onMinus: settings.arabicLineHeight > ArabicLineHeight.min
                  ? () => settings.setArabicLineHeight(settings.arabicLineHeight - ArabicLineHeight.step)
                  : null,
              onPlus: settings.arabicLineHeight < ArabicLineHeight.max
                  ? () => settings.setArabicLineHeight(settings.arabicLineHeight + ArabicLineHeight.step)
                  : null,
            ),
          ),
          AppSpacing.gapMd,
          Text('Muuqaal tusaale ah', style: context.textStyles.labelMedium),
          AppSpacing.gapXs,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ArabicText('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ، هذا نص تجريبي لعرض حجم الخط وتباعد الأسطر'),
                const OrnamentDivider(),
                Text(
                  'Tusaale: qoraalka tarjumaadda Af-Soomaaliga halkan ayuu ku muuqdaa cabbirkan.',
                  style: ArabicTextStyles.somaliTranslation(context),
                ),
              ],
            ),
          ),
          AppSpacing.gapSm,
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextButton(
              label: 'Ku celi qiyamka asalka ah',
              icon: Icons.restart_alt_rounded,
              onPressed: settings.readingIsDefault ? null : settings.resetReading,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.control});
  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    // Wrap: the control moves under the label on narrow screens.
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xxs,
      children: [
        Text(label, style: context.textStyles.titleSmall),
        control,
      ],
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.valueLabel, required this.semantic, required this.onMinus, required this.onPlus});

  final String valueLabel;
  final String semantic;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: context.appColors.goldSubtle, borderRadius: AppRadius.pillAll),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(tooltip: 'Yaree: $semantic', onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
        Semantics(
          label: '$semantic $valueLabel',
          excludeSemantics: true,
          child: Text(valueLabel, style: context.textStyles.titleSmall),
        ),
        IconButton(tooltip: 'Kordhi: $semantic', onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
      ],
    ),
  );
}
