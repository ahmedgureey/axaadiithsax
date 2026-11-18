import 'package:flutter/material.dart';

/// Spacing scale (4-pt grid). Use these instead of arbitrary numbers.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Default horizontal padding for screen content.
  static const double screen = md;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: screen);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  static const SizedBox gapXxs = SizedBox(width: xxs, height: xxs);
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 8; // chips, small controls
  static const double button = 14;
  static const double card = 16;
  static const double dialog = 24;
  static const double large = 28; // sheets, hero containers
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius buttonAll = BorderRadius.all(Radius.circular(button));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius dialogAll = BorderRadius.all(Radius.circular(dialog));
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Component sizes.
abstract final class AppSizes {
  /// Minimum touch target for interactive controls (Material/Apple guidance).
  static const double minTouchTarget = 48;
  static const double buttonHeight = 52;
  static const double inputHeight = 52;
  static const double iconSm = 18;
  static const double icon = 22;
  static const double iconLg = 28;
  static const double avatar = 44;

  /// Max readable width for long-form content on tablets.
  static const double maxContentWidth = 640;
}

/// Durations — keep motion subtle.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
}
