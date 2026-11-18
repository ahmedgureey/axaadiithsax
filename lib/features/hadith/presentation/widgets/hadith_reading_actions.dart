import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../data/models/hadith.dart';
import '../../../favorites/favorite_actions.dart';
import '../../../../app/app_services.dart';
import '../../hadith_actions.dart';

/// "Koobiyee dhammaan" · "La wadaag" · "Keydi" row for the reader.
class HadithReadingActions extends StatelessWidget {
  const HadithReadingActions({super.key, required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final favorites = context.services.favorites;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        OutlinedButton.icon(
          onPressed: () => copyText(context, hadithShareText(context, hadith), 'Xadiiska waa la koobiyeeyay'),
          icon: const Icon(Icons.copy_all_rounded, size: AppSizes.iconSm),
          label: const Text('Koobiyee dhammaan'),
        ),
        OutlinedButton.icon(
          onPressed: () => shareHadith(context, hadith),
          icon: const Icon(Icons.share_rounded, size: AppSizes.iconSm),
          label: const Text('La wadaag'),
        ),
        ListenableBuilder(
          listenable: favorites,
          builder: (context, _) {
            final saved = favorites.isFavorite(hadith.id);
            return OutlinedButton.icon(
              onPressed: () => toggleFavoriteWithFeedback(context, hadith.id),
              icon: Icon(
                saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: AppSizes.iconSm,
                color: saved ? context.appColors.gold : null,
              ),
              label: Text(saved ? 'La keydiyay' : 'Keydi'),
            );
          },
        ),
      ],
    );
  }
}
