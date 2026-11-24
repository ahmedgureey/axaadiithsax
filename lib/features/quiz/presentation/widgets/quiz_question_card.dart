import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/quiz_models.dart';

/// Question with options. After answering, correctness is shown with icons
/// and words ("Sax" / "Khalad"), not colour alone, plus an explanation.
class QuizQuestionCard extends StatelessWidget {
  const QuizQuestionCard({super.key, required this.question, required this.selected, required this.onSelect});

  final QuizQuestion question;

  /// Submitted option, or null while unanswered.
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final answered = selected != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaChip(label: question.type.label, icon: Icons.help_outline_rounded),
        AppSpacing.gapSm,
        Semantics(header: true, child: Text(question.prompt, style: context.textStyles.titleLarge)),
        if (question.arabicExcerpt != null) ...[
          AppSpacing.gapSm,
          AppCard(
            child: ArabicText(
              question.arabicExcerpt!,
              maxLines: 6,
              // A single word is shown large and centred.
              fontSize: question.type == QuizQuestionType.word ? 30 : 22,
              textAlign: question.type == QuizQuestionType.word ? TextAlign.center : TextAlign.start,
            ),
          ),
        ],
        if (question.contextText != null) ...[
          AppSpacing.gapSm,
          AppCard(child: Text(question.contextText!, style: context.textStyles.bodyMedium)),
        ],
        AppSpacing.gapMd,
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: QuizAnswerOption(
              letter: String.fromCharCode(65 + i),
              text: question.options[i],
              arabic: question.arabicOptions,
              state: !answered
                  ? AnswerState.idle
                  : i == question.correctIndex
                  ? AnswerState.correct
                  : i == selected
                  ? AnswerState.wrong
                  : AnswerState.disabled,
              onTap: answered ? null : () => onSelect(i),
            ),
          ),
        if (answered) ...[
          AppSpacing.gapSm,
          FormValidationMessage(
            type: selected == question.correctIndex ? FormMessageType.success : FormMessageType.error,
            message: selected == question.correctIndex
                ? 'Sax! ${question.explanation}'
                : 'Khalad. Jawaabta saxda ah: "${question.correctAnswer}". ${question.explanation}',
          ),
        ],
      ],
    );
  }
}

enum AnswerState { idle, correct, wrong, disabled }

class QuizAnswerOption extends StatelessWidget {
  const QuizAnswerOption({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
    this.arabic = false,
  });

  final String letter;
  final String text;
  final AnswerState state;
  final VoidCallback? onTap;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final c = context.appColors;
    final (Color border, IconData? icon, String? word) = switch (state) {
      AnswerState.correct => (c.success, Icons.check_circle_rounded, 'Sax'),
      AnswerState.wrong => (scheme.error, Icons.cancel_rounded, 'Khalad'),
      _ => (scheme.outlineVariant, null, null),
    };
    return Semantics(
      button: state == AnswerState.idle,
      label: '$letter: $text${word == null ? '' : ' — $word'}',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        borderColor: border,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget - AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: border.withValues(alpha: 0.15),
                child: Text(letter, style: context.textStyles.labelMedium?.copyWith(color: scheme.onSurface)),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: arabic
                    ? ArabicText(text, variant: ArabicTextVariant.label)
                    : Text(text, style: context.textStyles.bodyMedium),
              ),
              if (icon != null) ...[
                AppSpacing.gapXs,
                Icon(icon, color: border, size: AppSizes.icon),
                const SizedBox(width: AppSpacing.xxs),
                Text(word!, style: context.textStyles.labelMedium?.copyWith(color: border)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
