import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Greeting, logo, notifications and a refresh button. No accounts: the
/// greeting is the same for everyone.
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key, this.onRefresh});

  /// Reloads the home screen (and server data when a backend is used).
  final VoidCallback? onRefresh;

  static const greeting = 'Assalaamu Calaykum';

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      titleSpacing: AppSpacing.md,
      title: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: context.appColors.gold.withValues(alpha: 0.6)),
              ),
              child: const IslamicStar(size: 20),
            ),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(AppText.homeGreeting),
                  style: context.textStyles.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Ku soo dhowow Xadiith App',
                  style: context.textStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Ogeysiisyada',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => context.push(AppRoutes.notifications),
        ),
        IconButton(tooltip: 'Cusboonaysii', onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
        const SizedBox(width: AppSpacing.xxs),
      ],
    );
  }
}
