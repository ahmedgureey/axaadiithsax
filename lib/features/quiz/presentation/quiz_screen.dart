import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/quiz_models.dart';

/// Quiz setup: number of questions, topic and source. Only options the data
/// can support are offered (no difficulty levels: the demo data has none).
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  static const title = 'Imtixaanka Xadiiska';

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _count = QuizConfig.countOptions.first;
  String? _categoryId;
  QuizSource _source = QuizSource.all;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    final topics = [
      for (final c in repo.categories)
        if (repo.hadithCountOfCategory(c.id) > 0) c,
    ];
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleQuiz), leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          AppPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Su\'aalaha waxaa laga sameeyaa xogta app-ka oo keliya.', style: context.textStyles.bodyMedium),
                AppSpacing.gapLg,
                Text('Tirada su\'aalaha', style: context.textStyles.titleSmall),
                AppSpacing.gapXs,
                SegmentedButton<int>(
                  segments: [for (final n in QuizConfig.countOptions) ButtonSegment(value: n, label: Text('$n'))],
                  selected: {_count},
                  onSelectionChanged: (s) => setState(() => _count = s.first),
                ),
                AppSpacing.gapLg,
                Text('Mowduuca', style: context.textStyles.titleSmall),
                AppSpacing.gapXs,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: const Text('Dhammaan'),
                      selected: _categoryId == null,
                      onSelected: (_) => setState(() => _categoryId = null),
                    ),
                    for (final c in topics)
                      ChoiceChip(
                        label: Text(c.nameSomali),
                        selected: _categoryId == c.id,
                        onSelected: (_) => setState(() => _categoryId = c.id),
                      ),
                  ],
                ),
                AppSpacing.gapLg,
                Text('Xadiisyada', style: context.textStyles.titleSmall),
                AppSpacing.gapXs,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final s in QuizSource.values)
                      ChoiceChip(
                        label: Text(s.label),
                        selected: _source == s,
                        onSelected: (_) => setState(() => _source = s),
                      ),
                  ],
                ),
                AppSpacing.gapXl,
                PrimaryButton(
                  label: 'Bilow imtixaanka',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => context.push(
                    AppRoutes.quizPlay,
                    extra: QuizConfig(questionCount: _count, categoryId: _categoryId, source: _source),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
