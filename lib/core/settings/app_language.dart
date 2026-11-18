import 'package:flutter/widgets.dart';

/// Interface language preference.
///
/// Only Somali is a complete translation. Arabic and English currently change
/// the system texts (dialogs, pickers, tooltips from Flutter), the layout
/// direction (Arabic = RTL) and the strings in `AppStrings` — the rest of the
/// interface stays Somali until translations are added. Hadith text and its
/// Somali translation are never machine-translated.
enum AppLanguage {
  somali('so', 'Af-Soomaali', 'Somali', isComplete: true),
  arabic('ar', 'العربية', 'Arabic'),
  english('en', 'English', 'English');

  const AppLanguage(this.code, this.nativeName, this.englishName, {this.isComplete = false});

  final String code;
  final String nativeName;
  final String englishName;

  /// True when every screen is translated.
  final bool isComplete;

  Locale get locale => Locale(code);
  TextDirection get textDirection => this == arabic ? TextDirection.rtl : TextDirection.ltr;

  static AppLanguage fromCode(String? code) =>
      AppLanguage.values.firstWhere((l) => l.code == code, orElse: () => AppLanguage.somali);
}
