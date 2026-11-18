import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import 'widgets/reading_preferences_card.dart';

class ReadingSettingsScreen extends StatelessWidget {
  const ReadingSettingsScreen({super.key});

  static const title = 'Doorbidyada akhriska';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleReading), leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          AppPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Isbeddeladan waxay saameeyaan bogagga akhriska oo dhan. Qoraalka xadiiska laftiisa isma beddelo.',
                  style: context.textStyles.bodyMedium,
                ),
                AppSpacing.gapMd,
                ReadingPreferencesCard(settings: context.services.settings),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
