import 'package:flutter/material.dart';

import '../../../../app/app_services.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/widgets/widgets.dart';

/// Shown before the user types or filters: recent searches + topics.
class SearchInitialView extends StatelessWidget {
  const SearchInitialView({
    super.key,
    required this.onTerm,
    required this.onCategory,
    required this.onBrowseCategories,
  });

  final ValueChanged<String> onTerm;
  final ValueChanged<String> onCategory;
  final VoidCallback onBrowseCategories;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final history = services.searchHistory;
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
      children: [
        ListenableBuilder(
          listenable: history,
          builder: (context, _) {
            if (history.terms.isEmpty) {
              return AppPageBody(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'Qor eray Carabi ama Soomaali ah.',
                    style: context.textStyles.bodyMedium?.copyWith(color: context.appColors.textSecondary),
                  ),
                ),
              );
            }
            return AppPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(title: 'Raadintii dhowayd', actionLabel: 'Tirtir dhammaan', onAction: history.clear),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final term in history.terms)
                        InputChip(
                          avatar: const Icon(Icons.history_rounded, size: 18),
                          label: Text(term),
                          onPressed: () => onTerm(term),
                          onDeleted: () => history.remove(term),
                          deleteButtonTooltipMessage: 'Ka saar "$term"',
                        ),
                    ],
                  ),
                  AppSpacing.gapLg,
                ],
              ),
            );
          },
        ),
        // Only words that really return results are suggested.
        if (_workingSuggestions(context) case final words when words.isNotEmpty) ...[
          const AppPageBody(child: SectionHeader(title: suggestionsTitle)),
          AppSpacing.gapXs,
          AppPageBody(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final w in words)
                  ActionChip(
                    avatar: const Icon(Icons.search_rounded, size: 18),
                    label: Text(w),
                    onPressed: () => onTerm(w),
                  ),
              ],
            ),
          ),
          AppSpacing.gapLg,
        ],
        if (services.search.categories.isNotEmpty) ...[
          AppPageBody(
            child: SectionHeader(title: 'Mowduucyo', actionLabel: 'Dhammaan', onAction: onBrowseCategories),
          ),
          AppPageBody(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final c in services.search.categories)
                  ActionChip(
                    avatar: Icon(categoryIcon(c.iconKey), size: 18),
                    label: Text(c.nameSomali),
                    onPressed: () => onCategory(c.id),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static const suggestionsTitle = 'Erayo la raadiyo';

  /// Candidate words, in display order.
  static const suggestions = [
    'Niyad',
    'Salaad',
    'Iimaan',
    'Jannada',
    'Sadaqo',
    'Zakada',
    'Walaal',
    'Naxariis',
    'Taqwa',
    'Dulmi',
    'Sunnada',
  ];

  List<String> _workingSuggestions(BuildContext context) {
    final search = context.services.search;
    return [
      for (final w in suggestions)
        if (search.search(query: w).isNotEmpty) w,
    ];
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
