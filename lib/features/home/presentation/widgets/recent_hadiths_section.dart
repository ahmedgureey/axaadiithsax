import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_services.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';
import '../../../hadith/presentation/hadith_preview_card.dart';

/// Shows recently viewed hadith from reading history. Without history it
/// shows deterministic featured demo hadith under an honest title — it never
/// claims something was read when it wasn't.
class RecentHadithsSection extends StatelessWidget {
  const RecentHadithsSection({super.key, required this.featured});

  static const recentTitle = 'Xadiisyadii Ugu Dambeeyey';
  static const featuredTitle = 'Xadiisyo la soo Xulay';

  final List<Hadith> featured;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    return ListenableBuilder(
      listenable: services.history,
      builder: (context, _) {
        final recent = [for (final id in services.history.recentIds) ?repo.hadithById(id)].take(3).toList();
        final hasHistory = recent.isNotEmpty;
        final items = hasHistory ? recent : featured;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: context.tr(hasHistory ? AppText.homeRecent : AppText.homeFeatured),
              actionLabel: context.tr(AppText.seeAll),
              onAction: () => context.go(AppRoutes.books),
            ),
            if (!hasHistory)
              Text('Weli wax xadiis ah ma aadan akhrin — kuwan waa tusaalooyin.', style: context.textStyles.bodySmall),
            AppSpacing.gapSm,
            if (items.isEmpty)
              Text('Xadiis lama helin.', style: context.textStyles.bodySmall)
            else
              for (final h in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: HadithPreviewCard(hadith: h),
                ),
          ],
        );
      },
    );
  }
}
