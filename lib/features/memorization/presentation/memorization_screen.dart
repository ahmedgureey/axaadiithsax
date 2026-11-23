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
                child: Text(
                  m.hasAnyActivity
                      ? 'Si fiican ayaad u socotaa — sii wad maalin kasta.'
                      : 'Ku bilow xadiis keliya maanta.',
                  style: context.textStyles.bodyLarge,
                ),
              ),
              AppSpacing.gapMd,
              AppPageBody(
                child: DailyGoalCard(
                  controller: m,
                  onStart: () {
                    final next = m.nextPlanned();
                    context.go(next == null ? AppRoutes.memorizationPlan : AppRoutes.memorizeHadith(next));
                  },
                  onChangeTarget: () => showDailyTargetSheet(context, m),
                ),
              ),
              AppSpacing.gapSm,
              AppPageBody(
                child: AppTextButton(
                  label: 'Eeg qorshaha maanta',
                  icon: Icons.list_alt_rounded,
                  onPressed: () => context.go(AppRoutes.memorizationPlan),
                ),
              ),
              AppSpacing.gapMd,
              AppPageBody(
                child: _StatsGrid(
                  items: [
                    _Stat(Icons.menu_book_rounded, '${m.memorizedCount} / ${m.totalAvailable}', 'Wadarta la xifdiyey'),
                    _Stat(Icons.history_rounded, '$due', 'Dib-u-eegis sugaya'),
                    _Stat(
                      Icons.local_fire_department_rounded,
                      m.streak == 0 ? '—' : '${m.streak}',
                      m.streak == 0 ? 'Weli silsilad ma jirto' : 'Maalmood oo isku xiga',
                    ),
                    _Stat(Icons.task_alt_rounded, '${m.reviewsCompletedToday}', 'Dib-u-eegis maanta'),
                  ],
                ),
              ),
              AppSpacing.gapSm,
              AppPageBody(
                child: Semantics(
                  label: 'Horumarka guud: ${(m.overallProgress * 100).round()} boqolkiiba',
                  excludeSemantics: true,
                  child: ClipRRect(
                    borderRadius: AppRadius.pillAll,
                    child: LinearProgressIndicator(value: m.overallProgress, minHeight: 6),
                  ),
                ),
              ),
              AppSpacing.gapLg,
              AppPageBody(
                child: Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: due == 0 ? 'Dib-u-eegis' : 'Dib-u-eegis ($due)',
                        icon: Icons.replay_rounded,
                        onPressed: () => context.go(AppRoutes.memorizationReview),
                      ),
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: SecondaryButton(
                        label: 'Imtixaan',
                        icon: Icons.quiz_outlined,
                        onPressed: () => context.push(AppRoutes.quiz),
                      ),
                    ),
                  ],
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
                    ? Text('Weli imtixaan ma aadan gelin.', style: context.textStyles.bodySmall)
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
              const AppPageBody(child: SectionHeader(title: 'Kuwii aan dhawaan xifdiyey')),
              AppSpacing.gapSm,
              if (recent.isEmpty)
                AppPageBody(child: Text('Weli xadiis ma aadan xifdin.', style: context.textStyles.bodySmall))
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});
  final List<_Stat> items;

  @override
  Widget build(BuildContext context) {
    Widget tile(_Stat s) => Semantics(
      label: '${s.label}: ${s.value}',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(s.icon, color: context.appColors.goldText),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.value, style: context.textStyles.titleMedium),
                  Text(s.label, style: context.textStyles.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          if (i > 0) AppSpacing.gapSm,
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(items[i])),
                AppSpacing.gapSm,
                Expanded(child: i + 1 < items.length ? tile(items[i + 1]) : const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
