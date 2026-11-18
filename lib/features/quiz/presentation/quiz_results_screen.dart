import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Result passed to `/quiz/results` via `extra`.
class QuizResultArgs {
  const QuizResultArgs({required this.correct, required this.total, this.isDemo = false});
  final int correct;
  final int total;
  final bool isDemo;
}

class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({super.key, this.result});

  /// Null when opened without a result (deep link / refresh).
  final QuizResultArgs? result;

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
      body: r == null || r.total <= 0
          ? EmptyStateWidget(
              icon: Icons.quiz_outlined,
              title: 'Natiijo lama helin',
              message: 'Samee imtixaan si aad natiijo u aragto.',
              actionLabel: 'Ku noqo Xifdinta',
              onAction: () => context.go(AppRoutes.memorization),
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: AppPageBody(
                  child: Column(
                    children: [
                      if (r.isDemo) const DemoContentBadge(label: 'Natiijo tusaale ah'),
                      AppSpacing.gapLg,
                      Semantics(
                        label: '${r.correct} ka mid ah ${r.total} waa sax',
                        excludeSemantics: true,
                        child: Text('${r.correct} / ${r.total}', style: context.textStyles.displaySmall),
                      ),
                      AppSpacing.gapXs,
                      Text(
                        '${(r.correct * 100 / r.total).round()}% sax',
                        style: context.textStyles.titleMedium,
                      ),
                      AppSpacing.gapXxl,
                      PrimaryButton(
                        label: 'Ku noqo Xifdinta',
                        onPressed: () => context.go(AppRoutes.memorization),
                      ),
                      AppSpacing.gapSm,
                      SecondaryButton(
                        label: 'Isku day mar kale',
                        onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.quiz),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
