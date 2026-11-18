import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';
import 'auth_scaffold.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future<void>.delayed(AuthController.demoDelay);
    if (!mounted) return;
    AppSnackbar.show(context, 'Demo: furaha lama beddelin. Hadda gal.', type: AppSnackType.success);
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Furaha cusub',
      subtitle: 'Dooro furaha sirta ah ee cusub.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              PasswordTextField(
                label: 'Furaha cusub',
                controller: _password,
                isNewPassword: true,
                helperText: 'Ugu yaraan 8 xaraf',
                validator: AppValidators.password,
              ),
              AppSpacing.gapMd,
              PasswordTextField(
                label: 'Ku celi furaha',
                isNewPassword: true,
                validator: (v) => v != _password.text ? 'Furayaashu isma laha.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        AppSpacing.gapXl,
        PrimaryButton(label: 'Keydi furaha (demo)', onPressed: _submit, isLoading: _loading),
      ],
    );
  }
}
