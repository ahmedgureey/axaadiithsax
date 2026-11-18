import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Tab 2 — "Kutubta Xadiiska". Every number shown is counted from the local
/// dataset; nothing implies a collection is complete.
class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  static const title = 'Kutubta Xadiiska';

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    final books = repo.books;
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleBooks), showOrnament: true),
      body: books.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.auto_stories_outlined,
              title: 'Maktabaddu waa madhan tahay',
              message: 'Weli kutub laguma darin app-ka.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              // +1 for the notice at the top.
              itemCount: books.length + 1,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const AppPageBody(
                    child: FormValidationMessage(
                      type: FormMessageType.info,
                      message:
                          'Kutubtan waa tusaale: kaliya xadiisyo kooban oo tijaabo ah ayaa ku jira, '
                          'mana aha kutubta oo dhammaystiran.',
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
                            MetaChip(label: '$chapters cutub'),
                            MetaChip(label: '$hadiths xadiis'),
                            if (!book.isVerified) const DemoContentBadge(label: 'Tusaale'),
                          ],
                    onTap: () => context.go(AppRoutes.book(book.id)),
                  ),
                );
              },
            ),
    );
  }
}
