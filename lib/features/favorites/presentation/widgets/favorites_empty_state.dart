import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/widgets.dart';

class FavoritesEmptyState extends StatelessWidget {
  const FavoritesEmptyState({super.key});

  static const title = 'Weli ma kaydin wax xadiis ah.';

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.bookmark_add_outlined,
      title: title,
      message: 'Riix calaamadda keydinta ee xadiis kasta si aad mar dambe halkan uga hesho.',
      actionLabel: 'Raadi Xadiisyo',
      onAction: () => context.go(AppRoutes.search),
    );
  }
}
