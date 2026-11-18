import 'package:flutter/material.dart';

/// Raw brand palette for Xadiis App.
///
/// This is the ONLY file in the app that may contain hexadecimal colour
/// literals. Widgets must never read these directly — use
/// `Theme.of(context).colorScheme` or `context.appColors` instead so that
/// light and dark mode always stay correct.
///
/// Values marked "adjusted" were darkened/lightened from the original brief
/// to meet WCAG AA contrast (4.5:1 for body text) on their backgrounds.
abstract final class AppPalette {
  // ── Brand greens ───────────────────────────────────────────────────────
  static const Color deepGreen = Color(0xFF123B2A);
  static const Color primaryGreen = Color(0xFF1D5A40);
  static const Color lightGreen = Color(0xFFE7F0E8);

  // ── Neutrals ───────────────────────────────────────────────────────────
  static const Color warmCream = Color(0xFFF8F4E9);
  static const Color creamDeep = Color(0xFFF0E9D8); // inputs / chips on cream
  static const Color pureWhite = Color(0xFFFFFFFF);

  // ── Golds ──────────────────────────────────────────────────────────────
  static const Color softGold = Color(0xFFC6A15B); // decorative only on light
  static const Color darkGold = Color(0xFF9C7B3C); // large text / icons
  static const Color goldText = Color(0xFF7F6230); // adjusted: small gold text on light

  // ── Text (light theme) ─────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF202820);
  static const Color textSecondary = Color(0xFF5E685F); // adjusted from #69736A
  static const Color textDisabled = Color(0xFF9AA19B);

  // ── Status (light theme) ───────────────────────────────────────────────
  static const Color success = Color(0xFF287A4B);
  static const Color warning = Color(0xFF94600F); // adjusted from #A66A16
  static const Color error = Color(0xFFB23A36);
  static const Color divider = Color(0xFFE5E4DC);

  // ── Dark theme ─────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0E1A14);
  static const Color darkSurface = Color(0xFF14231B);
  static const Color darkSurfaceHigh = Color(0xFF1B2D23);
  static const Color darkSurfaceHighest = Color(0xFF23382C);
  static const Color darkPrimary = Color(0xFF8CCBA6);
  static const Color darkOnPrimary = Color(0xFF07291A);
  static const Color darkPrimaryContainer = Color(0xFF1D5A40);
  static const Color nightGold = Color(0xFFD9B877);
  static const Color darkTextPrimary = Color(0xFFEDE7D7);
  static const Color darkTextSecondary = Color(0xFFB4BBB0);
  static const Color darkTextDisabled = Color(0xFF6F7A72);
  static const Color darkDivider = Color(0xFF2C4136);
  static const Color darkSuccess = Color(0xFF7CC79A);
  static const Color darkWarning = Color(0xFFE3B061);
  static const Color darkError = Color(0xFFF0A29E);
  static const Color darkOnError = Color(0xFF4A0E0C);
}
