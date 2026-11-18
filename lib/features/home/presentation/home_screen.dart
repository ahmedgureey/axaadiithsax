import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/widgets/widgets.dart';
import '../../hadith/presentation/hadith_preview_card.dart';

/// Tab 1 — Guriga.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    final daily = repo.dailyHadith(DateTime.now());

    return Scaffold(
      appBar: AppTopBar(
        title: 'Xadiis App',
        subtitle: services.auth.displayName == null
            ? 'Assalaamu calaykum'
            : 'Assalaamu calaykum, ${services.auth.displayName}',
        showOrnament: true,
        actions: [
          IconActionButton(
            icon: Icons.bookmarks_outlined,
            tooltip: 'Kuwa la jecel yahay',
            onPressed: () => context.push(AppRoutes.favorites),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          if (daily != null)
            AppPageBody(
              child: DailyHadithCard(
                arabicText: daily.arabicText,
                somaliText: daily.somaliText,
                source: repo.bookById(daily.bookId)?.nameSomali ?? '',
                isVerified: daily.isVerified,
                onTap: () => context.push(AppRoutes.hadith(daily.id)),
              ),
            ),
          AppSpacing.gapLg,
          AppPageBody(
            child: Row(
              children: [
                Expanded(
                  child: CategoryCard(
                    title: 'Kuwa la jecel',
                    icon: Icons.bookmark_outline_rounded,
                    onTap: () => context.push(AppRoutes.favorites),
                  ),
                ),
                AppSpacing.gapSm,
                Expanded(
                  child: CategoryCard(
                    title: 'Xifdinta',
                    icon: Icons.psychology_outlined,
                    onTap: () => context.go(AppRoutes.memorization),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapXl,
          AppPageBody(
            child: SectionHeader(
              title: 'Kutubta',
              actionLabel: 'Dhammaan',
              onAction: () => context.go(AppRoutes.books),
            ),
          ),
          AppSpacing.gapSm,
          for (final book in repo.books.take(2))
            AppPageBody(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: BookCard(
                titleSomali: book.nameSomali,
                titleArabic: book.nameArabic,
                author: book.author,
                onTap: () => context.go(AppRoutes.book(book.id)),
              ),
            ),
          AppSpacing.gapLg,
          const AppPageBody(child: SectionHeader(title: 'Mawduucyada')),
          AppSpacing.gapSm,
          AppPageBody(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final c in repo.categories)
                  ActionChip(
                    avatar: Icon(categoryIcon(c.iconKey), size: 18),
                    label: Text(c.nameSomali),
                    onPressed: () => context.go(AppRoutes.searchCategory(c.id)),
                  ),
              ],
            ),
          ),
          AppSpacing.gapXl,
          const AppPageBody(child: SectionHeader(title: 'Dhowaan la akhriyay')),
          AppSpacing.gapSm,
          ListenableBuilder(
            listenable: services.history,
            builder: (context, _) {
              final recent = [for (final id in services.history.recentIds) ?repo.hadithById(id)]
                  .take(3)
                  .toList();
              if (recent.isEmpty) {
                return AppPageBody(
                  child: Text('Weli wax xadiis ah ma aadan akhrin.', style: context.textStyles.bodySmall),
                );
              }
              return Column(
                children: [
                  for (final h in recent)
                    AppPageBody(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                      child: HadithPreviewCard(hadith: h),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
