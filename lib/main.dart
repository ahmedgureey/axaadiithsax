import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app/app.dart';
import 'app/app_services.dart';
import 'core/backend/supabase_backend.dart';
import 'core/settings/app_settings_controller.dart';
import 'data/preview/preview_dataset.dart';
import 'data/remote/catalog_api.dart';
import 'data/repositories/hadith_repository.dart';
import 'features/auth/supabase_auth_gateway.dart';

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

/// With Supabase: published catalogue (loaded on demand, cached offline),
/// real accounts and synced bookmarks. Without it: bundled data and demo auth.
Future<AppServices> _servicesFrom(SettingsStore store) async {
  final client = SupabaseBackend.client;
  final api = client == null ? null : SupabaseCatalogApi(client);
  return AppServices.create(
    store,
    repository: client == null ? await _previewRepository() : null,
    catalogApi: api,
    bookmarkApi: api,
    authGateway: client == null ? null : SupabaseAuthGateway(client),
  );
}

/// LOCAL WEB PREVIEW ONLY (`--dart-define=XADIITH_PREVIEW_DATA=true`): the
/// unverified import file from `web/preview/`, every record marked
/// "lama xaqiijin". Never active in APK / production builds.
Future<HadithRepository?> _previewRepository() async {
  if (!kIsWeb || !PreviewDataset.enabled) return null;
  final data = await loadPreviewDataset((uri) async {
    final response = await http.get(uri);
    return response.statusCode == 200 ? utf8.decode(response.bodyBytes) : null;
  }, base: Uri.base);
  if (data == null) return null;
  return HadithRepository(
    books: [data.book],
    chapters: [data.chapter],
    hadiths: data.hadiths,
    categories: const [],
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
