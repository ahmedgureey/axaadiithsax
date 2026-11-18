import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';
import 'auth_scaffold.dart';

/// Simulated reset: validates the form, then states clearly that no server
/// password changed.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  static const doneMessage =
      'Demo: foomka waa sax, laakiin furaha sirta ah ee server-ka lama beddelin — '
      'ma jiro server. Ku gal akoonka demo-ga.';

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future<void>.delayed(AuthController.demoDelay);
    if (!mounted) return;
    // Discard the typed values immediately.
    _password.clear();
    _confirm.clear();
    setState(() {
      _loading = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const min = AuthController.minPasswordLength;
    return AuthScaffold(
      icon: Icons.password_rounded,
      title: 'Furaha cusub',
      subtitle: 'Dooro furaha sirta ah ee cusub (tijaabo).',
      children: [
        if (_done) ...[
          const FormValidationMessage(
            type: FormMessageType.success,
            message: ResetPasswordScreen.doneMessage,
          ),
          AppSpacing.gapLg,
        ] else ...[
          Form(
            key: _formKey,
            child: Column(
              children: [
                PasswordTextField(
                  label: 'Furaha cusub',
                  controller: _password,
                  isNewPassword: true,
                  helperText: 'Ugu yaraan $min xaraf',
                  textInputAction: TextInputAction.next,
                  validator: (v) => AppValidators.password(v, minLength: min),
                ),
                AppSpacing.gapMd,
                PasswordTextField(
                  label: 'Xaqiiji furaha cusub',
                  controller: _confirm,
                  isNewPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => AppValidators.confirmPassword(v, _password.text),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          AppSpacing.gapXl,
          PrimaryButton(label: 'Cusboonaysii Furaha', onPressed: _submit, isLoading: _loading),
          AppSpacing.gapMd,
        ],
        // Login replaces the whole auth stack: no back-loop into reset.
        if (_done)
          PrimaryButton(label: 'Ku noqo Gelitaanka', onPressed: () => context.go(AppRoutes.login))
        else
          AppTextButton(label: 'Ku noqo Gelitaanka', onPressed: () => context.go(AppRoutes.login)),
      ],
    );
  }
}
