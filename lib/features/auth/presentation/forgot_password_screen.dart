import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';
import 'auth_scaffold.dart';

/// Demo: no e-mail is sent; a generic confirmation leads to the simulated
/// reset step.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const confirmation = 'Haddii email-ku ku habboon yahay demo-ga, tallaabada xigta ayaa la muujin doonaa.';

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future<void>.delayed(AuthController.demoDelay);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _submitted = true;
    });
  }

  void _backToLogin() => context.canPop() ? context.pop() : context.go(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.lock_reset_rounded,
      title: 'Ma illowday furaha sirta ah?',
      subtitle: 'Geli email-kaaga. Demo-gan email dhab ah ma diro — wuxuu kuu muujinayaa tallaabooyinka.',
      children: [
        Form(
          key: _formKey,
          child: AppTextField(
            label: 'Email',
            controller: _email,
            hintText: 'tusaale@email.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: AppValidators.email,
            enabled: !_submitted && !_loading,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        AppSpacing.gapLg,
        if (_submitted) ...[
          const FormValidationMessage(type: FormMessageType.success, message: ForgotPasswordScreen.confirmation),
          AppSpacing.gapLg,
          PrimaryButton(
            label: 'U gudub furaha cusub (demo)',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.push(AppRoutes.resetPassword),
          ),
        ] else
          PrimaryButton(label: 'Sii wad', onPressed: _submit, isLoading: _loading),
        AppSpacing.gapMd,
        AppTextButton(label: 'Ku noqo Gelitaanka', icon: Icons.arrow_back_rounded, onPressed: _backToLogin),
      ],
    );
  }
}
