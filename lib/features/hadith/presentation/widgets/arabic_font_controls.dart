import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/theme.dart';

/// A− / size / A+ / reset for the Arabic reading size. Uses the persisted
/// [AppSettingsController] value, which only affects Arabic hadith text —
/// never the rest of the app's typography.
class ArabicFontControls extends StatelessWidget {
  const ArabicFontControls({super.key, required this.settings});

  static const step = 2.0;

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final size = settings.arabicFontSize;
    final canShrink = size > ArabicFontSize.min;
    final canGrow = size < ArabicFontSize.max;
    final isDefault = size == ArabicFontSize.defaultSize;
    return Container(
      decoration: BoxDecoration(color: context.appColors.goldSubtle, borderRadius: AppRadius.pillAll),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Yaree qoraalka Carabiga',
            onPressed: canShrink ? () => settings.setArabicFontSize(size - step) : null,
            icon: const Icon(Icons.text_decrease_rounded),
          ),
          Semantics(
            label: 'Cabbirka qoraalka Carabiga ${size.round()}',
            excludeSemantics: true,
            child: Text('${size.round()}', style: context.textStyles.titleSmall),
          ),
          IconButton(
            tooltip: 'Weyneey qoraalka Carabiga',
            onPressed: canGrow ? () => settings.setArabicFontSize(size + step) : null,
            icon: const Icon(Icons.text_increase_rounded),
          ),
          IconButton(
            tooltip: 'Dib u deji cabbirka',
            onPressed: isDefault ? null : () => settings.setArabicFontSize(ArabicFontSize.defaultSize),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
    );
  }
}
