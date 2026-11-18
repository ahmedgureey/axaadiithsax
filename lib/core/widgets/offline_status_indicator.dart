import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';

/// Where content lives — NOT network connectivity (the app does not detect
/// connectivity). Each label states only what is actually true.
enum OfflineAvailability {
  /// Text is bundled in the app and readable without internet.
  availableLocally('Ku jira qalabka — waa la akhrin karaa internet la\'aan', Icons.offline_pin_outlined),

  /// The user's own data (e.g. bookmark list) is stored on this device.
  savedOnDevice('Liiska waxa uu ku kaydsan yahay qalabkan', Icons.phone_android_rounded),

  /// Content is not included in this version of the app.
  notDownloaded('Kuma jiro qalabka — noocan kuma jiro', Icons.cloud_off_rounded),

  /// Availability cannot be determined.
  unknown('Lama garanayo in internet la\'aan la heli karo', Icons.help_outline_rounded);

  const OfflineAvailability(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Small, honest status pill for offline availability.
class OfflineStatusIndicator extends StatelessWidget {
  const OfflineStatusIndicator({super.key, required this.status});

  final OfflineAvailability status;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = switch (status) {
      OfflineAvailability.availableLocally || OfflineAvailability.savedOnDevice => c.success,
      OfflineAvailability.notDownloaded => c.warning,
      OfflineAvailability.unknown => c.textSecondary,
    };
    return Semantics(
      label: status.label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: AppRadius.pillAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(status.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
