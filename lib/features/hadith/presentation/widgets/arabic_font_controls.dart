import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';

/// A− / size / A+ / reset for the Arabic reading size. Uses the persisted
/// [AppSettingsController] value, which only affects Arabic hadith text —
/// never the rest of the app's typography.
class ArabicFontControls extends StatelessWidget {
  const ArabicFontControls({super.key, required this.settings, this.showReset = true});

  static const step = 2.0;

  /// Shown when the user tries to go past a limit.
  static final smallest = 'Kani waa cabbirka ugu yar (${ArabicFontSize.min.round()}).';
  static final largest = 'Kani waa cabbirka ugu weyn (${ArabicFontSize.max.round()}).';

  final AppSettingsController settings;

  /// The reset button (hidden in compact places such as the home card).
  final bool showReset;

  void _limit(BuildContext context, String message) => AppSnackbar.show(context, message);
  @override
  Widget build(BuildContext context) {
    final size = settings.arabicFontSize;
    final canShrink = size > ArabicFontSize.min;
    final canGrow = size < ArabicFontSize.max;
    final isDefault = size == ArabicFontSize.defaultSize;
    final disabled = Theme.of(context).disabledColor;
    return Container(
      decoration: BoxDecoration(color: context.appColors.goldSubtle, borderRadius: AppRadius.pillAll),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Yaree qoraalka Carabiga',
            // At the smallest size the button refuses and says why.
            onPressed: canShrink ? () => settings.setArabicFontSize(size - step) : () => _limit(context, smallest),
            color: canShrink ? null : disabled,
            icon: const Icon(Icons.text_decrease_rounded),
          ),
          Semantics(
            label: 'Cabbirka qoraalka Carabiga ${size.round()}',
            excludeSemantics: true,
            child: Text('${size.round()}', style: context.textStyles.titleSmall),
          ),
          IconButton(
            tooltip: 'Weyneey qoraalka Carabiga',
            // At the largest size the button refuses and says why.
            onPressed: canGrow ? () => settings.setArabicFontSize(size + step) : () => _limit(context, largest),
            color: canGrow ? null : disabled,
            icon: const Icon(Icons.text_increase_rounded),
          ),
          if (showReset)
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
