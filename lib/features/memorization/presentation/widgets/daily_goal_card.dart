import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../memorization_controller.dart';

/// Today's goal: planned vs completed with a labelled progress bar.
class DailyGoalCard extends StatelessWidget {
  const DailyGoalCard({super.key, required this.controller, required this.onStart, required this.onChangeTarget});

  final MemorizationController controller;
  final VoidCallback onStart;
  final VoidCallback onChangeTarget;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final planned = c.plannedToday;
    final done = c.completedToday;
    final percent = (c.dailyProgress * 100).round();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wrap: the target button drops below the title on narrow screens.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Hadafka maanta', style: context.textStyles.titleMedium),
              AppTextButton(label: '${c.dailyTarget} maalintii', icon: Icons.tune_rounded, onPressed: onChangeTarget),
            ],
          ),
          Text(
            planned == 0 ? 'Xadiis kale oo la xifdiyo ma jiro.' : '$done / $planned xadiis ayaa la xifdiyey maanta',
            style: context.textStyles.bodyMedium,
          ),
          AppSpacing.gapSm,
          Semantics(
            label: 'Horumarka maanta: $percent boqolkiiba',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: LinearProgressIndicator(value: c.dailyProgress, minHeight: 10),
            ),
          ),
          if (c.planLimitedByData && planned > 0) ...[
            AppSpacing.gapXs,
            Text(
              'Hadafkaagu wuxuu ka badan yahay xadiisyada weli la heli karo ($planned).',
              style: context.textStyles.bodySmall,
            ),
          ],
          AppSpacing.gapMd,
          if (c.isTodayComplete)
            const FormValidationMessage(
              type: FormMessageType.success,
              message: 'Hambalyo! Waad dhammaysay qorshaha maanta.',
            )
          else if (planned > 0)
            PrimaryButton(label: 'Bilow qorshaha maanta', icon: Icons.play_arrow_rounded, onPressed: onStart),
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
            'Haddii xadiisyada la heli karo ay ka yar yihiin hadafka, qorshuhu wuu gaabanayaa — xadiis lama sameeyo.',
            style: sheetContext.textStyles.bodySmall,
          ),
        ],
      ),
    ),
  );
}
