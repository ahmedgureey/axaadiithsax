/// Xadiith hadith import tool.
///
/// ```
/// dart run tool/hadith_import/hadith_import.dart FILE.json
///   → validate only (default, no network). Writes FILE.json.report.json.
///
/// dart run tool/hadith_import/hadith_import.dart FILE.json --apply --confirm-project=REF
///   → import into the project in SUPABASE_URL using SUPABASE_SECRET_KEY
///     (environment variables, never committed). REF must match the
///     project in SUPABASE_URL, so the target is always chosen explicitly.
/// ```
///
/// Records are created as 'imported'. Nothing is verified or published here.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

import 'dataset.dart';
import 'importer.dart';

Future<void> main(List<String> args) async {
  final files = args.where((a) => !a.startsWith('--')).toList();
  final apply = args.contains('--apply');
  final confirm = args
      .firstWhere((a) => a.startsWith('--confirm-project='), orElse: () => '')
      .replaceFirst('--confirm-project=', '');

  if (files.length != 1) {
    stderr.writeln('Usage: hadith_import.dart <file.json> [--apply --confirm-project=<ref>]');
    exitCode = 64;
    return;
  }
  final file = File(files.single);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${file.path}');
    exitCode = 66;
    return;
  }

  final bytes = file.readAsBytesSync();
  final digest = sha256.convert(bytes).toString();
  final (report, dataset) = Dataset.parse(utf8.decode(bytes));

  final reportFile = File('${file.path}.report.json');
  final reportJson = <String, Object?>{
    'file': file.path,
    'sha256': digest,
    'tool_version': toolVersion,
    'validated_at': DateTime.now().toUtc().toIso8601String(),
    'validation': report.toJson(),
  };

  stdout.writeln(
    'Validation: ${report.ok ? 'OK' : 'FAILED'} — '
    '${report.hadiths} hadith, ${report.translations} translations, ${report.gradings} gradings, '
    '${report.errors.length} errors, ${report.warnings.length} warnings',
  );
  for (final e in report.errors.take(20)) {
    stdout.writeln('  ERROR $e');
  }
  for (final w in report.warnings.take(10)) {
    stdout.writeln('  warn  $w');
  }

  if (!report.ok || !apply) {
    reportFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(reportJson));
    stdout.writeln('Report: ${reportFile.path}${apply ? '' : '  (dry run — nothing was written)'}');
    if (!report.ok) exitCode = 65;
    return;
  }

  final url = Platform.environment['SUPABASE_URL'] ?? '';
  final key = Platform.environment['SUPABASE_SECRET_KEY'] ?? Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
  final ref = Uri.tryParse(url)?.host.split('.').first ?? '';
  if (url.isEmpty || key.isEmpty) {
    stderr.writeln(
      'Set SUPABASE_URL and SUPABASE_SECRET_KEY in the environment (see tool/hadith_import/.env.example).',
    );
    exitCode = 78;
    return;
  }
  if (key.startsWith('sb_publishable_')) {
    stderr.writeln('A publishable key cannot import (RLS blocks writes). Use the secret key on this machine only.');
    exitCode = 78;
    return;
  }
  if (confirm.isEmpty || confirm != ref) {
    stderr.writeln('Refusing to write: pass --confirm-project=$ref to confirm the target project.');
    exitCode = 77;
    return;
  }

  final client = PostgrestClient(url, key);
  try {
    final result = await Importer(client).run(dataset!, fileName: file.uri.pathSegments.last, fileSha256: digest);
    reportJson['import'] = {
      'batch_id': result.batchId,
      'project': ref,
      'counts': result.counts,
      'errors': result.errors,
    };
    stdout.writeln('Import batch ${result.batchId}: ${result.counts}');
    if (result.errors.isNotEmpty) {
      stdout.writeln('${result.errors.length} errors — see report. Re-run the same command to resume.');
      exitCode = 1;
    }
  } catch (e) {
    reportJson['import'] = {'project': ref, 'fatal': '$e'};
    stderr.writeln('Import failed: $e');
    exitCode = 1;
  } finally {
    client.close();
    reportFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(reportJson));
    stdout.writeln('Report: ${reportFile.path}');
  }
}
