import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/not_found_screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../hadith/presentation/hadith_preview_card.dart';

/// Hadith list for one chapter. Both IDs are validated, and the chapter must
/// belong to the book in the URL.
class ChapterScreen extends StatelessWidget {
  const ChapterScreen({super.key, required this.bookId, required this.chapterId});

  final String bookId;
  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    final book = repo.bookById(bookId);
    final chapter = repo.chapterById(chapterId);
    if (book == null || chapter == null || chapter.bookId != book.id) {
      return const NotFoundScreen(
        title: 'Cutubkan lama helin',
        message: 'Cutubka aad dooratay kuma jiro kitaabkan.',
      );
    }
    final hadiths = repo.hadithsOf(chapter.id);
    return Scaffold(
      appBar: AppTopBar(title: chapter.titleSomali, subtitle: book.nameSomali),
      body: hadiths.isEmpty
          ? const EmptyStateWidget(title: 'Cutubkan xadiis kuma jiro')
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                AppPageBody(
                  child: ArabicText(chapter.titleArabic, variant: ArabicTextVariant.chapterHeading),
                ),
                AppSpacing.gapSm,
                for (final h in hadiths)
                  AppPageBody(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    child: HadithPreviewCard(hadith: h),
                  ),
              ],
            ),
    );
  }
}
