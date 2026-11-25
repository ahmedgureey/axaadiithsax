import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_info.dart';

/// What the published `update.json` asks this installed build to do.
enum UpdateKind { none, optional, required }

@immutable
class UpdateInfo {
  const UpdateInfo({required this.kind, required this.version, required this.downloadUrl, required this.message});

  final UpdateKind kind;

  /// Newest version name, e.g. "1.0.9".
  final String version;

  /// Where the new APK can be downloaded (https).
  final Uri downloadUrl;
  final String message;
}

/// Reads `update.json` from the project's GitHub repository:
///
/// ```json
/// {
///   "latest_build": 9,        // newest build number (pubspec "+N")
///   "min_build": 9,           // builds below this MUST update
///   "version": "1.0.8",
///   "apk_url": "https://github.com/…/releases/latest",
///   "message": "Nooc cusub ayaa diyaar ah."
/// }
/// ```
///
/// Offline, slow or invalid → [UpdateKind.none]: users are never blocked
/// because the check could not run.
class UpdateChecker {
  UpdateChecker({Future<String?> Function(Uri url)? fetch, int? currentBuild, this.url})
    : _fetch = fetch ?? _httpGet,
      currentBuild = currentBuild ?? int.parse(AppInfo.buildNumber);

  static final defaultUrl = Uri.parse('https://raw.githubusercontent.com/ahmedgureey/axaadiithsax/main/update.json');
  static const timeout = Duration(seconds: 6);

  final Future<String?> Function(Uri url) _fetch;
  final int currentBuild;
  final Uri? url;

  static Future<String?> _httpGet(Uri url) async {
    final r = await http.get(url).timeout(timeout);
    return r.statusCode == 200 ? utf8.decode(r.bodyBytes) : null;
  }

  Future<UpdateInfo?> check() async => (await report()).info;

  /// Full result of one check, with the reason (for "Hubi cusboonaysiin").
  Future<UpdateReport> report() async {
    String? body;
    try {
      body = await _fetch(url ?? defaultUrl);
    } on TimeoutException {
      return UpdateReport(currentBuild: currentBuild, problem: 'Server-ku wuu daahay. Hubi internetka.');
    } catch (e) {
      debugPrint('Update check failed: $e');
      return UpdateReport(currentBuild: currentBuild, problem: 'Internet lama heli karo.');
    }
    if (body == null) {
      return UpdateReport(currentBuild: currentBuild, problem: 'Faylka update.json lama helin.');
    }
    Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return UpdateReport(currentBuild: currentBuild, problem: 'update.json si sax ah looma akhrin karo.');
    }
    final map = json is Map ? json : const {};
    final latest = map['latest_build'], min = map['min_build'];
    final info = parse(json, currentBuild);
    return UpdateReport(
      currentBuild: currentBuild,
      latestBuild: latest is num ? latest.toInt() : null,
      minBuild: min is num ? min.toInt() : null,
      info: info,
      problem: latest is num ? null : 'update.json waxaa ka maqan latest_build.',
    );
  }

  /// Pure decision from the JSON (testable). Null when nothing to show.
  static UpdateInfo? parse(Object? json, int currentBuild) {
    if (json is! Map) return null;
    final latest = json['latest_build'];
    final min = json['min_build'];
    final url = Uri.tryParse('${json['apk_url'] ?? ''}');
    if (latest is! num || url == null || url.scheme != 'https' || url.host.isEmpty) return null;
    final kind = min is num && currentBuild < min
        ? UpdateKind.required
        : currentBuild < latest
        ? UpdateKind.optional
        : UpdateKind.none;
    if (kind == UpdateKind.none) return null;
    final message = json['message'];
    return UpdateInfo(
      kind: kind,
      version: '${json['version'] ?? ''}',
      downloadUrl: url,
      message: message is String && message.trim().isNotEmpty ? message : 'Nooc cusub oo app-ka ah ayaa diyaar ah.',
    );
  }
}

/// What one check found (shown by the "Hubi cusboonaysiin" button).
@immutable
class UpdateReport {
  const UpdateReport({required this.currentBuild, this.latestBuild, this.minBuild, this.info, this.problem});

  /// Build number of the installed app.
  final int currentBuild;

  /// Values read from update.json (null if not read).
  final int? latestBuild;
  final int? minBuild;

  /// Update to offer, or null.
  final UpdateInfo? info;

  /// Why the check could not complete, in Somali (null when it did).
  final String? problem;

  /// One-line Somali summary.
  String get summary {
    if (problem != null) return problem!;
    return switch (info?.kind) {
      UpdateKind.required => 'Cusboonaysiin qasab ah ayaa jirta.',
      UpdateKind.optional => 'Nooc cusub ayaa jira.',
      _ => 'App-kaagu waa nooca ugu dambeeyay.',
    };
  }
}
