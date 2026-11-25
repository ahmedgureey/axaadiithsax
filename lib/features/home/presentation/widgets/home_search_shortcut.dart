import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';

/// Looks like a search field but simply opens the Search tab, which stays the
/// single source of truth for search behaviour.
class HomeSearchShortcut extends StatelessWidget {
  const HomeSearchShortcut({super.key});

  static const hint = 'Raadi xadiis';

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fill = scheme.brightness == Brightness.dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
    return Semantics(
      button: true,
      label: 'Raadinta: $hint',
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoutes.search),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: context.appColors.textSecondary),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Text(
                      hint,
                      style: context.textStyles.bodyLarge?.copyWith(color: context.appColors.textSecondary),
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
