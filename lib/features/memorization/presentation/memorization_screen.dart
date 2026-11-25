import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import 'widgets/daily_goal_card.dart';
import 'widgets/memorization_hadith_tile.dart';
import 'widgets/weekly_progress_chart.dart';

/// Tab 4 — "Xifdintayda". Every number comes from recorded activity; a new
/// user starts at zero (no sample statistics).
class MemorizationScreen extends StatelessWidget {
  const MemorizationScreen({super.key});

  static const title = 'Xifdintayda';

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final m = services.memorization;
    final repo = services.repository;

    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleMemorization), showOrnament: true),
      body: ListenableBuilder(
        listenable: Listenable.merge([m, context.services.repository]),
        builder: (context, _) {
          if (!m.isLoaded) return const LoadingIndicator(message: 'Waa la soo rarayaa…');
          if (m.loadFailed) {
            return ErrorStateWidget(
              title: 'Horumarka lama soo rari karin',
              message: 'Kaydka qalabka lama akhrin karin.',
              onRetry: m.load,
            );
          }
          if (m.totalAvailable == 0) {
            return const EmptyStateWidget(
              icon: Icons.psychology_outlined,
              title: 'Xadiis lama heli karo',
              message: noVerifiedHadithMessage,
            );
          }
          final due = m.dueForReview.length;
          final recent = [for (final r in m.recentlyMemorized.take(3)) ?repo.hadithById(r.hadithId)];
          final quizzes = m.quizHistory.take(3).toList();
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              AppPageBody(
                child: DailyGoalCard(
                  controller: m,
                  onStart: () {
                    final next = m.nextPlanned();
                    context.go(next == null ? AppRoutes.memorizationPlan : AppRoutes.memorizeHadith(next));
                  },
                  onChangeTarget: () => showDailyTargetSheet(context, m),
                  onOpenPlan: () => context.go(AppRoutes.memorizationPlan),
                ),
              ),
              AppSpacing.gapMd,
              AppPageBody(
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.replay_rounded,
                        title: 'Dib-u-eegis',
                        subtitle: due == 0 ? 'Ma jiro mid sugaya' : '$due ayaa sugaya',
                        highlight: due > 0,
                        onTap: () => context.go(AppRoutes.memorizationReview),
                      ),
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.quiz_outlined,
                        title: 'Imtixaan',
                        subtitle: 'Is tijaabi',
                        onTap: () => context.push(AppRoutes.quiz),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapXl,
              const AppPageBody(child: SectionHeader(title: 'Horumarkaaga')),
              AppSpacing.gapXs,
              AppPageBody(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatsRow(
                        items: [
                          _Stat(Icons.menu_book_rounded, '${m.memorizedCount}/${m.totalAvailable}', 'La xifdiyey'),
                          _Stat(Icons.history_rounded, '$due', 'Sugaya'),
                          _Stat(Icons.local_fire_department_rounded, m.streak == 0 ? '—' : '${m.streak}', 'Silsilad'),
                          _Stat(Icons.task_alt_rounded, '${m.reviewsCompletedToday}', 'Maanta'),
                        ],
                      ),
                      AppSpacing.gapMd,
                      Semantics(
                        label: 'Horumarka guud: ${(m.overallProgress * 100).round()} boqolkiiba',
                        excludeSemantics: true,
                        child: ClipRRect(
                          borderRadius: AppRadius.pillAll,
                          child: LinearProgressIndicator(value: m.overallProgress, minHeight: 6),
                        ),
                      ),
                      AppSpacing.gapXxs,
                      Text(
                        '${(m.overallProgress * 100).round()}% ee ${m.totalAvailable}-ka xadiis',
                        style: context.textStyles.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.gapXl,
              const AppPageBody(child: SectionHeader(title: 'Toddobaadkan')),
              AppSpacing.gapSm,
              AppPageBody(
                child: AppCard(child: WeeklyProgressChart(days: m.recentDays())),
              ),
              AppSpacing.gapXl,
              const AppPageBody(child: SectionHeader(title: 'Imtixaannadii u dambeeyay')),
              AppSpacing.gapSm,
              AppPageBody(
                child: quizzes.isEmpty
                    ? Text('Weli imtixaan ma jiro.', style: context.textStyles.bodySmall)
                    : Column(
                        children: [
                          for (final q in quizzes)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.quiz_outlined),
                              title: Text('${q.correct} / ${q.total} sax (${q.percentage}%)'),
                              subtitle: Text(q.day),
                            ),
                        ],
                      ),
              ),
              AppSpacing.gapXl,
              const AppPageBody(child: SectionHeader(title: 'Dhawaan la xifdiyey')),
              AppSpacing.gapSm,
              if (recent.isEmpty)
                AppPageBody(child: Text('Weli xadiis ma xifdin.', style: context.textStyles.bodySmall))
              else
                for (final h in recent)
                  AppPageBody(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                    child: MemorizationHadithTile(
                      hadith: h,
                      subtitle: 'La xifdiyey: ${m.recordOf(h.id)?.memorizedOn}',
                      onTap: () => context.go(AppRoutes.memorizeHadith(h.id)),
                    ),
                  ),
              AppPageBody(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(m.schedule.description, style: context.textStyles.bodySmall),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat {
  const _Stat(this.icon, this.value, this.label);
  final IconData icon;
  final String value;
  final String label;
}

/// Four numbers side by side (icon, value, short label).
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});
  final List<_Stat> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in items)
          Expanded(
            child: Semantics(
              label: '${s.label}: ${s.value}',
              excludeSemantics: true,
              child: Column(
                children: [
                  Icon(s.icon, size: 20, color: context.appColors.goldText),
                  AppSpacing.gapXxs,
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(s.value, style: context.textStyles.titleMedium),
                  ),
                  Text(
                    s.label,
                    style: context.textStyles.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Large tappable tile for the main actions (review, quiz).
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AppCard(
      onTap: onTap,
      semanticLabel: '$title: $subtitle',
      color: highlight ? scheme.primaryContainer : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.10), borderRadius: AppRadius.smAll),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          AppSpacing.gapSm,
          Text(title, style: context.textStyles.titleSmall),
          Text(subtitle, style: context.textStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
