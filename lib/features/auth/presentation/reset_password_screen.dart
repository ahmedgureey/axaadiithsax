import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';
import 'auth_scaffold.dart';

/// Simulated reset: validates the form, then states clearly that no server
/// password changed.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  static const doneMessage = 'Demo: furaha sirta ah lama beddelin (ma jiro server). Ku gal akoonka demo-ga.';

  static const realDoneMessage = 'Furaha sirta ah waa la beddelay. Hadda waad gashay.';

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
    final auth = context.services.auth;
    if (!auth.usesRealAccounts) await Future<void>.delayed(AuthController.demoDelay);
    // Real accounts: saved by Supabase inside the recovery session opened from
    // the e-mail link. Demo: nothing changes.
    final failure = await auth.completePasswordReset(_password.text);
    if (!mounted) return;
    if (failure != null) {
      setState(() => _loading = false);
      AppSnackbar.show(context, failure.message, type: AppSnackType.error);
      return;
    }
    // Discard the typed values immediately.
    _password.clear();
    _confirm.clear();
    setState(() {
      _loading = false;
      _done = true;
    });
  }

  /// Leaving during a recovery session signs out; otherwise the router would
  /// keep returning here.
  Future<void> _backToLogin(BuildContext context) async {
    final router = GoRouter.of(context);
    final auth = context.services.auth;
    if (auth.isRecoveringPassword) await auth.signOut();
    router.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    const min = AuthController.minPasswordLength;
    final auth = context.services.auth;
    final real = auth.usesRealAccounts;
    return AuthScaffold(
      icon: Icons.password_rounded,
      title: 'Furaha cusub',
      subtitle: real ? 'Dooro furaha sirta ah ee cusub.' : 'Dooro furaha sirta ah ee cusub (tijaabo).',
      children: [
        if (_done) ...[
          FormValidationMessage(
            type: FormMessageType.success,
            message: real ? ResetPasswordScreen.realDoneMessage : ResetPasswordScreen.doneMessage,
          ),
          AppSpacing.gapLg,
          if (real && auth.isSignedIn) ...[
            PrimaryButton(label: 'U gudub Guriga', onPressed: () => context.go(AppRoutes.home)),
            AppSpacing.gapSm,
          ],
        ] else ...[
          if (real && !auth.isRecoveringPassword) ...[
            const FormValidationMessage(
              type: FormMessageType.info,
              message: 'Si aad furaha u beddesho, fur link-ga email-ka "Ilowday furaha" ee laguu soo diray.',
            ),
            AppSpacing.gapLg,
          ],
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
          PrimaryButton(label: 'Ku noqo Gelitaanka', onPressed: () => _backToLogin(context))
        else
          AppTextButton(label: 'Ku noqo Gelitaanka', onPressed: () => _backToLogin(context)),
      ],
    );
  }
}
