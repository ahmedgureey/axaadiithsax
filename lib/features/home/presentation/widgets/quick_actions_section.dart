import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';

/// "Si Degdeg ah u Gal" — four shortcuts using the existing routes.
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(Icons.search_rounded, 'Raadso Xadiis', () => context.go(AppRoutes.search)),
      _QuickAction(
        Icons.bookmarks_outlined,
        'Xadiisyada aan Kaydiyey',
        () => context.push(AppRoutes.favorites),
      ),
      _QuickAction(Icons.psychology_outlined, 'Qorshaha Xifdinta', () => context.go(AppRoutes.memorization)),
      _QuickAction(Icons.quiz_outlined, 'Imtixaanka Xadiiska', () => context.push(AppRoutes.quiz)),
    ];
    Widget row(int start) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: actions[start]),
          AppSpacing.gapSm,
          Expanded(child: actions[start + 1]),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Si Degdeg ah u Gal'),
        AppSpacing.gapSm,
        row(0),
        AppSpacing.gapSm,
        row(2),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(color: context.colors.primaryContainer, borderRadius: AppRadius.smAll),
            child: Icon(icon, color: context.colors.onPrimaryContainer, size: AppSizes.icon),
          ),
          AppSpacing.gapSm,
          Expanded(child: Text(label, style: context.textStyles.titleSmall)),
        ],
      ),
    );
  }
}
