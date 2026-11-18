import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/hadith.dart';
import '../../hadith/hadith_actions.dart';

/// Review session for memorised hadith that are due.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  static const title = 'Dib-u-eegis';

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  /// Reviews completed while this screen is open.
  int _sessionCount = 0;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final m = services.memorization;
    return Scaffold(
      appBar: const AppTopBar(title: ReviewScreen.title),
      body: ListenableBuilder(
        listenable: m,
        builder: (context, _) {
          final due = [for (final r in m.dueForReview) ?services.repository.hadithById(r.hadithId)];
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              AppPageBody(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Fadhigan: $_sessionCount dib-u-eegis · ${due.length} ayaa haray',
                    style: context.textStyles.titleMedium,
                  ),
                ),
              ),
              AppPageBody(child: Text(m.schedule.description, style: context.textStyles.bodySmall)),
              AppSpacing.gapMd,
              if (due.isEmpty)
                SizedBox(
                  height: 320,
                  child: EmptyStateWidget(
                    icon: Icons.task_alt_rounded,
                    title: _sessionCount > 0
                        ? 'Hambalyo! Dib-u-eegistii waa dhammaatay.'
                        : 'Wax dib-u-eegis ah ma jiro maanta',
                    message: 'Xadiisyada aad xifdiso waxay halkan ku soo muuqan doonaan marka la gaaro waqtigooda.',
                    actionLabel: 'Ku noqo Xifdintayda',
                    onAction: () => context.go(AppRoutes.memorization),
                  ),
                )
              else
                for (final h in due)
                  AppPageBody(
                    key: ValueKey(h.id),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    child: _ReviewCard(
                      hadith: h,
                      onDone: () async {
                        if (await m.completeReview(h.id)) setState(() => _sessionCount++);
                      },
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.hadith, required this.onDone});

  final Hadith hadith;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    final record = services.memorization.recordOf(hadith.id);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              MetaChip(label: repo.bookById(hadith.bookId)?.nameSomali ?? '—', icon: Icons.menu_book_rounded),
              MetaChip(label: repo.referenceLabel(hadith), color: context.appColors.goldText),
              if (record?.flagged ?? false) MetaChip(label: 'Adiga ayaa calaamadeeyay', icon: Icons.flag_outlined),
            ],
          ),
          AppSpacing.gapSm,
          ArabicText(hadith.arabicText),
          AppSpacing.gapXs,
          Text(hadith.somaliText ?? missingTranslationText, style: context.textStyles.bodyMedium),
          AppSpacing.gapMd,
          Row(
            children: [
              Expanded(
                child: PrimaryButton(label: 'Waan dib u eegay', icon: Icons.check_rounded, onPressed: onDone),
              ),
              AppSpacing.gapXs,
              IconActionButton(
                icon: Icons.open_in_new_rounded,
                tooltip: 'Fur xadiiska',
                onPressed: () => context.push(AppRoutes.hadith(hadith.id)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
