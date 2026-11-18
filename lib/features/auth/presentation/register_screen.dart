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
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
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
    // Only name + e-mail are kept; the password is discarded here.
    // Capture the router first: the auth change triggers a redirect that may
    // dispose this screen before we navigate.
    final router = GoRouter.of(context);
    await context.services.auth.registerDemo(name: _name.text, email: _email.text);
    router.go(AppRoutes.verifyEmail);
  }

  @override
  Widget build(BuildContext context) {
    const min = AuthController.minPasswordLength;
    return AuthScaffold(
      icon: Icons.person_add_alt_rounded,
      title: 'Samee Akoon',
      subtitle: 'Akoon tijaabo ah oo ku kaydsan qalabkan oo keliya — ma jiro server.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Magaca oo buuxa',
                  controller: _name,
                  prefixIcon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => AppValidators.required(v, field: 'Magacu'),
                  enabled: !_loading,
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
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                PasswordTextField(
                  controller: _password,
                  isNewPassword: true,
                  helperText: 'Ugu yaraan $min xaraf',
                  textInputAction: TextInputAction.next,
                  validator: (v) => AppValidators.password(v, minLength: min),
                ),
                AppSpacing.gapMd,
                PasswordTextField(
                  label: 'Xaqiiji furaha',
                  controller: _confirm,
                  isNewPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => AppValidators.confirmPassword(v, _password.text),
                ),
                AppSpacing.gapSm,
                CheckboxFormField(
                  label: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Waan aqbalay shuruudaha iyo '),
                      InkWell(
                        onTap: () => context.push(AppRoutes.settingsPrivacy),
                        child: Text(
                          'arrimaha gaarka ah',
                          style: TextStyle(
                            color: context.colors.primary,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  requiredMessage: 'Fadlan aqbal shuruudaha si aad u sii wadato.',
                ),
                AppSpacing.gapLg,
                PrimaryButton(label: 'Samee Akoon', onPressed: _submit, isLoading: _loading),
                AppSpacing.gapMd,
                AppTextButton(
                  label: 'Akoon ma leedahay? Gal',
                  onPressed: _loading ? null : () => context.pushReplacement(AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
