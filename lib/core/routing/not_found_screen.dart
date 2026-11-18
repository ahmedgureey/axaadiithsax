import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/widgets.dart';
import 'app_routes.dart';

/// Friendly "not found" content with a way back home. Used for unknown
/// routes and for invalid book / chapter / hadith IDs.
class NotFoundView extends StatelessWidget {
  const NotFoundView({
    super.key,
    this.title = 'Boggan lama helin',
    this.message = 'Waxa aad raadinaysay ma jiro ama waa la beddelay.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.travel_explore_rounded,
      title: title,
      message: message,
      actionLabel: 'Ku noqo Guriga',
      onAction: () => context.go(AppRoutes.home),
    );
  }
}

/// Full-screen variant (router `errorBuilder`, invalid IDs).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.title, this.message});

  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Lama helin'),
      body: NotFoundView(
        title: title ?? 'Boggan lama helin',
        message: message ?? 'Waxa aad raadinaysay ma jiro ama waa la beddelay.',
      ),
    );
  }
}
