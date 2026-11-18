import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';
import 'auth_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future<void>.delayed(AuthController.demoDelay);
    if (!mounted) return;
    await context.services.auth.signInDemo(email: _email.text.trim());
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Gal',
      subtitle: 'Ku gal akoonkaaga si aad u keydsato horumarkaaga.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Email',
                  controller: _email,
                  hintText: 'tusaale@email.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: AppValidators.email,
                ),
                AppSpacing.gapMd,
                PasswordTextField(
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  validator: AppValidators.password,
                  onFieldSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppTextButton(
                    label: 'Ilowday furaha?',
                    onPressed: () => context.push(AppRoutes.forgotPassword),
                  ),
                ),
                AppSpacing.gapSm,
                PrimaryButton(label: 'Gal (demo)', onPressed: _submit, isLoading: _loading),
                AppSpacing.gapMd,
                AppTextButton(
                  label: 'Akoon ma lihid? Is diiwaangeli',
                  onPressed: () => context.pushReplacement(AppRoutes.register),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
