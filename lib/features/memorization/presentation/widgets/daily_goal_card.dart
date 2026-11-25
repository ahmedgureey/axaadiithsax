import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../memorization_controller.dart';

/// Today's goal: planned vs completed with a labelled progress bar.
class DailyGoalCard extends StatelessWidget {
  const DailyGoalCard({
    super.key,
    required this.controller,
    required this.onStart,
    required this.onChangeTarget,
    this.onOpenPlan,
  });

  final MemorizationController controller;
  final VoidCallback onStart;
  final VoidCallback onChangeTarget;

  /// Opens today's list ("Qorshaha maanta").
  final VoidCallback? onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final planned = c.plannedToday;
    final done = c.completedToday;
    final percent = (c.dailyProgress * 100).round();
    final scheme = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                label: 'Horumarka maanta: $percent boqolkiiba',
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: c.dailyProgress,
                          strokeWidth: 6,
                          backgroundColor: scheme.primary.withValues(alpha: 0.10),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: context.textStyles.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hadafka maanta', style: context.textStyles.titleMedium),
                    Text(
                      planned == 0 ? 'Xadiis kale ma jiro.' : '$done / $planned la xifdiyey maanta',
                      style: context.textStyles.bodySmall,
                    ),
                    AppSpacing.gapXxs,
                    ActionChip(
                      avatar: const Icon(Icons.tune_rounded, size: 16),
                      label: Text('${c.dailyTarget} maalintii'),
                      onPressed: onChangeTarget,
                      tooltip: 'Beddel hadafka',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (c.planLimitedByData && planned > 0) ...[
            AppSpacing.gapXs,
            Text('Hadafku wuu ka badan yahay xadiisyada jira ($planned).', style: context.textStyles.bodySmall),
          ],
          AppSpacing.gapMd,
          if (c.isTodayComplete)
            const FormValidationMessage(
              type: FormMessageType.success,
              message: 'Hambalyo! Waad dhammaysay qorshaha maanta.',
            )
          else if (planned > 0)
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Bilow qorshaha maanta',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onStart,
                  ),
                ),
                if (onOpenPlan != null) ...[
                  AppSpacing.gapSm,
                  IconButton.outlined(
                    tooltip: 'Eeg qorshaha maanta',
                    onPressed: onOpenPlan,
                    icon: const Icon(Icons.list_alt_rounded),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet to choose the daily target.
Future<void> showDailyTargetSheet(BuildContext context, MemorizationController controller) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Imisa xadiis maalintii?', style: sheetContext.textStyles.titleLarge),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final t in MemorizationController.targetOptions)
                ChoiceChip(
                  label: Text('$t'),
                  selected: controller.dailyTarget == t,
                  onSelected: (_) {
                    controller.setDailyTarget(t);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            'Haddii xadiisyadu ka yar yihiin hadafka, qorshuhu wuu gaabanayaa.',
            style: sheetContext.textStyles.bodySmall,
          ),
        ],
      ),
    ),
  );
}
