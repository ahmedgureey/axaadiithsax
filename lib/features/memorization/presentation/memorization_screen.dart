import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../hadith/hadith_actions.dart';

/// Tab 4 — Xifdinta.
class MemorizationScreen extends StatelessWidget {
  const MemorizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    final plan = services.memorization;

    return Scaffold(
      appBar: const AppTopBar(title: 'Xifdinta', showOrnament: true),
      body: ListenableBuilder(
        listenable: plan,
        builder: (context, _) {
          final next = plan.nextHadithId;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              AppPageBody(
                child: MemorizationProgressCard(
                  title: 'Qorshahayga maanta',
                  subtitle: 'Qorshe tusaale ah · ${plan.total} xadiis',
                  memorized: plan.memorizedCount,
                  total: plan.total,
                  onContinue: next == null ? null : () => context.push(AppRoutes.hadith(next)),
                ),
              ),
              AppSpacing.gapMd,
              AppPageBody(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  onTap: () => context.push(AppRoutes.quiz),
                  child: ListTile(
                    leading: Icon(Icons.quiz_outlined, color: context.appColors.goldText),
                    title: const Text('Imtixaan'),
                    subtitle: const Text('Is tijaabi waxa aad xifdisay'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
              AppSpacing.gapSm,
              AppPageBody(
                child: Text(
                  'Jadwalka dib-u-eegista wuxuu iman doonaa marxaladda xigta.',
                  style: context.textStyles.bodySmall,
                ),
              ),
              AppSpacing.gapXl,
              const AppPageBody(child: SectionHeader(title: 'Xadiisyada qorshaha')),
              AppSpacing.gapSm,
              for (final (index, id) in plan.planHadithIds.indexed)
                if (repo.hadithById(id) case final h?)
                  AppPageBody(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      onTap: () => context.push(AppRoutes.hadith(h.id)),
                      child: ListTile(
                        leading: Icon(
                          plan.isMemorized(h.id) ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          color: plan.isMemorized(h.id)
                              ? context.appColors.success
                              : context.appColors.textSecondary,
                          semanticLabel: plan.isMemorized(h.id) ? 'La xifdiyay' : 'Lama xifdin',
                        ),
                        title: Text('Xadiis ${index + 1} · ${repo.bookById(h.bookId)?.nameSomali ?? ''}'),
                        subtitle: Text(
                          h.somaliText ?? missingTranslationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
