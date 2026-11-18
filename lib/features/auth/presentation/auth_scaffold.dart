import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Shared layout for the demo authentication screens: back button, optional
/// icon, title, demo notice and a scrollable, keyboard-aware centred form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.icon,
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final IconData? icon;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: showBack
            ? IconButton(
                tooltip: 'Dib u noqo',
                icon: const BackButtonIcon(),
                onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.welcome),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: AppPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.colors.primaryContainer,
                        borderRadius: AppRadius.buttonAll,
                      ),
                      child: Icon(icon, color: context.colors.onPrimaryContainer, size: AppSizes.iconLg),
                    ),
                  ),
                  AppSpacing.gapMd,
                ],
                Semantics(header: true, child: Text(title, style: context.textStyles.headlineMedium)),
                AppSpacing.gapXs,
                Text(subtitle, style: context.textStyles.bodyMedium?.copyWith(color: context.appColors.textSecondary)),
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

/// Required checkbox that participates in [Form] validation.
class CheckboxFormField extends FormField<bool> {
  CheckboxFormField({
    super.key,
    required Widget label,
    String? requiredMessage,
    bool initialValue = false,
    ValueChanged<bool>? onChanged,
  }) : super(
         initialValue: initialValue,
         validator: requiredMessage == null ? null : (v) => v == true ? null : requiredMessage,
         builder: (state) {
           final context = state.context;
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               CheckboxListTile(
                 value: state.value ?? false,
                 onChanged: (v) {
                   state.didChange(v ?? false);
                   onChanged?.call(v ?? false);
                 },
                 title: label,
                 contentPadding: EdgeInsets.zero,
                 controlAffinity: ListTileControlAffinity.leading,
                 dense: true,
                 isError: state.hasError,
               ),
               if (state.hasError)
                 Padding(
                   padding: const EdgeInsets.only(left: AppSpacing.md),
                   child: Text(
                     state.errorText!,
                     style: context.textStyles.bodySmall?.copyWith(color: context.colors.error),
                   ),
                 ),
             ],
           );
         },
       );
}
