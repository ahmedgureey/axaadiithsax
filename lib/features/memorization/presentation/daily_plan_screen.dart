import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import 'widgets/daily_goal_card.dart';
import 'widgets/memorization_hadith_tile.dart';

/// Today's assigned hadith with their status.
class DailyPlanScreen extends StatelessWidget {
  const DailyPlanScreen({super.key});

  static const title = 'Qorshaha maanta';

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final m = services.memorization;
    return Scaffold(
      appBar: const AppTopBar(title: title),
      body: ListenableBuilder(
        listenable: m,
        builder: (context, _) {
          final plan = [for (final id in m.todayPlan) ?services.repository.hadithById(id)];
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              AppPageBody(
                child: DailyGoalCard(
                  controller: m,
                  onStart: () {
                    final next = m.nextPlanned();
                    if (next != null) context.go(AppRoutes.memorizeHadith(next));
                  },
                  onChangeTarget: () => showDailyTargetSheet(context, m),
                ),
              ),
              AppSpacing.gapLg,
              if (plan.isEmpty)
                const SizedBox(
                  height: 280,
                  child: EmptyStateWidget(
                    icon: Icons.celebration_outlined,
                    title: 'Xadiis kale lama hayo',
                    message: 'Dhammaan xadiisyada la heli karo waad xifdisay. Isku day dib-u-eegis.',
                  ),
                )
              else
                for (final h in plan)
                  AppPageBody(
                    key: ValueKey(h.id),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                    child: MemorizationHadithTile(
                      hadith: h,
                      onTap: () => context.go(AppRoutes.memorizeHadith(h.id)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
