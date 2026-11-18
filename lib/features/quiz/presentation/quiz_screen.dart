import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import 'quiz_results_screen.dart';

/// Quiz entry. Real multiple-choice questions arrive in the quiz phase;
/// this screen exercises the quiz → results → back navigation.
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Imtixaan', leading: backOrHomeLeading(context)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: AppPageBody(
              child: Column(
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: context.appColors.goldText),
                  AppSpacing.gapLg,
                  Text(
                    'Imtixaanka xifdinta',
                    style: context.textStyles.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXs,
                  Text(
                    'Su\'aalaha dhabta ah waxay iman doonaan marxaladda imtixaannada. '
                    'Hadda waxaad arki kartaa natiijo tusaale ah.',
                    style: context.textStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXl,
                  PrimaryButton(
                    label: 'Muuji natiijo tusaale ah',
                    onPressed: () => context.push(
                      AppRoutes.quizResults,
                      extra: const QuizResultArgs(correct: 3, total: 5, isDemo: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
