import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/hadith.dart';
import '../../favorites/favorite_actions.dart';
import '../hadith_actions.dart';

/// Hadith list item wired to navigation and favourites. Opens the hadith
/// detail on top of the current tab, so back returns to where the user was.
class HadithPreviewCard extends StatelessWidget {
  const HadithPreviewCard({super.key, required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final book = services.repository.bookById(hadith.bookId);
    return ListenableBuilder(
      listenable: services.favorites,
      builder: (context, _) => HadithCard(
        arabicText: hadith.arabicText,
        somaliText: hadith.somaliText ?? missingTranslationText,
        source: book?.nameSomali ?? '—',
        reference: services.repository.referenceLabel(hadith),
        grade: hadith.grade,
        isVerified: hadith.isVerified,
        previewLines: 3,
        isFavorite: services.favorites.isFavorite(hadith.id),
        onFavoriteToggle: () => toggleFavoriteWithFeedback(context, hadith.id),
        onTap: () => context.push(AppRoutes.hadith(hadith.id)),
      ),
    );
  }
}
