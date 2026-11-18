import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/memorization_models.dart';

/// Lightweight 7-day bar chart of recorded activity, with a text summary for
/// people who can't read the chart.
class WeeklyProgressChart extends StatelessWidget {
  const WeeklyProgressChart({super.key, required this.days});

  /// Oldest first.
  final List<(String, DayActivity)> days;

  static const _weekdays = ['Isn', 'Tal', 'Arb', 'Kha', 'Jim', 'Sab', 'Axd'];

  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold<int>(0, (m, d) => d.$2.total > m ? d.$2.total : m);
    final memorized = days.fold<int>(0, (s, d) => s + d.$2.memorized);
    final reviewed = days.fold<int>(0, (s, d) => s + d.$2.reviewed);
    final quizzes = days.fold<int>(0, (s, d) => s + d.$2.quizzes);
    final activeDays = days.where((d) => !d.$2.isEmpty).length;
    final summary = activeDays == 0
        ? 'Toddobaadkan weli wax dhaqdhaqaaq ah lama diiwaangelin.'
        : 'Toddobaadkan: $memorized xifdin, $reviewed dib-u-eegis, $quizzes imtixaan — $activeDays maalmood oo firfircoon.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (day, a) in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: maxValue == 0 ? 0.04 : (a.total / maxValue).clamp(0.04, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: a.isEmpty ? context.appColors.divider : context.colors.primary,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                          AppSpacing.gapXxs,
                          Text(
                            _weekdays[LocalDay.parse(day).weekday - 1],
                            style: context.textStyles.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        AppSpacing.gapXs,
        Text(summary, style: context.textStyles.bodySmall),
      ],
    );
  }
}
