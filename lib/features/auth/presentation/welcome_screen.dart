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
                  AppSpacing.gapXl,
                  Text('Ku soo dhowow', style: context.textStyles.headlineSmall, textAlign: TextAlign.center),
                  AppSpacing.gapXs,
                  HonorificText(
                    'Akhri, raadi oo xifdi axaadiista Nabiga ﷺ — Carabi iyo Af-Soomaali.',
                    style: context.textStyles.bodyLarge?.copyWith(color: context.appColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXxl,
                  PrimaryButton(
                    label: 'Gal Akoonka',
                    icon: Icons.login_rounded,
                    onPressed: () => context.push(AppRoutes.login),
                  ),
                  AppSpacing.gapSm,
                  SecondaryButton(
                    label: 'Samee Akoon',
                    icon: Icons.person_add_alt_rounded,
                    onPressed: () => context.push(AppRoutes.register),
                  ),
                  AppSpacing.gapMd,
                  AppTextButton(
                    label: 'Sii wad adigoon gelin',
                    onPressed: () async {
                      // Guest mode: the user is NOT authenticated.
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
