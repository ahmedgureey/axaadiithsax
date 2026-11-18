import 'package:flutter/material.dart';

import '../../../../app/app_services.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';
import '../../../hadith/hadith_actions.dart';

/// Plan / history item: status icon (not colour alone), book + reference,
/// short Arabic and Somali excerpts.
class MemorizationHadithTile extends StatelessWidget {
  const MemorizationHadithTile({super.key, required this.hadith, required this.onTap, this.trailing, this.subtitle});

  final Hadith hadith;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    final memorized = services.memorization.isMemorized(hadith.id);
    final c = context.appColors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(
              memorized ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: memorized ? c.success : c.textSecondary,
              semanticLabel: memorized ? 'La xifdiyey' : 'Weli lama xifdin',
            ),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${repo.bookById(hadith.bookId)?.nameSomali ?? ''} · ${repo.referenceLabel(hadith)}',
                  style: context.textStyles.labelSmall,
                ),
                ArabicText(hadith.arabicText, maxLines: 1, fontSize: 18),
                Text(
                  hadith.somaliText ?? missingTranslationText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodySmall,
                ),
                if (subtitle != null) Text(subtitle!, style: context.textStyles.labelSmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
