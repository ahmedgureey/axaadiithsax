import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Why an in-app update could not finish (Somali message for the user).
class ApkInstallException implements Exception {
  const ApkInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Result of [ApkInstaller.install].
enum ApkInstallResult {
  /// Android's installer screen was opened.
  started,

  /// The user must first allow "install unknown apps" for this app; the
  /// system settings page was opened. Tap "Cusboonaysii" again afterwards.
  needsPermission,
}

/// Downloads the new APK inside the app and opens Android's installer, so
/// the update never depends on the phone's browser.
abstract interface class ApkInstaller {
  /// Downloads [url]; [onProgress] gets 0..1, or null when the size is unknown.
  /// Returns the saved file's path.
  Future<String> download(Uri url, void Function(double? progress) onProgress);

  /// Opens the installer for the file from [download].
  Future<ApkInstallResult> install(String path);
}

/// Android implementation (Dart download + `com.xadiithapp.app/update` channel).
class AndroidApkInstaller implements ApkInstaller {
  AndroidApkInstaller({http.Client? client, MethodChannel? channel})
    : _client = client ?? http.Client(),
      _channel = channel ?? const MethodChannel('com.xadiithapp.app/update');

  static const fileName = 'Xadiith-App.apk';

  final http.Client _client;
  final MethodChannel _channel;

  @override
  Future<String> download(Uri url, void Function(double? progress) onProgress) async {
    final dir = await _channel.invokeMethod<String>('updatesDir');
    if (dir == null) throw const ApkInstallException('Meel faylka lagu keydiyo lama helin.');
    final file = File('$dir/$fileName');
    final http.StreamedResponse response;
    try {
      response = await _client.send(http.Request('GET', url)).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApkInstallException('Server-ku wuu daahay. Hubi internetka kadibna isku day mar kale.');
    } on SocketException {
      throw const ApkInstallException('Internet lama heli karo. Hubi internetka kadibna isku day mar kale.');
    }
    if (response.statusCode != 200) {
      throw ApkInstallException('Faylka cusub lama heli karo (${response.statusCode}).');
    }
    final total = response.contentLength;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total == null || total == 0 ? null : received / total);
      }
    } on TimeoutException {
      throw const ApkInstallException('Soo dejintu way istaagtay. Hubi internetka kadibna isku day mar kale.');
    } on SocketException {
      throw const ApkInstallException('Internetku wuu go\'ay. Isku day mar kale.');
    } finally {
      await sink.close();
    }
    if (received == 0 || (total != null && received != total)) {
      throw const ApkInstallException('Faylka si buuxda looma soo dejin. Isku day mar kale.');
    }
    return file.path;
  }

  @override
  Future<ApkInstallResult> install(String path) async {
    final allowed = await _channel.invokeMethod<bool>('canInstall') ?? false;
    if (!allowed) {
      await _channel.invokeMethod<bool>('openInstallSettings');
      return ApkInstallResult.needsPermission;
    }
    final ok = await _channel.invokeMethod<bool>('installApk', {'path': path}) ?? false;
    if (!ok) throw const ApkInstallException('Rakibaadda lama furi karin.');
    return ApkInstallResult.started;
  }
}
