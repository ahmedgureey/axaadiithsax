import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/quiz_models.dart';

/// Results computed from the submitted answers in [result].
class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({super.key, this.result});

  /// Null when opened without a quiz (deep link / refresh).
  final QuizResult? result;

  static String messageFor(int percentage) => switch (percentage) {
    >= 80 => 'Aad baad u fiicantahay! Sii wad dib-u-eegista.',
    >= 50 => 'Waa bilow wanaagsan. Dib u eeg kuwa aad khaldantay.',
    _ => 'Ha quusan — dib u akhri xadiisyada oo mar kale isku day.',
  };

  static String formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m == 0 ? '$s ilbiriqsi' : '$m daqiiqo $s ilbiriqsi';
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Scaffold(
      appBar: AppTopBar(
        title: 'Natiijada',
        leading: IconButton(
          tooltip: 'Xir',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go(AppRoutes.memorization),
        ),
      ),
      body: r == null || r.total == 0
          ? EmptyStateWidget(
              icon: Icons.quiz_outlined,
              title: 'Natiijo lama helin',
              message: 'Samee imtixaan si aad natiijo u aragto.',
              actionLabel: 'Ku noqo Xifdinta',
              onAction: () => context.go(AppRoutes.memorization),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppPageBody(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        label: '${r.correct} ka mid ah ${r.total} waa sax, ${r.percentage} boqolkiiba',
                        excludeSemantics: true,
                        child: Column(
                          children: [
                            Text('${r.percentage}%', style: context.textStyles.displaySmall),
                            Text('${r.correct} / ${r.total} sax', style: context.textStyles.titleMedium),
                          ],
                        ),
                      ),
                      AppSpacing.gapSm,
                      Text(messageFor(r.percentage), style: context.textStyles.bodyLarge, textAlign: TextAlign.center),
                      AppSpacing.gapLg,
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          MetaChip(label: 'Wadar: ${r.total}', icon: Icons.list_rounded),
                          MetaChip(
                            label: 'Sax: ${r.correct}',
                            icon: Icons.check_circle_outline,
                            color: context.appColors.success,
                          ),
                          MetaChip(
                            label: 'Khalad: ${r.incorrect}',
                            icon: Icons.cancel_outlined,
                            color: context.colors.error,
                          ),
                          if (r.duration != null)
                            MetaChip(label: formatDuration(r.duration!), icon: Icons.timer_outlined),
                        ],
                      ),
                      AppSpacing.gapSm,
                      Text(
                        'Natiijadani waxay ku salaysan tahay xogta app-ka; ma cabbirayso aqoontaada diineed oo dhan.',
                        style: context.textStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapXl,
                      PrimaryButton(
                        label: 'Isku day mar kale',
                        icon: Icons.replay_rounded,
                        onPressed: () => context.pushReplacement(AppRoutes.quizPlay, extra: r.config),
                      ),
                      AppSpacing.gapSm,
                      SecondaryButton(label: 'Ku noqo Xifdinta', onPressed: () => context.go(AppRoutes.memorization)),
                      if (r.incorrectIndexes.isNotEmpty) ...[
                        AppSpacing.gapXl,
                        const SectionHeader(title: 'Kuwii aad khaldantay'),
                        AppSpacing.gapSm,
                        for (final i in r.incorrectIndexes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('${i + 1}. ${r.questions[i].prompt}', style: context.textStyles.titleSmall),
                                  AppSpacing.gapXxs,
                                  Text(
                                    r.answers[i] == null
                                        ? 'Lama jawaabin'
                                        : 'Jawaabtaada: ${r.questions[i].options[r.answers[i]!]}',
                                    style: context.textStyles.bodySmall?.copyWith(color: context.colors.error),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Saxda: ${r.questions[i].correctAnswer}',
                                    style: context.textStyles.bodySmall?.copyWith(color: context.appColors.success),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
