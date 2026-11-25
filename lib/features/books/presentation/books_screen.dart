import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/remote/catalog_service.dart';

/// Tab 2 — "Kutubta Xadiiska". Every number shown is counted from the local
/// dataset; nothing implies a collection is complete.
class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  static const title = 'Kutubta Xadiiska';

  @override
  Widget build(BuildContext context) => CatalogBuilder(builder: _build);

  Widget _build(BuildContext context) {
    final repo = context.services.repository;
    final catalog = context.services.catalog;
    final books = repo.books;
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleBooks), showOrnament: true),
      body: books.isEmpty && catalog?.origin == CatalogOrigin.unavailable
          ? const CatalogUnavailableState()
          : books.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.auto_stories_outlined,
              title: 'Maktabaddu waa madhan tahay',
              message: 'Weli kutub laguma darin app-ka.',
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
              // +1 for the notice at the top, +1 for the contents of a single collection.
              itemCount: books.length + (books.length == 1 ? 2 : 1),
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                if (i == books.length + 1) {
                  return AppPageBody(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                    child: BookContents(bookId: books.first.id),
                  );
                }
                if (i == 0) {
                  return AppPageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CatalogStatusBanner(),
                        // Placeholder notice only while placeholder books are shown.
                        if (repo.totalHadithCount == 0 || catalog != null || books.any((b) => b.isDemo))
                          FormValidationMessage(
                            type: FormMessageType.info,
                            message: repo.totalHadithCount == 0
                                ? noVerifiedHadithMessage
                                : catalog != null
                                ? 'Xadiisyada halkan ku jira waa kuwa dib-u-eegis lagu sameeyey oo la daabacay; '
                                      'mid kasta wuxuu leeyahay isha iyo lambarkiisa asalka ah.'
                                : 'Kutubtan waa tusaale: kaliya xadiisyo kooban oo tijaabo ah ayaa ku jira, '
                                      'mana aha kutubta oo dhammaystiran.',
                          ),
                      ],
                    ),
                  );
                }
                final book = books[i - 1];
                final chapters = repo.chaptersOf(book.id).length;
                final hadiths = repo.hadithCountOfBook(book.id);
                final c = context.appColors;
                return AppPageBody(
                  child: BookCard(
                    titleSomali: book.nameSomali,
                    titleArabic: book.nameArabic,
                    author: book.author,
                    description: book.description,
                    badges: hadiths == 0
                        ? [MetaChip(label: 'Weli lama darin', icon: Icons.hourglass_empty_rounded, color: c.warning)]
                        : [
                            if (chapters > 1) MetaChip(label: '$chapters cutub'),
                            MetaChip(label: '$hadiths xadiis', icon: Icons.format_list_numbered_rounded),
                            if (book.isDemo) const DemoContentBadge(label: 'Tusaale'),
                          ],
                    onTap: () => context.go(AppRoutes.book(book.id)),
                  ),
                );
              },
            ),
    );
  }
}

/// "Tusmada": every hadith of a (single) collection by number and subject.
/// Only shown when the subjects are known (study notes).
class BookContents extends StatelessWidget {
  const BookContents({super.key, required this.bookId});

  static const title = 'Tusmada xadiisyada';

  final String bookId;

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    final items = [
      for (final h in repo.readingOrderOf(bookId))
        if (repo.studyOf(h.id) case final s?) (h, s.topic),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: title),
        AppSpacing.gapXs,
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64, endIndent: AppSpacing.md),
                ListTile(
                  leading: NumberBadge(items[i].$1.displayNumber, size: 32),
                  title: Text(
                    items[i].$2,
                    style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: context.appColors.textSecondary),
                  onTap: () => context.push(AppRoutes.hadith(items[i].$1.id)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
