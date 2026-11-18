import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future<void>.delayed(AuthController.demoDelay);
    if (!mounted) return;
    setState(() => _loading = false);
    context.push(AppRoutes.resetPassword);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Ilowday furaha',
      subtitle: 'Geli email-kaaga. Nidaamka dhabta ah wuxuu kuu diri lahaa link dib-u-dejin ah.',
      children: [
        Form(
          key: _formKey,
          child: AppTextField(
            label: 'Email',
            controller: _email,
            hintText: 'tusaale@email.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: AppValidators.email,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        AppSpacing.gapXl,
        PrimaryButton(label: 'Dir link (demo)', onPressed: _submit, isLoading: _loading),
      ],
    );
  }
}
