import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_services.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';
import '../../../favorites/favorite_actions.dart';
import '../../../hadith/hadith_actions.dart';
import '../../../hadith/presentation/widgets/arabic_font_controls.dart';

/// "Xadiiska Maalinta" — uses the shared favorites controller for bookmarks.
class DailyHadithSection extends StatelessWidget {
  const DailyHadithSection({super.key, required this.hadith});

  final Hadith? hadith;

  @override
  Widget build(BuildContext context) {
    final h = hadith;
    if (h == null) {
      return const AppCard(
        child: SizedBox(
          height: 240,
          child: EmptyStateWidget(
            icon: Icons.menu_book_outlined,
            title: 'Xadiiska maalinta lama heli karo',
            message: noVerifiedHadithMessage,
          ),
        ),
      );
    }
    final services = context.services;
    final repo = services.repository;
    final source = repo.bookById(h.bookId)?.nameSomali ?? '—';
    void open() => context.push(AppRoutes.hadith(h.id));

    return ListenableBuilder(
      listenable: services.favorites,
      builder: (context, _) {
        final saved = services.favorites.isFavorite(h.id);
        return DailyHadithCard(
          title: context.tr(AppText.homeDailyHadith),
          readLabel: context.tr(AppText.homeReadHadith),
          arabicText: h.arabicText,
          somaliText: h.somaliText ?? missingTranslationText,
          narrator: h.narrator,
          source: source,
          reference: repo.referenceLabel(h),
          grade: h.grade,
          isVerified: h.isVerified,
          isDemo: h.isDemo,
          isFavorite: saved,
          onTap: open,
          onRead: open,
          onShare: () => shareHadith(context, h),
          onBookmark: () => toggleFavoriteWithFeedback(context, h.id),
          fontControls: ListenableBuilder(
            listenable: services.settings,
            builder: (context, _) => ArabicFontControls(settings: services.settings, showReset: false),
          ),
        );
      },
    );
  }
}
