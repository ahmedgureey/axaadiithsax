/// Converts a downloaded fawazahmed0/hadith-api edition file into an import
/// file (`xadiith-import/1`), then validate it with hadith_import.dart.
///
/// ```
/// dart run tool/hadith_import/convert_fawazahmed0.dart SRC.json OUT.json
///   --edition=ara-nawawi --commit=<full git sha> --collection=nawawi40
///   --name-ar=<Arabic collection name> [--name-en=...] [--compiler-en=...]
///   --retrieved=YYYY-MM-DD [--br-to-newline]
/// ```
/// `--br-to-newline`: documented fix for HTML `<br>` in the source text; each
/// affected record gets `normalization_notes`.
/// Download the file from the commit-pinned URL so the checksum matches:
/// https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@SHA/editions/EDITION.json
library;

import 'dart:convert';
import 'dart:io';

import 'adapters/fawazahmed0.dart';

void main(List<String> args) {
  String? opt(String name) {
    final a = args.firstWhere((x) => x.startsWith('--$name='), orElse: () => '');
    return a.isEmpty ? null : a.substring(name.length + 3);
  }

  final files = args.where((a) => !a.startsWith('--')).toList();
  final required = ['edition', 'commit', 'collection', 'name-ar', 'retrieved'];
  final missing = [
    for (final r in required)
      if (opt(r) == null) '--$r',
  ];
  if (files.length != 2 || missing.isNotEmpty) {
    stderr.writeln('Usage: convert_fawazahmed0.dart SRC.json OUT.json ${required.map((r) => '--$r=…').join(' ')}');
    if (missing.isNotEmpty) stderr.writeln('Missing: ${missing.join(', ')}');
    exitCode = 64;
    return;
  }
  final commit = opt('commit')!;
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    stderr.writeln('--commit must be the full 40-character git sha');
    exitCode = 64;
    return;
  }

  final source = jsonDecode(utf8.decode(File(files[0]).readAsBytesSync())) as Map<String, dynamic>;
  final result = convertFawazahmed0(
    edition: source,
    editionKey: opt('edition')!,
    commit: commit,
    collectionId: opt('collection')!,
    collectionNameAr: opt('name-ar')!,
    collectionNameEn: opt('name-en'),
    compilerEn: opt('compiler-en'),
    retrievedAt: opt('retrieved')!,
    brToNewline: args.contains('--br-to-newline'),
  );
  File(files[1]).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result.dataset));
  stdout.writeln('Converted ${(result.dataset['hadiths'] as List).length} records → ${files[1]}');
  for (final (n, why) in result.skipped) {
    stdout.writeln('  skipped hadith $n: $why');
  }
}
