import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future<void>.delayed(AuthController.demoDelay);
    if (!mounted) return;
    context.services.auth.startRegistrationDemo(name: _name.text, email: _email.text);
    setState(() => _loading = false);
    context.push(AppRoutes.verifyEmail);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Is diiwaangeli',
      subtitle: 'Samee akoon si aad u keydsato kuwa aad jeceshahay iyo xifdintaada.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Magaca',
                  controller: _name,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => AppValidators.required(v, field: 'Magacu'),
                ),
                AppSpacing.gapMd,
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
                  isNewPassword: true,
                  helperText: 'Ugu yaraan 8 xaraf',
                  textInputAction: TextInputAction.next,
                  validator: AppValidators.password,
                ),
                AppSpacing.gapMd,
                PasswordTextField(
                  label: 'Ku celi furaha',
                  isNewPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != _password.text ? 'Furayaashu isma laha.' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                AppSpacing.gapXl,
                PrimaryButton(label: 'Samee akoon (demo)', onPressed: _submit, isLoading: _loading),
                AppSpacing.gapMd,
                AppTextButton(
                  label: 'Akoon ma leedahay? Gal',
                  onPressed: () => context.pushReplacement(AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
