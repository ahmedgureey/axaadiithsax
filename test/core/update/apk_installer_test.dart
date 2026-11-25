import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xadiithapp/core/update/apk_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.xadiithapp.app/update');
  late Directory dir;
  final calls = <MethodCall>[];
  var canInstall = true;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('apk_test');
    calls.clear();
    canInstall = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'updatesDir' => dir.path,
        'canInstall' => canInstall,
        _ => true,
      };
    });
  });
  tearDown(() => dir.deleteSync(recursive: true));

  final bytes = List<int>.generate(5000, (i) => i % 256);

  test('downloads the whole file with progress and opens the installer', () async {
    final progress = <double?>[];
    final installer = AndroidApkInstaller(
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.fromIterable([bytes.sublist(0, 2000), bytes.sublist(2000)]),
          200,
          contentLength: bytes.length,
        ),
      ),
    );
    final path = await installer.download(Uri.parse('https://example.invalid/a.apk'), progress.add);
    expect(File(path).readAsBytesSync(), bytes);
    expect(progress.last, 1.0);
    expect(await installer.install(path), ApkInstallResult.started);
    expect(calls.last.method, 'installApk');
    expect(calls.last.arguments, {'path': path});
  });

  test('an incomplete download is rejected', () async {
    final installer = AndroidApkInstaller(
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(Stream.value(bytes.sublist(0, 100)), 200, contentLength: bytes.length),
      ),
    );
    await expectLater(
      installer.download(Uri.parse('https://example.invalid/a.apk'), (_) {}),
      throwsA(isA<ApkInstallException>()),
    );
  });

  test('a missing file (404) is reported in Somali', () async {
    final installer = AndroidApkInstaller(client: MockClient((_) async => http.Response('nope', 404)));
    await expectLater(
      installer.download(Uri.parse('https://example.invalid/a.apk'), (_) {}),
      throwsA(isA<ApkInstallException>().having((e) => e.message, 'message', contains('404'))),
    );
  });

  test('without install permission: opens the settings page instead', () async {
    canInstall = false;
    final installer = AndroidApkInstaller(client: MockClient((_) async => http.Response('', 200)));
    expect(await installer.install('${dir.path}/x.apk'), ApkInstallResult.needsPermission);
    expect(calls.map((c) => c.method), ['canInstall', 'openInstallSettings']);
  });
}
