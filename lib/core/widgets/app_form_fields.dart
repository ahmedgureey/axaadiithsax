import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';

/// Labelled text input with helper and validation text.
///
/// The [label] is rendered above the field (always visible — better for
/// older users than a floating label) and is used as the semantics label.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.inputFormatters,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Text(label, style: context.textStyles.titleSmall)),
        AppSpacing.gapXs,
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          maxLines: obscureText ? 1 : maxLines,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: context.textStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            helperMaxLines: 2,
            errorMaxLines: 3,
            semanticCounterText: label,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            suffixIcon: suffix,
          ).copyWith(labelText: null),
        ),
      ],
    );
  }
}

/// Password input with show/hide toggle.
class PasswordTextField extends StatefulWidget {
  const PasswordTextField({
    super.key,
    this.label = 'Furaha sirta ah',
    this.controller,
    this.hintText,
    this.helperText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.isNewPassword = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;

  /// Registration screens: hints the OS to offer a strong password.
  final bool isNewPassword;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      hintText: widget.hintText,
      helperText: widget.helperText,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      textInputAction: widget.textInputAction,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: [widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password],
      obscureText: _obscured,
      prefixIcon: Icons.lock_outline_rounded,
      suffix: IconButton(
        tooltip: _obscured ? 'Muuji furaha' : 'Qari furaha',
        icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
}

enum FormMessageType { error, success, info }

/// Form-level message (e.g. "Email ama furaha waa khalad").
class FormValidationMessage extends StatelessWidget {
  const FormValidationMessage({super.key, required this.message, this.type = FormMessageType.error});

  final String message;
  final FormMessageType type;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final c = context.appColors;
    final (Color color, IconData icon) = switch (type) {
      FormMessageType.error => (scheme.error, Icons.error_outline_rounded),
      FormMessageType.success => (c.success, Icons.check_circle_outline_rounded),
      FormMessageType.info => (c.goldText, Icons.info_outline_rounded),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: AppRadius.buttonAll,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: AppSizes.icon),
            AppSpacing.gapSm,
            Expanded(
              child: Text(message, style: context.textStyles.bodyMedium?.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple reusable validators (Somali messages).
abstract final class AppValidators {
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? required(String? value, {String field = 'Goobtan'}) =>
      (value == null || value.trim().isEmpty) ? '$field waa qasab.' : null;

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Fadlan geli email-kaaga.';
    if (!_emailRegex.hasMatch(value.trim())) return 'Email-ku sax maaha.';
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) return 'Fadlan geli furaha sirta ah.';
    if (value.length < minLength) return 'Furuhu waa inuu ahaadaa ugu yaraan $minLength xaraf.';
    return null;
  }

  /// Confirmation must be present and identical (compared exactly — never trimmed).
  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Fadlan ku celi furaha sirta ah.';
    if (value != original) return 'Furayaashu isma laha.';
    return null;
  }
}
