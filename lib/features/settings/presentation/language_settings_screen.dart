import 'package:flutter/material.dart';

import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Interface language. Only Somali is available in this phase.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Luqadda', leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          AppPageBody(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Af-Soomaali'),
              subtitle: const Text('Luqadda app-ka'),
              trailing: Icon(
                Icons.check_circle_rounded,
                color: context.colors.primary,
                semanticLabel: 'La doortay',
              ),
              selected: true,
            ),
          ),
          for (final lang in ['English', 'العربية'])
            AppPageBody(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: false,
                title: Text(lang),
                subtitle: const Text('Dhowaan'),
              ),
            ),
          AppSpacing.gapMd,
          AppPageBody(
            child: Text(
              'Qoraalka xadiiska wuxuu had iyo jeer ku qornaanayaa Carabi, tarjumaaddana Af-Soomaali.',
              style: context.textStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
