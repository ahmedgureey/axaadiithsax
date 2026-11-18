import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Shared layout for the demo authentication screens: back button, title,
/// demo notice, scrollable centred form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Dib u noqo',
          icon: const BackButtonIcon(),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.welcome),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: AppPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: context.textStyles.headlineMedium),
                AppSpacing.gapXs,
                Text(
                  subtitle,
                  style: context.textStyles.bodyMedium?.copyWith(color: context.appColors.textSecondary),
                ),
                AppSpacing.gapLg,
                const DemoAuthNotice(),
                AppSpacing.gapXl,
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Makes it explicit that authentication is a demo.
class DemoAuthNotice extends StatelessWidget {
  const DemoAuthNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const FormValidationMessage(
      type: FormMessageType.info,
      message:
          'Tani waa tijaabo (demo). Ma jiro server ama xaqiijin dhab ah, '
          'furaha sirta ahna lama kaydiyo.',
    );
  }
}
