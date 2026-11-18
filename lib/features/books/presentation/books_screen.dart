import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Tab 2 — Kutubta: hadith collections.
class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    final books = repo.books;
    return Scaffold(
      appBar: const AppTopBar(title: 'Kutubta', showOrnament: true),
      body: books.isEmpty
          ? const EmptyStateWidget(icon: Icons.auto_stories_outlined, title: 'Kutub lama helin')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              itemCount: books.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                final book = books[i];
                return AppPageBody(
                  child: BookCard(
                    titleSomali: book.nameSomali,
                    titleArabic: book.nameArabic,
                    author: book.author,
                    countLabel: repo.chaptersOf(book.id).isEmpty
                        ? 'Weli lama darin'
                        : '${repo.chaptersOf(book.id).length} cutub (tusaale)',
                    onTap: () => context.go(AppRoutes.book(book.id)),
                  ),
                );
              },
            ),
    );
  }
}
