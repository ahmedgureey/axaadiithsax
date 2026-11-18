import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_scaffold.dart';

/// Demo e-mail verification: no e-mail is sent.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.services.auth.pendingEmail;
    return AuthScaffold(
      title: 'Xaqiiji email-kaaga',
      subtitle: email == null
          ? 'Nidaamka dhabta ah wuxuu kuu diri lahaa link xaqiijin ah.'
          : 'Nidaamka dhabta ah wuxuu link xaqiijin ah u diri lahaa $email.',
      children: [
        Icon(Icons.mark_email_read_outlined, size: 72, color: context.appColors.gold),
        AppSpacing.gapXl,
        PrimaryButton(
          label: 'Waan xaqiijiyay (demo)',
          onPressed: () async {
            await context.services.auth.completeVerificationDemo();
            if (context.mounted) context.go(AppRoutes.home);
          },
        ),
        AppSpacing.gapSm,
        AppTextButton(
          label: 'Dib u dir (demo)',
          onPressed: () => AppSnackbar.show(context, 'Demo: wax email ah lama dirin.'),
        ),
      ],
    );
  }
}
