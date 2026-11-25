import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_services.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/widgets.dart';

/// Today's memorisation numbers from the real memorisation controller.
class HomeMemorizationSummary extends StatelessWidget {
  const HomeMemorizationSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.services.memorization;
    return ListenableBuilder(
      listenable: Listenable.merge([m, context.services.repository]),
      builder: (context, _) {
        final due = m.dueForReview.length;
        final subtitle = m.plannedToday == 0
            ? 'Dhammaan waad xifdisay. Mashaa Allah!'
            : due == 0
            ? 'Dib-u-eegis ma sugayso'
            : '$due dib-u-eegis ayaa sugaya';
        return MemorizationProgressCard(
          title: context.tr(AppText.homeMemorizationProgress),
          subtitle: subtitle,
          memorized: m.completedToday,
          total: m.plannedToday,
          streakDays: m.streak > 0 ? m.streak : null,
          onTap: () => context.go(AppRoutes.memorization),
        );
      },
    );
  }
}
