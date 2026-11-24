import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'core/backend/supabase_backend.dart';
import 'core/settings/app_settings_controller.dart';
import 'data/bundled/bundled_dataset.dart';
import 'data/remote/catalog_api.dart';
import 'data/repositories/hadith_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  // Optional backend: no-op unless built with --dart-define-from-file=supabase.json.
  await SupabaseBackend.initialize();
  runApp(XadiisApp(services: await _createServices()));
}

/// Local storage can fail (corrupt prefs, platform channel error). The app
/// must still start: fall back to in-memory storage with default settings.
Future<AppServices> _createServices() async {
  try {
    return await _servicesFrom(SharedPrefsSettingsStore());
  } catch (error, stack) {
    debugPrint('Local storage unavailable, using in-memory defaults: $error');
    debugPrintStack(stackTrace: stack, maxFrames: 5);
    return _servicesFrom(InMemorySettingsStore());
  }
}

/// Hadith come from the collection bundled with the app (assets): they work
/// online and offline and need no database. Only if the bundle is missing
/// does the app fall back to the Supabase catalogue (when configured).
Future<AppServices> _servicesFrom(SettingsStore store) async {
  final bundled = await _bundledRepository();
  if (bundled != null) return AppServices.create(store, repository: bundled);
  final client = SupabaseBackend.client;
  return AppServices.create(store, catalogApi: client == null ? null : SupabaseCatalogApi(client));
}

Future<HadithRepository?> _bundledRepository() async {
  final data = await loadBundledDataset(rootBundle);
  if (data == null || data.hadiths.isEmpty) return null;
  return HadithRepository(
    books: [data.book],
    chapters: [data.chapter],
    hadiths: data.hadiths,
    categories: const [],
    studyNotes: await loadBundledStudy(rootBundle),
  );
}

/// OFL requires the license to ship with the font; this makes it appear in
/// Flutter's licenses page (showLicensePage / About screen).
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/Amiri-OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Amiri font'], text);
  });
}
