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
  bool _rememberMe = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future<void>.delayed(AuthController.demoDelay);
    if (!mounted) return;
    // E-mail trimmed; password passed exactly as typed.
    final ok = await context.services.auth.signInDemo(
      email: _email.text,
      password: _password.text,
      rememberMe: _rememberMe,
    );
    if (!mounted) return;
    if (ok) {
      context.go(AppRoutes.home);
    } else {
      setState(() {
        _loading = false;
        _error =
            'Email-ka ama furaha sirta ah kuma habboona akoonka demo-ga. '
            'Isticmaal xogta demo-ga ee hoose.';
      });
    }
  }

  Future<void> _tryDemo() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    await Future<void>.delayed(AuthController.demoDelay);
    if (!mounted) return;
    await context.services.auth.tryDemo(rememberMe: _rememberMe);
    if (mounted) context.go(AppRoutes.home);
  }

  void _fillDemo() {
    _email.text = AuthController.demoEmail;
    _password.text = AuthController.demoPassword;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.login_rounded,
      title: 'Ku soo dhowow mar kale',
      subtitle: 'Gal akoonkaaga si aad u sii wadato akhriska iyo xifdinta.',
      children: [
        _DemoCredentialsCard(onFill: _loading ? null : _fillDemo),
        AppSpacing.gapLg,
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
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                PasswordTextField(
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  validator: (v) => AppValidators.password(v, minLength: AuthController.minPasswordLength),
                  onFieldSubmitted: (_) => _submit(),
                ),
                AppSpacing.gapXs,
                // Wrap (not Row): on narrow phones / large text the link
                // moves below instead of overflowing.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MergeSemantics(
                      child: InkWell(
                        borderRadius: AppRadius.smAll,
                        onTap: _loading ? null : () => setState(() => _rememberMe = !_rememberMe),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: _loading ? null : (v) => setState(() => _rememberMe = v ?? true),
                            ),
                            Text('I xasuuso', style: context.textStyles.bodyMedium),
                            AppSpacing.gapXs,
                          ],
                        ),
                      ),
                    ),
                    AppTextButton(
                      label: 'Ilowday furaha?',
                      onPressed: _loading ? null : () => context.push(AppRoutes.forgotPassword),
                    ),
                  ],
                ),
                if (_error != null) ...[AppSpacing.gapSm, FormValidationMessage(message: _error!)],
                AppSpacing.gapMd,
                PrimaryButton(label: 'Gal', onPressed: _submit, isLoading: _loading),
                AppSpacing.gapSm,
                SecondaryButton(
                  label: 'Tijaabi Demo-ga',
                  icon: Icons.play_circle_outline_rounded,
                  onPressed: _loading ? null : _tryDemo,
                ),
                AppSpacing.gapMd,
                AppTextButton(
                  label: 'Akoon ma lihid? Isdiiwaangeli',
                  // Replace (not push) so Login ⇄ Register never builds a loop.
                  onPressed: _loading ? null : () => context.pushReplacement(AppRoutes.register),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Visible, clearly labelled demo account.
class _DemoCredentialsCard extends StatelessWidget {
  const _DemoCredentialsCard({required this.onFill});

  final VoidCallback? onFill;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.goldSubtle,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: c.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Akoonka demo-ga', style: context.textStyles.titleSmall),
          AppSpacing.gapXxs,
          SelectableText('Email: ${AuthController.demoEmail}', style: context.textStyles.bodyMedium),
          SelectableText('Furaha: ${AuthController.demoPassword}', style: context.textStyles.bodyMedium),
          AppSpacing.gapXxs,
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextButton(label: 'Buuxi xogta demo-ga', icon: Icons.edit_note_rounded, onPressed: onFill),
          ),
        ],
      ),
    );
  }
}
