import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'core/settings/app_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  final services = await AppServices.create(SharedPrefsSettingsStore());
  runApp(XadiisApp(services: services));
}

/// OFL requires the license to ship with the font; this makes it appear in
/// Flutter's licenses page (showLicensePage / About screen).
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/Amiri-OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Amiri font'], text);
  });
}
