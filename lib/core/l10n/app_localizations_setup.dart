import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../settings/app_language.dart';

/// Flutter's built-in localizations cover Arabic and English but not Somali.
/// For Somali these delegates supply Flutter's default (English) system
/// strings — dialog buttons, picker labels — while the app's own text stays
/// Somali. Replace with real Somali system strings when available.
class _SomaliFallbackMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _SomaliFallbackMaterialDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'so';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(const DefaultMaterialLocalizations());

  @override
  bool shouldReload(_SomaliFallbackMaterialDelegate old) => false;
}

class _SomaliFallbackCupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _SomaliFallbackCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'so';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(const DefaultCupertinoLocalizations());

  @override
  bool shouldReload(_SomaliFallbackCupertinoDelegate old) => false;
}

abstract final class AppLocalizationsSetup {
  static List<Locale> get supportedLocales => [for (final l in AppLanguage.values) l.locale];

  static const delegates = <LocalizationsDelegate<dynamic>>[
    _SomaliFallbackMaterialDelegate(),
    _SomaliFallbackCupertinoDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];
}
