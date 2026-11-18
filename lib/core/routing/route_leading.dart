import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// App bar leading for full-screen routes: the normal back button when there
/// is somewhere to go back to, otherwise (deep link / fresh start) a Home
/// button so the user is never stuck.
Widget? backOrHomeLeading(BuildContext context) {
  if (context.canPop()) return null; // AppBar shows its default BackButton.
  return IconButton(
    tooltip: 'Guriga',
    icon: const Icon(Icons.home_outlined),
    onPressed: () => context.go(AppRoutes.home),
  );
}
