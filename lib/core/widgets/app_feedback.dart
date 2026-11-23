import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';
import 'app_buttons.dart';

/// Shown wherever hadith would appear but the app has no verified records.
const noVerifiedHadithMessage = 'Weli ma jiraan xadiisyo la xaqiijiyey oo la soo bandhigi karo.';

/// Centered progress indicator with optional message.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.message, this.size = 32});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message ?? 'Waa la soo rarayaa',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(dimension: size, child: const CircularProgressIndicator(strokeWidth: 3)),
            if (message != null) ...[
              AppSpacing.gapSm,
              Text(message!, style: context.textStyles.bodySmall, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared layout for empty / error states.
class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: iconColor),
              ),
              AppSpacing.gapLg,
              Text(title, style: context.textStyles.titleLarge, textAlign: TextAlign.center),
              if (message != null) ...[
                AppSpacing.gapXs,
                Text(
                  message!,
                  style: context.textStyles.bodyMedium?.copyWith(color: context.appColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                AppSpacing.gapXl,
                PrimaryButton(label: actionLabel!, onPressed: onAction, expanded: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Nothing here yet" state (no favourites, no search results...).
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: icon,
      iconColor: context.appColors.goldText,
      iconBackground: context.appColors.goldSubtle,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// Error state with retry.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    this.title = 'Wax qalad ah ayaa dhacay',
    this.message = 'Fadlan isku day mar kale.',
    this.onRetry,
    this.retryLabel = 'Isku day mar kale',
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return _StateMessage(
      icon: Icons.error_outline_rounded,
      iconColor: scheme.error,
      iconBackground: scheme.errorContainer,
      title: title,
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
    );
  }
}

/// Confirmation dialog. Returns `true` when confirmed.
///
/// ```dart
/// final ok = await showConfirmDialog(context, title: 'Ka saar?', ...);
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Haa',
  String cancelLabel = 'Jooji',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );
  return result ?? false;
}

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel = 'Haa',
    this.cancelLabel = 'Jooji',
    this.isDestructive = false,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message!),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel)),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

enum AppSnackType { info, success, error }

/// Consistent snack bars (e.g. "Waa la koobiyeeyay").
abstract final class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    AppSnackType type = AppSnackType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final c = context.appColors;
    final icon = switch (type) {
      AppSnackType.info => Icons.info_outline_rounded,
      AppSnackType.success => Icons.check_circle_outline_rounded,
      AppSnackType.error => Icons.error_outline_rounded,
    };
    final iconColor = switch (type) {
      AppSnackType.info => c.gold,
      AppSnackType.success => c.success,
      AppSnackType.error => context.colors.error,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: AppSizes.icon),
              AppSpacing.gapSm,
              Expanded(child: Text(message)),
            ],
          ),
          action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
        ),
      );
  }
}
