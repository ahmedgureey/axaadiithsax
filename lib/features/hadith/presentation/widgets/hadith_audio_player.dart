import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';

/// Audio player card. No record has audio yet and the app has no playback
/// engine, so the player shows an honest "Cod lama hayo" state with all
/// controls disabled — it never pretends to play.
class HadithAudioPlayer extends StatelessWidget {
  const HadithAudioPlayer({super.key, required this.hadith});

  static const unavailableLabel = 'Cod lama hayo';
  static const speeds = [0.75, 1.0, 1.25, 1.5];

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    // Even if a record lists an asset, playback is not implemented yet, so
    // the controls stay disabled and the label says why.
    final message = hadith.hasAudio ? 'Dhegeysiga codka weli lama diyaarin.' : 'Xadiiskan weli cod looma duubin.';
    final c = context.appColors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                enabled: false,
                label: 'Dhegeyso — $unavailableLabel',
                excludeSemantics: true,
                child: IconButton.filled(
                  onPressed: null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  iconSize: AppSizes.iconLg,
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dhegeyso', style: context.textStyles.titleSmall),
                    Row(
                      children: [
                        Icon(Icons.volume_off_rounded, size: 16, color: c.textSecondary),
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Text(
                            unavailableLabel,
                            style: context.textStyles.labelMedium?.copyWith(color: c.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          // Static (disabled) progress: 0 of an unknown duration.
          ExcludeSemantics(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.pillAll,
                  child: LinearProgressIndicator(value: 0, minHeight: 4, backgroundColor: c.divider),
                ),
                AppSpacing.gapXxs,
                Row(
                  children: [
                    Text('0:00', style: context.textStyles.labelSmall),
                    const Spacer(),
                    Text('--:--', style: context.textStyles.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapXs,
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final s in speeds)
                ChoiceChip(
                  label: Text('${s}x'),
                  selected: s == 1.0,
                  onSelected: null, // disabled until audio exists
                ),
            ],
          ),
          AppSpacing.gapXs,
          Text(message, style: context.textStyles.bodySmall),
        ],
      ),
    );
  }
}
