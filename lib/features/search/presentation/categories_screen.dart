import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/widgets/widgets.dart';

/// "Mowduucyada Xadiiska" — every topic with its real record count.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const title = 'Mowduucyada Xadiiska';

  @override
  Widget build(BuildContext context) {
    final search = context.services.search;
    final categories = search.categories;
    return Scaffold(
      appBar: const AppTopBar(title: title),
      body: categories.isEmpty
          ? const EmptyStateWidget(icon: Icons.label_outline_rounded, title: 'Mowduuc lama helin')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              itemCount: categories.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                final c = categories[i];
                final count = search.countForCategory(c.id);
                final colors = context.appColors;
                return AppPageBody(
                  child: AppCard(
                    semanticLabel: '${c.nameSomali}, $count xadiis',
                    onTap: () => context.go(AppRoutes.categoryResults(c.id)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(color: colors.goldSubtle, shape: BoxShape.circle),
                          child: Icon(categoryIcon(c.iconKey), color: colors.goldText),
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(c.nameSomali, style: context.textStyles.titleMedium),
                              ArabicText(c.nameArabic, variant: ArabicTextVariant.label, maxLines: 1),
                              if (c.description.isNotEmpty) Text(c.description, style: context.textStyles.bodySmall),
                              AppSpacing.gapXxs,
                              Align(
                                alignment: Alignment.centerLeft,
                                child: count == 0
                                    ? MetaChip(label: 'Weli xadiis ma jiro', color: colors.warning)
                                    : MetaChip(label: '$count xadiis'),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
