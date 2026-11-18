import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';
import 'app_cards.dart';
import 'app_navigation.dart';

/// Titled group of settings rows inside a card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;

  /// Optional explanatory text under the card.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        AppSpacing.gapXs,
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null) ...[AppSpacing.gapXs, Text(footer!, style: Theme.of(context).textTheme.bodySmall)],
      ],
    );
  }
}

/// One settings row (≥48dp tall). [destructive] uses the error colour AND a
/// warning icon so colour is not the only signal.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      minTileHeight: AppSizes.minTouchTarget + AppSpacing.xs,
      leading: Icon(icon, color: color ?? context.appColors.textSecondary),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(destructive ? Icons.warning_amber_rounded : Icons.chevron_right_rounded, color: color)),
      onTap: onTap,
    );
  }
}
