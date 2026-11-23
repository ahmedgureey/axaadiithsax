import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/not_found_screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/search_options.dart';
import 'widgets/search_result_card.dart';

/// Hadith records of one topic. Unknown IDs → not-found; empty topics get a
/// friendly explanation.
class CategoryResultsScreen extends StatelessWidget {
  const CategoryResultsScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final search = context.services.search;
    final category = context.services.repository.categoryById(categoryId);
    if (category == null) {
      return const NotFoundScreen(title: 'Mowduucan lama helin', message: 'Mowduuca aad dooratay kuma jiro app-ka.');
    }
    final results = search.search(filters: SearchFilters(categoryIds: {category.id}));
    final colors = context.appColors;

    final header = AppPageBody(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: colors.goldSubtle, shape: BoxShape.circle),
              child: Icon(categoryIcon(category.iconKey), color: colors.goldText, size: AppSizes.iconLg),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ArabicText(category.nameArabic, variant: ArabicTextVariant.chapterHeading, maxLines: 1),
                  if (category.description.isNotEmpty) Text(category.description, style: context.textStyles.bodyMedium),
                  Semantics(
                    liveRegion: true,
                    child: Text('${results.length} natiijo', style: context.textStyles.labelMedium),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppTopBar(
        title: category.nameSomali,
        actions: [
          IconActionButton(
            icon: Icons.manage_search_rounded,
            tooltip: 'Ku raadi mowduucan',
            onPressed: () => context.go(AppRoutes.searchWith(categoryId: category.id)),
          ),
        ],
      ),
      body: results.isEmpty
          ? Column(
              children: [
                AppSpacing.gapMd,
                header,
                Expanded(
                  child: EmptyStateWidget(
                    icon: Icons.inbox_outlined,
                    title: 'Weli xadiis lama hayo',
                    message: 'Mowduucan weli xadiis kuma jiro.',
                    actionLabel: 'Eeg mowduucyada kale',
                    onAction: () => context.go(AppRoutes.categories),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              itemCount: results.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return header;
                final h = results[i - 1];
                return AppPageBody(
                  key: ValueKey(h.id),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  child: SearchResultCard(hadith: h),
                );
              },
            ),
    );
  }
}
