import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_services.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Greeting, logo, notifications and profile shortcut.
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  static const greeting = 'Assalaamu Calaykum';

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final auth = context.services.auth;
    return AppBar(
      toolbarHeight: preferredSize.height,
      titleSpacing: AppSpacing.md,
      title: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => Row(
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
                  Text(greeting, style: context.textStyles.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    // Guests are greeted generically — never as an account holder.
                    auth.isSignedIn && auth.displayName != null
                        ? 'Ku soo dhowow, ${auth.displayName}'
                        : 'Ku soo dhowow Xadiith App',
                    style: context.textStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Ogeysiisyada',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => context.push(AppRoutes.notifications),
        ),
        ListenableBuilder(
          listenable: auth,
          builder: (context, _) {
            final name = auth.isSignedIn ? auth.displayName : null;
            return IconButton(
              tooltip: name == null ? 'Aniga (marti)' : 'Aniga',
              onPressed: () => context.go(AppRoutes.profile),
              icon: name == null
                  ? const Icon(Icons.account_circle_outlined)
                  : CircleAvatar(
                      radius: 14,
                      backgroundColor: context.colors.primaryContainer,
                      foregroundColor: context.colors.onPrimaryContainer,
                      child: Text(name.characters.first.toUpperCase(), style: context.textStyles.labelMedium),
                    ),
            );
          },
        ),
        const SizedBox(width: AppSpacing.xxs),
      ],
    );
  }
}
