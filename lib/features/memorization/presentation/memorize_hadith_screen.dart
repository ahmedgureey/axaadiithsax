import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/not_found_screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../hadith/hadith_actions.dart';
import '../../hadith/presentation/widgets/arabic_font_controls.dart';

/// Focused memorisation view: text, translation, status and the actions
/// needed while memorising. The full reader stays available via a link.
class MemorizeHadithScreen extends StatelessWidget {
  const MemorizeHadithScreen({super.key, required this.hadithId});

  final String hadithId;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    final m = services.memorization;
    final hadith = repo.hadithById(hadithId);
    if (hadith == null) {
      if (services.catalog == null) {
        return const NotFoundScreen(
          title: 'Xadiiskan lama helin',
          message: 'Xadiiska qorshaha kuma jiro xogta app-ka.',
        );
      }
      // Backend: download it first; "not found" only if it truly isn't published.
      return EnsureHadiths(
        ids: [hadithId],
        builder: (context, loading, failure, retry) {
          if (repo.hadithById(hadithId) != null) return MemorizeHadithScreen(hadithId: hadithId);
          if (loading) return const Scaffold(body: LoadingIndicator(message: 'Xadiiska waa la soo rarayaa'));
          if (failure != null) {
            return Scaffold(
              appBar: AppBar(),
              body: ErrorStateWidget(title: 'Xadiiska lama soo rari karin', message: failure.message, onRetry: retry),
            );
          }
          return const NotFoundScreen(
            title: 'Xadiiskan lama helin',
            message: 'Xadiiskan kuma jiro, ama weli lama daabicin.',
          );
        },
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([m, services.settings, services.repository, ?services.catalog]),
      builder: (context, _) {
        final memorized = m.isMemorized(hadith.id);
        final record = m.recordOf(hadith.id);
        final next = m.nextPlanned(afterId: hadith.id);
        final c = context.appColors;
        return Scaffold(
          appBar: AppTopBar(title: 'Xifdi', subtitle: repo.bookById(hadith.bookId)?.nameSomali),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              AppPageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        MetaChip(label: repo.referenceLabel(hadith), color: c.goldText),
                        MetaChip(
                          label: memorized ? 'La xifdiyey' : 'Weli lama xifdin',
                          icon: memorized ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          color: memorized ? c.success : c.textSecondary,
                        ),
                        if (!hadith.isVerified) const DemoContentBadge(),
                      ],
                    ),
                    AppSpacing.gapMd,
                    Align(
                      alignment: Alignment.centerRight,
                      child: ArabicFontControls(settings: services.settings),
                    ),
                    AppSpacing.gapXs,
                    ArabicText(hadith.arabicText, selectable: true),
                    const OrnamentDivider(verticalPadding: AppSpacing.md),
                    Text('Tarjumaadda Af Soomaaliga', style: context.textStyles.labelMedium),
                    AppSpacing.gapXxs,
                    Text(
                      hadith.somaliText ?? missingTranslationText,
                      style: ArabicTextStyles.somaliTranslation(context),
                    ),
                    AppSpacing.gapXl,
                    if (!memorized)
                      PrimaryButton(
                        label: 'Waan Xifdiyey',
                        icon: Icons.check_rounded,
                        onPressed: () async {
                          final added = await m.markMemorized(hadith.id);
                          if (added && context.mounted) {
                            AppSnackbar.show(
                              context,
                              m.isTodayComplete ? 'Hambalyo! Qorshaha maanta waa dhammaaday.' : 'Waa la diiwaangeliyay',
                              type: AppSnackType.success,
                            );
                          }
                        },
                      )
                    else ...[
                      FormValidationMessage(
                        type: FormMessageType.success,
                        message: 'La xifdiyey ${record?.memorizedOn}. Dib-u-eegista xigta: ${record?.nextReviewOn}.',
                      ),
                      AppSpacing.gapSm,
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Dib-u-eegis mar dambe',
                              icon: Icons.flag_outlined,
                              onPressed: record?.flagged ?? false
                                  ? null
                                  : () async {
                                      if (await m.markForReview(hadith.id) && context.mounted) {
                                        AppSnackbar.show(context, 'Waxaa lagu daray liiska dib-u-eegista');
                                      }
                                    },
                            ),
                          ),
                          AppSpacing.gapSm,
                          Expanded(
                            child: AppTextButton(
                              label: 'Ka noqo',
                              icon: Icons.undo_rounded,
                              onPressed: () => m.undoMemorized(hadith.id),
                            ),
                          ),
                        ],
                      ),
                    ],
                    AppSpacing.gapSm,
                    if (next != null)
                      SecondaryButton(
                        label: 'Xadiiska xiga',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => context.pushReplacement(AppRoutes.memorizeHadith(next)),
                      )
                    else if (m.isTodayComplete)
                      SecondaryButton(
                        label: 'Ku noqo Xifdintayda',
                        onPressed: () => context.go(AppRoutes.memorization),
                      ),
                    AppTextButton(
                      label: 'Fur bogga xadiiska oo dhan',
                      icon: Icons.open_in_new_rounded,
                      onPressed: () => context.push(AppRoutes.hadith(hadith.id)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
