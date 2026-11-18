import 'package:flutter/material.dart';

import '../settings/app_settings_controller.dart';
import 'app_theme_colors.dart';

/// Font configuration.
///
/// Somali / Latin UI text uses the platform system font (Roboto on Android,
/// SF Pro on iOS): highly legible, zero bundle size, full Somali character
/// coverage.
///
/// Arabic text uses the bundled **Amiri** font (`assets/fonts/`, SIL OFL 1.1)
/// so hadith text looks identical on Android and iOS and works offline.
/// Glyphs Amiri lacks fall back to the platform Arabic fonts in
/// [arabicFallback].
abstract final class AppFonts {
  /// Latin UI font. `null` = platform default.
  static const String? uiFamily = null;

  /// Bundled Arabic font family (declared in `pubspec.yaml`).
  static const String arabicFamily = 'Amiri';

  /// System Arabic fonts tried in order for glyphs missing from Amiri.
  static const List<String> arabicFallback = ['Noto Naskh Arabic', 'Geeza Pro', 'Damascus', 'Arial'];
}

/// Reading-size limits for Arabic hadith text (logical pixels).
abstract final class ArabicFontSize {
  static const double min = 20;
  static const double max = 40;
  static const double defaultSize = 26;
}

/// Multiplier for Somali translation text on reading screens.
abstract final class TranslationScale {
  static const double min = 0.9;
  static const double max = 1.4;
  static const double defaultValue = 1.0;
  static const double step = 0.1;

  /// Clamped and rounded to one decimal so repeated steps stay exact.
  static double clamp(double v) => (v.clamp(min, max) * 10).roundToDouble() / 10;
}

/// Line height for Arabic hadith text.
abstract final class ArabicLineHeight {
  static const double min = 1.6;
  static const double max = 2.6;
  static const double defaultValue = 2.0;
  static const double step = 0.2;

  static double clamp(double v) => (v.clamp(min, max) * 10).roundToDouble() / 10;
}

/// Builds the Material [TextTheme] for the app (Somali / Latin text).
abstract final class AppTypography {
  static TextTheme textTheme(AppThemeColors c) {
    final primary = c.textPrimary;
    final secondary = c.textSecondary;
    return TextTheme(
      // Display headings (splash, onboarding hero)
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      // Screen titles
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.25,
      ),
      headlineSmall: TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w700, color: primary),
      // Section headings
      titleLarge: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w600, color: primary),
      // Card titles
      titleMedium: TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w600, color: primary),
      titleSmall: TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w600, color: primary),
      // Somali body / translations
      bodyLarge: TextStyle(fontSize: 17, height: 1.6, fontWeight: FontWeight.w400, color: primary),
      bodyMedium: TextStyle(fontSize: 15, height: 1.55, fontWeight: FontWeight.w400, color: primary),
      // Secondary text
      bodySmall: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w400, color: secondary),
      // Buttons
      labelLarge: TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      // Chips / labels
      labelMedium: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500, color: secondary),
      // Small metadata (reference numbers, dates)
      labelSmall: TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: secondary,
        letterSpacing: 0.2,
      ),
    ).apply(fontFamily: AppFonts.uiFamily);
  }
}

/// Text styles for Arabic content. Always render these inside an RTL region —
/// use the `ArabicText` widget, which does that for you.
abstract final class ArabicTextStyles {
  static TextStyle _base(Color color) => TextStyle(
    fontFamily: AppFonts.arabicFamily,
    fontFamilyFallback: AppFonts.arabicFallback,
    color: color,
    // Arabic letters must never be letter-spaced: it breaks shaping.
    letterSpacing: 0,
  );

  /// Main hadith matn. [fontSize] comes from reading settings.
  static TextStyle hadith(
    BuildContext context, {
    double fontSize = ArabicFontSize.defaultSize,
    double lineHeight = ArabicLineHeight.defaultValue,
  }) {
    return _base(context.appColors.arabicText)
        .copyWith(fontSize: fontSize, height: lineHeight, fontWeight: FontWeight.w400);
  }

  /// Arabic chapter / book headings.
  static TextStyle chapterHeading(BuildContext context) {
    return _base(context.appColors.arabicText).copyWith(fontSize: 22, height: 1.7, fontWeight: FontWeight.w700);
  }

  /// Narrator line, e.g. «عن أبي هريرة رضي الله عنه».
  static TextStyle narrator(BuildContext context, {double fontSize = 18}) {
    return _base(context.appColors.goldText).copyWith(fontSize: fontSize, height: 1.8, fontWeight: FontWeight.w600);
  }

  /// Short Arabic labels inside cards (book name in Arabic, etc.).
  static TextStyle label(BuildContext context) {
    return _base(context.appColors.textSecondary).copyWith(fontSize: 16, height: 1.6);
  }

  /// Somali translation of a hadith — sits under the Arabic text.
  /// Somali translation on reading screens. Uses the reader's translation
  /// size preference unless [scale] is given; the rest of the UI is unaffected.
  static TextStyle somaliTranslation(BuildContext context, {double? scale}) {
    final base = Theme.of(context).textTheme.bodyLarge!;
    final s = scale ?? AppSettingsScope.maybeOf(context)?.translationScale ?? TranslationScale.defaultValue;
    return base.copyWith(fontSize: (base.fontSize ?? 17) * s, height: 1.7);
  }
}
