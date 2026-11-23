import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/backend/supabase_backend.dart';

void main() {
  test('tests run without a backend configured', () {
    expect(SupabaseConfig.isConfigured, isFalse);
    expect(SupabaseBackend.client, isNull);
  });

  test('missing URL or key → notConfigured (app stays local)', () async {
    expect(await SupabaseBackend.initialize(url: '', publishableKey: ''), BackendStatus.notConfigured);
    expect(
      await SupabaseBackend.initialize(url: 'https://x.supabase.co', publishableKey: ''),
      BackendStatus.notConfigured,
    );
  });

  test('secret keys and non-https URLs are refused before any network call', () async {
    expect(SupabaseConfig.isSecretKey('sb_secret_abc'), isTrue);
    expect(SupabaseConfig.isSecretKey('sb_publishable_abc'), isFalse);
    expect(
      await SupabaseBackend.initialize(url: 'https://x.supabase.co', publishableKey: 'sb_secret_abc'),
      BackendStatus.failed,
    );
    expect(
      await SupabaseBackend.initialize(url: 'http://x.supabase.co', publishableKey: 'sb_publishable_abc'),
      BackendStatus.failed,
    );
    expect(SupabaseBackend.client, isNull);
  });
}
