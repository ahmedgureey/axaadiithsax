import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';
import 'islamic_ornament.dart';

/// Reusable app bar. Use [showOrnament] on top-level tab screens.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showOrnament = false,
    this.centerTitle = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showOrnament;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? kToolbarHeight : 68);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      centerTitle: centerTitle,
      toolbarHeight: preferredSize.height,
      actions: [
        ...?actions,
        const SizedBox(width: AppSpacing.xxs),
      ],
      title: Column(
        crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showOrnament) ...[const IslamicStar(size: 14), AppSpacing.gapXs],
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
            ],
          ),
          if (subtitle != null) Text(subtitle!, style: context.textStyles.bodySmall, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class AppNavDestination {
  const AppNavDestination({required this.label, required this.icon, required this.selectedIcon, this.textKey});

  /// Somali label (fallback when [textKey] is null).
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Translated label key for the selected interface language.
  final AppText? textKey;

  String labelFor(BuildContext context) => textKey == null ? label : AppStrings.of(context, textKey!);
}

/// The five main tabs agreed in the audit.
abstract final class AppNavDestinations {
  static const List<AppNavDestination> main = [
    AppNavDestination(
      label: 'Guriga',
      textKey: AppText.navHome,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    AppNavDestination(
      label: 'Kutubta',
      textKey: AppText.navBooks,
      icon: Icons.auto_stories_outlined,
      selectedIcon: Icons.auto_stories_rounded,
    ),
    AppNavDestination(
      label: 'Raadinta',
      textKey: AppText.navSearch,
      icon: Icons.search_outlined,
      selectedIcon: Icons.search_rounded,
    ),
    AppNavDestination(
      label: 'Xifdinta',
      textKey: AppText.navMemorize,
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology_rounded,
    ),
    AppNavDestination(
      label: 'Aniga',
      textKey: AppText.navProfile,
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];
}

/// Bottom navigation bar for the main shell. Routing is wired in Phase 3;
/// this widget is router-agnostic (index in, index out).
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.destinations = AppNavDestinations.main,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.appColors.divider)),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.labelFor(context),
              tooltip: d.labelFor(context),
            ),
        ],
      ),
    );
  }
}

/// Section title with optional "see all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(color: context.appColors.gold, borderRadius: AppRadius.pillAll),
            ),
            AppSpacing.gapXs,
            Expanded(child: Text(title, style: context.textStyles.titleMedium)),
            // The action keeps its natural width, capped at 45% of the row,
            // so it only ellipsizes on very narrow screens / very large text.
            if (actionLabel != null && onAction != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                child: TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Constrains content width on tablets and applies screen padding.
class AppPageBody extends StatelessWidget {
  const AppPageBody({super.key, required this.child, this.padding = AppSpacing.screenPadding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
