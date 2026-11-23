import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';
import 'auth_scaffold.dart';

/// Simulated e-mail verification. Nothing is sent; verification happens only
/// when the user taps the clearly labelled demo button.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _loading = false;

  Future<void> _verify() async {
    setState(() => _loading = true);
    await Future<void>.delayed(AuthController.demoDelay);
    if (!mounted) return;
    final router = GoRouter.of(context);
    AppSnackbar.show(context, 'Demo: email-ka waxaa loo calaamadeeyay "la xaqiijiyay".', type: AppSnackType.success);
    await context.services.auth.verifyEmailDemo();
    // Verified sessions are redirected away from this route; go explicitly too.
    router.go(AppRoutes.home);
  }

  Future<void> _backToLogin() async {
    // Leaving verification ends the unverified demo session.
    final router = GoRouter.of(context);
    await context.services.auth.signOut();
    router.go(AppRoutes.login);
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    final failure = await context.services.auth.resendVerification();
    if (!mounted) return;
    setState(() => _loading = false);
    AppSnackbar.show(
      context,
      failure?.message ?? 'Email-ka xaqiijinta mar kale ayaa la diray.',
      type: failure == null ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _leaveRealVerification() async {
    final router = GoRouter.of(context);
    final auth = context.services.auth;
    auth.clearPendingVerification();
    if (auth.isSignedIn) await auth.signOut();
    router.go(AppRoutes.login);
  }

  /// Real accounts: Supabase sent a confirmation e-mail. The account becomes
  /// usable after the link is opened; then the user signs in.
  Widget _buildReal(BuildContext context, String? masked) => AuthScaffold(
    showBack: false,
    icon: Icons.mark_email_unread_outlined,
    title: 'Xaqiiji Email-ka',
    subtitle: masked == null ? 'Waxaan kuu soo dirnay link xaqiijin ah.' : 'Waxaan link xaqiijin ah u dirnay $masked.',
    children: [
      Center(child: Icon(Icons.forward_to_inbox_rounded, size: 72, color: context.appColors.gold)),
      AppSpacing.gapXl,
      const FormValidationMessage(
        type: FormMessageType.info,
        message:
            'Fur email-ka (eeg sidoo kale Spam), riix link-ga xaqiijinta telefoonkan, kadibna ku gal email-kaaga '
            'iyo furahaaga sirta ah.',
      ),
      AppSpacing.gapXl,
      PrimaryButton(
        label: 'U gudub Gelitaanka',
        icon: Icons.login_rounded,
        onPressed: _loading ? null : _leaveRealVerification,
      ),
      AppSpacing.gapSm,
      SecondaryButton(
        label: 'Dib u dir email-ka',
        icon: Icons.refresh_rounded,
        onPressed: _loading ? null : _resend,
        isLoading: _loading,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final masked = context.services.auth.maskedEmail;
    if (context.services.auth.usesRealAccounts) return _buildReal(context, masked);
    return AuthScaffold(
      showBack: false,
      icon: Icons.mark_email_unread_outlined,
      title: 'Xaqiiji Email-ka',
      subtitle: masked == null ? 'Demo-gan email xaqiijin ah ma diro.' : 'Demo-gan email xaqiijin ah uma diro $masked.',
      children: [
        Center(child: Icon(Icons.forward_to_inbox_rounded, size: 72, color: context.appColors.gold)),
        AppSpacing.gapXl,
        PrimaryButton(
          label: 'Tijaabi Xaqiijinta',
          icon: Icons.verified_outlined,
          onPressed: _verify,
          isLoading: _loading,
        ),
        AppSpacing.gapXs,
        Text(
          'Tani waa xaqiijin la iska dhigay (simulated) — server ma hubin.',
          style: context.textStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapLg,
        AppTextButton(label: 'Hadda ka dib', onPressed: _loading ? null : () => context.go(AppRoutes.home)),
        AppTextButton(label: 'Ku noqo Gelitaanka', onPressed: _loading ? null : _backToLogin),
      ],
    );
  }
}
