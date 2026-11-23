import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/not_found_screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Book overview + lazily built chapter list. Invalid [bookId] → not-found.
class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) => CatalogBuilder(builder: _build);

  Widget _build(BuildContext context) {
    final repo = context.services.repository;
    final book = repo.bookById(bookId);
    if (book == null) {
      return const NotFoundScreen(
        title: 'Kitaabkan lama helin',
        message: 'Kitaabka aad dooratay kuma jiro xogta app-ka.',
      );
    }
    final chapters = repo.chaptersOf(book.id);
    final hadithCount = repo.hadithCountOfBook(book.id);

    return Scaffold(
      appBar: AppTopBar(
        title: book.nameSomali,
        actions: [
          if (hadithCount > 0)
            IconActionButton(
              icon: Icons.manage_search_rounded,
              tooltip: 'Ka raadi kitaabkan',
              onPressed: () => context.go(AppRoutes.searchWith(bookId: book.id)),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: AppPageBody(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ArabicText(book.nameArabic, variant: ArabicTextVariant.chapterHeading),
                      Text(book.author, style: context.textStyles.titleSmall),
                      AppSpacing.gapXs,
                      Text(book.description, style: context.textStyles.bodyMedium),
                      AppSpacing.gapSm,
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          MetaChip(label: '${chapters.length} cutub (halkan)', icon: Icons.list_alt_rounded),
                          MetaChip(label: '$hadithCount xadiis (halkan)', icon: Icons.menu_book_outlined),
                          if (!book.isVerified && hadithCount > 0) const DemoContentBadge(),
                          OfflineStatusIndicator(
                            status: hadithCount > 0
                                ? OfflineAvailability.availableLocally
                                : OfflineAvailability.notDownloaded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: AppSpacing.gapXl),
          const SliverToBoxAdapter(
            child: AppPageBody(child: SectionHeader(title: 'Cutubyada')),
          ),
          const SliverToBoxAdapter(child: AppSpacing.gapSm),
          if (chapters.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: EmptyStateWidget(
                  icon: Icons.list_alt_rounded,
                  title: 'Cutub lama helin',
                  message: 'Kitaabkan weli cutub ama xadiis laguma darin.',
                  actionLabel: 'Ku noqo kutubta',
                  onAction: () => context.go(AppRoutes.books),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              sliver: SliverList.builder(
                itemCount: chapters.length,
                itemBuilder: (context, i) {
                  final chapter = chapters[i];
                  final count = repo.hadithCountOfChapter(chapter.id);
                  return AppPageBody(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      semanticLabel: 'Cutubka ${chapter.number}: ${chapter.titleSomali}, $count xadiis',
                      onTap: () => context.go(AppRoutes.chapter(book.id, chapter.id)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: context.appColors.goldSubtle,
                          foregroundColor: context.appColors.goldText,
                          child: Text('${chapter.number}'),
                        ),
                        title: Text(chapter.titleSomali),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ArabicText(chapter.titleArabic, variant: ArabicTextVariant.label, maxLines: 1),
                            Text('Cutubka ${chapter.number} · $count xadiis', style: context.textStyles.labelSmall),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
