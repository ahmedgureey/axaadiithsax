import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/widgets/widgets.dart';
import '../../home_feed.dart';

/// "Mowduucyada" — topic tiles that open the Search tab filtered by topic.
class HadithCategoriesSection extends StatelessWidget {
  const HadithCategoriesSection({super.key, required this.categories});

  final List<CategorySummary> categories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Mowduucyada', actionLabel: 'Dhammaan', onAction: () => context.go(AppRoutes.categories)),
        AppSpacing.gapSm,
        if (categories.isEmpty)
          Text('Mowduuc lama helin.', style: context.textStyles.bodySmall)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = AppSpacing.xs;
              final columns = constraints.maxWidth >= 560 ? 8 : 4;
              final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final c in categories)
                    SizedBox(
                      width: tileWidth,
                      child: _CategoryTile(summary: c),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.summary});

  final CategorySummary summary;

  @override
  Widget build(BuildContext context) {
    final c = summary.category;
    final appColors = context.appColors;
    final labelStyle = context.textStyles.labelMedium?.copyWith(color: context.colors.onSurface);
    // Every tile reserves room for two label lines, so all tiles have the same
    // height (and icons line up) whether a name fits on one line or needs two.
    final lineHeight = MediaQuery.textScalerOf(context).scale(labelStyle?.fontSize ?? 12) * (labelStyle?.height ?? 1.3);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs, vertical: AppSpacing.sm),
      semanticLabel: '${c.nameSomali}, ${summary.hadithCount} xadiis',
      onTap: () => context.go(AppRoutes.categoryResults(c.id)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(color: appColors.goldSubtle, shape: BoxShape.circle),
            child: Icon(categoryIcon(c.iconKey), color: appColors.goldText, size: AppSizes.icon),
          ),
          AppSpacing.gapXs,
          SizedBox(
            height: lineHeight * 2,
            child: Center(
              child: Text(
                c.nameSomali,
                style: labelStyle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
