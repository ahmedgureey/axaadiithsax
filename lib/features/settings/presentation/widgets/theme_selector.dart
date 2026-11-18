import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/l10n/app_strings.dart';

/// System / Light / Dark. Uses the app's single AppSettingsController, so the
/// whole app updates immediately and the choice persists.
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key, required this.settings});

  final AppSettingsController settings;

  static const labels = {
    ThemeMode.system: AppText.themeSystem,
    ThemeMode.light: AppText.themeLight,
    ThemeMode.dark: AppText.themeDark,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SegmentedButton<ThemeMode>(
        // The check icon marks the selection in addition to colour.
        showSelectedIcon: true,
        segments: [
          for (final (mode, icon) in [
            (ThemeMode.system, Icons.brightness_auto_outlined),
            (ThemeMode.light, Icons.light_mode_outlined),
            (ThemeMode.dark, Icons.dark_mode_outlined),
          ])
            ButtonSegment(
              value: mode,
              icon: Icon(icon),
              label: Text(context.tr(labels[mode]!), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        selected: {settings.themeMode},
        onSelectionChanged: (s) => settings.setThemeMode(s.first),
      ),
    );
  }
}
