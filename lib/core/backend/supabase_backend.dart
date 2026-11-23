import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase connection settings, injected at build time:
///
/// ```
/// flutter run --dart-define-from-file=supabase.json
/// flutter build apk --release --dart-define-from-file=supabase.json
/// ```
///
/// `supabase.json` is git-ignored (see `supabase.example.json`). Only the
/// project URL and the **publishable** key belong here — never a secret /
/// service_role key, which would give anyone who unpacks the APK full access.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// Secret keys must never ship in a client app.
  static bool isSecretKey(String key) =>
      key.startsWith('sb_secret_') || (key.startsWith('eyJ') && key.contains('c2VydmljZV9yb2xl')); // "service_role"
}

enum BackendStatus {
  /// Built without `--dart-define-from-file=supabase.json`: app runs fully local.
  notConfigured,

  /// Supabase client initialised (no feature depends on it yet).
  ready,

  /// Configuration rejected or initialisation failed; app keeps running locally.
  failed,
}

/// Starts the Supabase client when configured. Never throws and never blocks
/// startup for long: the app must work offline and without a backend.
abstract final class SupabaseBackend {
  static BackendStatus _status = BackendStatus.notConfigured;
  static BackendStatus get status => _status;

  /// The client, or null when the backend is not available.
  static SupabaseClient? get client => _status == BackendStatus.ready ? Supabase.instance.client : null;

  static Future<BackendStatus> initialize({
    String url = SupabaseConfig.url,
    String publishableKey = SupabaseConfig.publishableKey,
  }) async {
    if (url.isEmpty || publishableKey.isEmpty) return _status = BackendStatus.notConfigured;
    if (SupabaseConfig.isSecretKey(publishableKey) || !url.startsWith('https://')) {
      debugPrint('Supabase not started: use the project https URL and a publishable key only.');
      return _status = BackendStatus.failed;
    }
    try {
      await Supabase.initialize(url: url, publishableKey: publishableKey).timeout(const Duration(seconds: 8));
      return _status = BackendStatus.ready;
    } catch (error) {
      debugPrint('Supabase unavailable, continuing with local data: $error');
      return _status = BackendStatus.failed;
    }
  }
}
