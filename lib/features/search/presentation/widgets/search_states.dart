import 'package:flutter/material.dart';

import '../../../../app/app_services.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/widgets/widgets.dart';

/// Shown before the user types or filters. Nothing is listed (no hints,
/// suggestions or recent searches); only server topics, when a backend
/// provides them.
class SearchInitialView extends StatelessWidget {
  const SearchInitialView({super.key, required this.onCategory, required this.onBrowseCategories});

  final ValueChanged<String> onCategory;
  final VoidCallback onBrowseCategories;

  @override
  Widget build(BuildContext context) {
    final categories = context.services.search.categories;
    if (categories.isEmpty) return const SizedBox.expand();
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
      children: [
        AppPageBody(
          child: SectionHeader(title: 'Mowduucyo', actionLabel: 'Dhammaan', onAction: onBrowseCategories),
        ),
        AppPageBody(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final c in categories)
                ActionChip(
                  avatar: Icon(categoryIcon(c.iconKey), size: 18),
                  label: Text(c.nameSomali),
                  onPressed: () => onCategory(c.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Wax natiijo ah lama helin." with concrete suggestions.
class SearchNoResultsView extends StatelessWidget {
  const SearchNoResultsView({
    super.key,
    required this.hasFilters,
    required this.onResetFilters,
    required this.onBrowseCategories,
  });

  static const title = 'Wax natiijo ah lama helin.';

  final bool hasFilters;
  final VoidCallback onResetFilters;
  final VoidCallback onBrowseCategories;

  @override
  Widget build(BuildContext context) {
    final tips = [
      'Hubi higgaadda erayga.',
      'Isku day eray ka gaaban.',
      if (hasFilters) 'Ka saar qaar ka mid ah shaandhaynta.',
      'Baadh mowduucyada la heli karo.',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: AppPageBody(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: context.appColors.goldSubtle, shape: BoxShape.circle),
              child: Icon(Icons.search_off_rounded, size: 40, color: context.appColors.goldText),
            ),
            AppSpacing.gapLg,
            Text(title, style: context.textStyles.titleLarge, textAlign: TextAlign.center),
            AppSpacing.gapSm,
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text('• $tip', style: context.textStyles.bodyMedium, textAlign: TextAlign.center),
              ),
            AppSpacing.gapLg,
            if (hasFilters) ...[
              SecondaryButton(label: 'Ka saar shaandhaynta', onPressed: onResetFilters, expanded: false),
              AppSpacing.gapSm,
            ],
            AppTextButton(label: 'Eeg mowduucyada', onPressed: onBrowseCategories),
          ],
        ),
      ),
    );
  }
}
