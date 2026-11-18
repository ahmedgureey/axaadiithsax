import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'core/settings/app_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  runApp(XadiisApp(services: await _createServices()));
}

/// Local storage can fail (corrupt prefs, platform channel error). The app
/// must still start: fall back to in-memory storage with default settings.
Future<AppServices> _createServices() async {
  try {
    return await AppServices.create(SharedPrefsSettingsStore());
  } catch (error, stack) {
    debugPrint('Local storage unavailable, using in-memory defaults: $error');
    debugPrintStack(stackTrace: stack, maxFrames: 5);
    return AppServices.create(InMemorySettingsStore());
  }
}

/// OFL requires the license to ship with the font; this makes it appear in
/// Flutter's licenses page (showLicensePage / About screen).
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/Amiri-OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Amiri font'], text);
  });
}
