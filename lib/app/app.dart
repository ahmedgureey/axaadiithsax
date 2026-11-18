import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/app_router.dart';
import '../core/routing/app_routes.dart';
import '../core/settings/app_settings_controller.dart';
import '../core/theme/app_theme.dart';
import 'app_services.dart';

/// Root widget: provides services, builds the router once, and rebuilds the
/// theme when appearance settings change.
class XadiisApp extends StatefulWidget {
  const XadiisApp({super.key, required this.services, this.initialLocation = AppRoutes.splash});

  final AppServices services;

  /// Override for tests / deep links.
  final String initialLocation;

  @override
  State<XadiisApp> createState() => _XadiisAppState();
}

class _XadiisAppState extends State<XadiisApp> {
  late final GoRouter _router = buildAppRouter(widget.services, initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    return AppServicesScope(
      services: widget.services,
      child: AppSettingsScope(
        controller: settings,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => MaterialApp.router(
            title: 'Xadiith App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
