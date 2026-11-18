import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/not_found_screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../hadith/presentation/hadith_preview_card.dart';

/// Hadith list for one chapter (lazy). Both IDs are validated, and the
/// chapter must belong to the book in the URL.
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

    final header = AppPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArabicText(chapter.titleArabic, variant: ArabicTextVariant.chapterHeading),
          Text(
            '${book.nameSomali} · Cutubka ${chapter.number} · ${hadiths.length} xadiis',
            style: context.textStyles.labelMedium,
          ),
          AppSpacing.gapSm,
        ],
      ),
    );

    return Scaffold(
      appBar: AppTopBar(title: chapter.titleSomali, subtitle: book.nameSomali),
      body: hadiths.isEmpty
          ? Column(
              children: [
                AppSpacing.gapMd,
                header,
                Expanded(
                  child: EmptyStateWidget(
                    icon: Icons.menu_book_outlined,
                    title: 'Cutubkan xadiis kuma jiro',
                    message: 'Weli xadiis laguma darin cutubkan.',
                    actionLabel: 'Ku noqo kitaabka',
                    onAction: () => context.go(AppRoutes.book(book.id)),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              itemCount: hadiths.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return header;
                final h = hadiths[i - 1];
                return AppPageBody(
                  key: ValueKey(h.id),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  child: HadithPreviewCard(hadith: h),
                );
              },
            ),
    );
  }
}
