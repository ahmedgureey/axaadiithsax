import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/not_found_screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Book overview + chapter list. Invalid [bookId] → not-found state.
class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    final book = repo.bookById(bookId);
    if (book == null) {
      return const NotFoundScreen(
        title: 'Kitaabkan lama helin',
        message: 'Kitaabka aad dooratay kuma jiro xogta app-ka.',
      );
    }
    final chapters = repo.chaptersOf(book.id);
    return Scaffold(
      appBar: AppTopBar(title: book.nameSomali),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          AppPageBody(
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ArabicText(book.nameArabic, variant: ArabicTextVariant.chapterHeading),
                  Text(book.author, style: context.textStyles.titleSmall),
                  AppSpacing.gapXs,
                  Text(book.description, style: context.textStyles.bodyMedium),
                  if (!book.isVerified) ...[
                    AppSpacing.gapSm,
                    const Align(alignment: Alignment.centerLeft, child: DemoContentBadge()),
                  ],
                ],
              ),
            ),
          ),
          AppSpacing.gapXl,
          const AppPageBody(child: SectionHeader(title: 'Cutubyada')),
          AppSpacing.gapSm,
          if (chapters.isEmpty)
            const SizedBox(height: 280, child: EmptyStateWidget(title: 'Cutub lama helin'))
          else
            for (final chapter in chapters)
              AppPageBody(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  onTap: () => context.go(AppRoutes.chapter(book.id, chapter.id)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.appColors.goldSubtle,
                      foregroundColor: context.appColors.goldText,
                      child: Text('${chapter.number}'),
                    ),
                    title: Text(chapter.titleSomali),
                    subtitle: ArabicText(chapter.titleArabic, variant: ArabicTextVariant.label, maxLines: 1),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
