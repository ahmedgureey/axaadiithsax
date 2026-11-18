import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/theme/theme.dart';

double _luminance(Color c) => c.computeLuminance();

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('AppTheme', () {
    test('light and dark themes use Material 3 and the right brightness', () {
      expect(AppTheme.light.useMaterial3, isTrue);
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    });

    test('both themes register AppThemeColors extension', () {
      expect(AppTheme.light.extension<AppThemeColors>(), AppThemeColors.light);
      expect(AppTheme.dark.extension<AppThemeColors>(), AppThemeColors.dark);
    });

    for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
      group('${entry.key} contrast (WCAG AA)', () {
        final t = entry.value;
        final s = t.colorScheme;
        final c = t.extension<AppThemeColors>()!;
        final card = s.brightness == Brightness.dark ? s.surfaceContainerHigh : s.surfaceContainerLowest;

        test('body text on background ≥ 4.5', () {
          expect(contrast(c.textPrimary, s.surface), greaterThanOrEqualTo(4.5));
          expect(contrast(c.textPrimary, card), greaterThanOrEqualTo(4.5));
        });
        test('secondary text on background and cards ≥ 4.5', () {
          expect(contrast(c.textSecondary, s.surface), greaterThanOrEqualTo(4.5));
          expect(contrast(c.textSecondary, card), greaterThanOrEqualTo(4.5));
        });
        test('primary button label ≥ 4.5', () {
          expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
        });
        test('small gold text ≥ 4.5', () {
          expect(contrast(c.goldText, s.surface), greaterThanOrEqualTo(4.5));
        });
        test('Arabic text ≥ 7 (AAA, long reading)', () {
          expect(contrast(c.arabicText, card), greaterThanOrEqualTo(7));
        });
        test('error and warning text ≥ 4.5', () {
          expect(contrast(s.error, s.surface), greaterThanOrEqualTo(4.5));
          expect(contrast(c.warning, s.surface), greaterThanOrEqualTo(4.5));
        });
      });
    }
  });
}
