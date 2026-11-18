import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../splash/presentation/splash_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppLogo(),
                  AppSpacing.gapLg,
                  Text(
                    'Ku soo dhowow! Akhri, raadi oo xifdi axaadiista Nabiga ﷺ.',
                    style: context.textStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXxl,
                  PrimaryButton(
                    label: 'Gal',
                    icon: Icons.login_rounded,
                    onPressed: () => context.push(AppRoutes.login),
                  ),
                  AppSpacing.gapSm,
                  SecondaryButton(label: 'Is diiwaangeli', onPressed: () => context.push(AppRoutes.register)),
                  AppSpacing.gapSm,
                  AppTextButton(
                    label: 'Ku sii wad marti ahaan',
                    onPressed: () async {
                      await context.services.auth.continueAsGuest();
                      if (context.mounted) context.go(AppRoutes.home);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
