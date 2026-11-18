import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Semantic colours that Material's [ColorScheme] does not cover
/// (gold accent, success/warning, text tiers, card border...).
///
/// Read with `context.appColors`.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.gold,
    required this.goldText,
    required this.goldSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.divider,
    required this.cardBorder,
    required this.arabicText,
    required this.patternStroke,
  });

  /// Decorative gold (ornaments, icons, borders).
  final Color gold;

  /// Gold that is safe for small text on the current background.
  final Color goldText;

  /// Very soft gold tint for highlighted backgrounds.
  final Color goldSubtle;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color success;
  final Color warning;
  final Color divider;
  final Color cardBorder;

  /// Colour for Arabic hadith text (slightly deeper than body text).
  final Color arabicText;

  /// Stroke for subtle geometric pattern decoration.
  final Color patternStroke;

  static const AppThemeColors light = AppThemeColors(
    gold: AppPalette.softGold,
    goldText: AppPalette.goldText,
    goldSubtle: Color(0x1FC6A15B),
    textPrimary: AppPalette.textPrimary,
    textSecondary: AppPalette.textSecondary,
    textDisabled: AppPalette.textDisabled,
    success: AppPalette.success,
    warning: AppPalette.warning,
    divider: AppPalette.divider,
    cardBorder: AppPalette.divider,
    arabicText: AppPalette.deepGreen,
    patternStroke: Color(0x26C6A15B),
  );

  static const AppThemeColors dark = AppThemeColors(
    gold: AppPalette.nightGold,
    goldText: AppPalette.nightGold,
    goldSubtle: Color(0x26D9B877),
    textPrimary: AppPalette.darkTextPrimary,
    textSecondary: AppPalette.darkTextSecondary,
    textDisabled: AppPalette.darkTextDisabled,
    success: AppPalette.darkSuccess,
    warning: AppPalette.darkWarning,
    divider: AppPalette.darkDivider,
    cardBorder: AppPalette.darkDivider,
    arabicText: AppPalette.darkTextPrimary,
    patternStroke: Color(0x1FD9B877),
  );

  @override
  AppThemeColors copyWith({
    Color? gold,
    Color? goldText,
    Color? goldSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? success,
    Color? warning,
    Color? divider,
    Color? cardBorder,
    Color? arabicText,
    Color? patternStroke,
  }) {
    return AppThemeColors(
      gold: gold ?? this.gold,
      goldText: goldText ?? this.goldText,
      goldSubtle: goldSubtle ?? this.goldSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      divider: divider ?? this.divider,
      cardBorder: cardBorder ?? this.cardBorder,
      arabicText: arabicText ?? this.arabicText,
      patternStroke: patternStroke ?? this.patternStroke,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      gold: Color.lerp(gold, other.gold, t)!,
      goldText: Color.lerp(goldText, other.goldText, t)!,
      goldSubtle: Color.lerp(goldSubtle, other.goldSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      arabicText: Color.lerp(arabicText, other.arabicText, t)!,
      patternStroke: Color.lerp(patternStroke, other.patternStroke, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  AppThemeColors get appColors => Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.light;
}
