import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/theme/app_typography.dart';

void main() {
  group('AppSettingsController', () {
    test('defaults to system theme and default Arabic size', () async {
      final c = AppSettingsController(InMemorySettingsStore());
      await c.load();
      expect(c.themeMode, ThemeMode.system);
      expect(c.arabicFontSize, ArabicFontSize.defaultSize);
    });

    test('persists and restores theme mode', () async {
      final store = InMemorySettingsStore();
      await AppSettingsController(store).setThemeMode(ThemeMode.dark);

      final restored = AppSettingsController(store);
      await restored.load();
      expect(restored.themeMode, ThemeMode.dark);
    });

    test('clamps and persists Arabic font size', () async {
      final store = InMemorySettingsStore();
      final c = AppSettingsController(store);
      await c.setArabicFontSize(999);
      expect(c.arabicFontSize, ArabicFontSize.max);

      final restored = AppSettingsController(store);
      await restored.load();
      expect(restored.arabicFontSize, ArabicFontSize.max);
    });

    test('ignores corrupt stored values', () async {
      final c = AppSettingsController(InMemorySettingsStore({'settings.themeMode': 'purple'}));
      await c.load();
      expect(c.themeMode, ThemeMode.system);
    });

    test('notifies listeners on change', () async {
      final c = AppSettingsController(InMemorySettingsStore());
      var calls = 0;
      c.addListener(() => calls++);
      await c.setThemeMode(ThemeMode.light);
      await c.setThemeMode(ThemeMode.light); // no-op
      expect(calls, 1);
    });
  });
}
