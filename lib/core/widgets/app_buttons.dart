import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';

/// Shared button content: optional leading icon, or a spinner while loading.
class _ButtonChild extends StatelessWidget {
  const _ButtonChild({required this.label, required this.icon, required this.isLoading, required this.spinnerColor});

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color spinnerColor;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: spinnerColor));
    }
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconSm),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: text),
      ],
    );
  }
}

/// Main call-to-action. Set [isLoading] to show a spinner and block taps
/// (this doubles as the "LoadingButton"). `onPressed: null` = disabled.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  /// Fill the available width (default for forms and bottom actions).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: isLoading
          ? FilledButton.styleFrom(disabledBackgroundColor: context.colors.primary.withValues(alpha: 0.85))
          : null,
      child: _ButtonChild(label: label, icon: icon, isLoading: isLoading, spinnerColor: context.colors.onPrimary),
    );
    return Semantics(
      button: true,
      label: isLoading ? '$label — waa la socodsiinayaa' : null,
      excludeSemantics: isLoading,
      child: expanded ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Secondary, outlined action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: _ButtonChild(label: label, icon: icon, isLoading: isLoading, spinnerColor: context.colors.primary),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Low-emphasis text action (e.g. "Ilowday furaha?").
class AppTextButton extends StatelessWidget {
  const AppTextButton({super.key, required this.label, required this.onPressed, this.icon, this.color});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = color == null ? null : TextButton.styleFrom(foregroundColor: color);
    if (icon == null) {
      return TextButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return TextButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: AppSizes.iconSm),
      label: Text(label),
    );
  }
}

/// Icon-only action (copy, share, bookmark, play...). [tooltip] is required
/// because it is also the accessibility label.
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selectedIcon,
    this.isSelected = false,
    this.filled = false,
    this.color,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Toggle state (e.g. bookmarked).
  final bool isSelected;

  /// Tonal filled background — for prominent standalone actions.
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final selectedColor = context.appColors.gold;
    final iconWidget = Icon(isSelected ? (selectedIcon ?? icon) : icon);
    final fg = isSelected ? selectedColor : (color ?? context.appColors.textSecondary);
    if (filled) {
      return IconButton.filledTonal(
        onPressed: onPressed,
        tooltip: tooltip,
        isSelected: isSelected,
        icon: iconWidget,
        style: IconButton.styleFrom(
          backgroundColor: context.colors.primaryContainer,
          foregroundColor: isSelected ? selectedColor : context.colors.onPrimaryContainer,
        ),
      );
    }
    return IconButton(onPressed: onPressed, tooltip: tooltip, isSelected: isSelected, icon: iconWidget, color: fg);
  }
}
