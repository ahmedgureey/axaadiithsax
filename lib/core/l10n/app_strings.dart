import 'package:flutter/widgets.dart';

import '../settings/app_settings_controller.dart';

/// App-owned interface strings per language — the foundation for full
/// localisation. Only the keys below are translated so far; everything else
/// in the app is Somali. Never put hadith text or its translation here.
enum AppText { navHome, navBooks, navSearch, navMemorize, navProfile }

abstract final class AppStrings {
  static const Map<AppLanguage, Map<AppText, String>> _table = {
    AppLanguage.somali: {
      AppText.navHome: 'Guriga',
      AppText.navBooks: 'Kutubta',
      AppText.navSearch: 'Raadinta',
      AppText.navMemorize: 'Xifdinta',
      AppText.navProfile: 'Aniga',
    },
    AppLanguage.arabic: {
      AppText.navHome: 'الرئيسية',
      AppText.navBooks: 'الكتب',
      AppText.navSearch: 'البحث',
      AppText.navMemorize: 'الحفظ',
      AppText.navProfile: 'حسابي',
    },
    AppLanguage.english: {
      AppText.navHome: 'Home',
      AppText.navBooks: 'Books',
      AppText.navSearch: 'Search',
      AppText.navMemorize: 'Memorize',
      AppText.navProfile: 'Profile',
    },
  };

  /// Missing translations fall back to Somali.
  static String get(AppLanguage language, AppText key) => _table[language]?[key] ?? _table[AppLanguage.somali]![key]!;

  static String of(BuildContext context, AppText key) =>
      get(AppSettingsScope.maybeOf(context)?.language ?? AppLanguage.somali, key);

  /// Number of keys translated for [language] (for honest UI copy).
  static int translatedCount(AppLanguage language) => _table[language]?.length ?? 0;
  static int get totalKeys => AppText.values.length;
}
