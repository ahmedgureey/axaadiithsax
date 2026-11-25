import 'package:flutter/material.dart';

import '../../../../app/app_services.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';
import '../../../favorites/favorite_actions.dart';
import '../../hadith_actions.dart';

/// All reader actions in one row, icons only (each has a tooltip / screen
/// reader label): copy Arabic · copy translation · copy all · share · save.
class HadithReadingActions extends StatelessWidget {
  const HadithReadingActions({super.key, required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final favorites = context.services.favorites;
    Widget action(IconData icon, String tooltip, VoidCallback? onPressed, {Color? color}) => IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          action(
            Icons.translate_rounded,
            context.tr(AppText.actionCopyArabic),
            () => copyText(context, hadith.arabicText, 'Qoraalka Carabiga waa la koobiyeeyay'),
          ),
          action(
            Icons.copy_rounded,
            context.tr(AppText.actionCopyTranslation),
            hadith.hasTranslation
                ? () => copyText(context, hadith.somaliText!, 'Tarjumaadda waa la koobiyeeyay')
                : null,
          ),
          action(
            Icons.copy_all_rounded,
            'Koobiyee dhammaan',
            () => copyText(context, hadithShareText(context, hadith), 'Xadiiska waa la koobiyeeyay'),
          ),
          action(Icons.share_rounded, 'La wadaag', () => shareHadith(context, hadith)),
          ListenableBuilder(
            listenable: favorites,
            builder: (context, _) {
              final saved = favorites.isFavorite(hadith.id);
              return action(
                saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                saved ? 'Ka saar kuwa la keydiyay' : 'Keydi',
                () => toggleFavoriteWithFeedback(context, hadith.id),
                color: saved ? context.appColors.gold : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
