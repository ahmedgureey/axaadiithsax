/// Applies a validated [Dataset] to Supabase through PostgREST.
///
/// Safety rules:
/// * INSERT only — existing rows are never updated or deleted
///   (`resolution=ignore-duplicates`). Re-running the same file is therefore
///   safe and acts as a resume: already-imported records are skipped.
/// * Everything arrives as `imported`. Verification/publishing is impossible
///   from here (the database refuses it outside `review_record()`).
/// * Every hadith/translation/grading carries `import_batch_id`; the batch row
///   records source, licence, file checksum, counts and errors.
/// * Translations, gradings and topics are added only for hadith created in
///   this run, so reviewed records are never touched.
library;

import 'dart:convert';
import 'dart:io';

import 'dataset.dart';

const toolVersion = 'hadith_import/1.0.0';

/// Minimal REST surface the importer needs (fakeable in tests).
abstract class RestClient {
  /// POST rows to [table]; returns the rows the server actually inserted.
  Future<List<Map<String, dynamic>>> insert(
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
    bool ignoreDuplicates = false,
  });

  Future<List<Map<String, dynamic>>> select(String table, Map<String, String> query);

  /// PATCH used ONLY for the import_batches bookkeeping row.
  Future<void> updateBatch(String batchId, Map<String, dynamic> values);
}

class ImportResult {
  ImportResult(this.batchId);
  final String batchId;
  final counts = <String, int>{
    'hadiths_inserted': 0,
    'hadiths_skipped_existing': 0,
    'translations_inserted': 0,
    'gradings_inserted': 0,
    'categories_linked': 0,
    'books_inserted': 0,
    'chapters_inserted': 0,
  };
  final errors = <Map<String, String>>[];
}

class Importer {
  Importer(this.client, {this.batchSize = 200});

  final RestClient client;
  final int batchSize;

  Future<ImportResult> run(Dataset data, {required String fileName, required String fileSha256}) async {
    final prov = data.provenance;
    final batchRows = await client.insert('import_batches', [
      {
        'source_name': prov['source_name'],
        'source_edition': prov['source_edition'],
        'source_url': prov['source_url'],
        'license': prov['license'],
        'file_name': fileName,
        'file_sha256': fileSha256,
        'tool_version': toolVersion,
      },
    ]);
    final result = ImportResult(batchRows.single['id'] as String);

    try {
      await _apply(data, result);
      await client.updateBatch(result.batchId, {
        'state': result.errors.isEmpty ? 'completed' : 'failed',
        'finished_at': DateTime.now().toUtc().toIso8601String(),
        'counts': result.counts,
        'errors': result.errors,
      });
    } catch (e) {
      result.errors.add({'stage': 'fatal', 'message': '$e'});
      await client.updateBatch(result.batchId, {
        'state': 'failed',
        'finished_at': DateTime.now().toUtc().toIso8601String(),
        'counts': result.counts,
        'errors': result.errors,
      });
      rethrow;
    }
    return result;
  }

  Future<void> _apply(Dataset data, ImportResult result) async {
    final col = data.collection;
    final collectionId = col['id'] as String;
    final scheme = data.numberingScheme;

    // Collection: created if missing, never modified.
    await client.insert(
      'collections',
      [
        {
          for (final k in [
            'id', 'name_ar', 'name_en', 'name_so', 'compiler_ar', 'compiler_en', 'description_so',
            'description_en', 'edition', 'publisher', 'source_reference', 'source_url', //
          ])
            if (col[k] != null) k: col[k],
        },
      ],
      onConflict: 'id',
      ignoreDuplicates: true,
    );

    // Books, then their ids.
    final insertedBooks = await client.insert(
      'books',
      [
        for (final b in data.books)
          {
            'collection_id': collectionId,
            'book_number': b['book_number'],
            'title_ar': b['title_ar'],
            'title_en': b['title_en'],
            'title_so': b['title_so'],
            'sort_order': b['sort_order'],
          },
      ],
      onConflict: 'collection_id,book_number',
      ignoreDuplicates: true,
    );
    result.counts['books_inserted'] = insertedBooks.length;
    final bookIds = {
      for (final b in await client.select('books', {'select': 'id,book_number', 'collection_id': 'eq.$collectionId'}))
        b['book_number'] as String: b['id'] as String,
    };

    // Chapters, then their ids.
    if (data.chapters.isNotEmpty) {
      final insertedChapters = await client.insert(
        'chapters',
        [
          for (final c in data.chapters)
            {
              'book_id': bookIds[c['book_number']],
              'sort_order': c['sort_order'],
              'chapter_number': c['chapter_number'],
              'title_ar': c['title_ar'],
              'title_en': c['title_en'],
              'title_so': c['title_so'],
            },
        ],
        onConflict: 'book_id,sort_order',
        ignoreDuplicates: true,
      );
      result.counts['chapters_inserted'] = insertedChapters.length;
    }
    final chapterIds = <String, String>{};
    for (final entry in bookIds.entries) {
      for (final c in await client.select('chapters', {'select': 'id,sort_order', 'book_id': 'eq.${entry.value}'})) {
        chapterIds['${entry.key}|${c['sort_order']}'] = c['id'] as String;
      }
    }

    final knownCategories = {
      for (final c in await client.select('categories', {'select': 'id'})) c['id'] as String,
    };

    // Hadiths in batches.
    final records = data.hadiths;
    for (var start = 0; start < records.length; start += batchSize) {
      final chunk = records.sublist(start, (start + batchSize).clamp(0, records.length));
      final rows = [
        for (final h in chunk)
          {
            'collection_id': collectionId,
            'numbering_scheme': scheme,
            'hadith_number': h['hadith_number'],
            'source_position': h['source_position'],
            'book_id': bookIds[h['book_number']],
            'chapter_id': chapterIds['${h['book_number']}|${h['chapter_sort']}'],
            'arabic_text': h['arabic_text'], // exactly as in the file
            'arabic_text_vowelized': h['arabic_text_vowelized'],
            'vowelized_verified': false,
            'narrator_text_ar': h['narrator_text_ar'],
            'normalization_notes': h['normalization_notes'],
            'source_name': data.provenance['source_name'],
            'source_edition': data.provenance['source_edition'],
            'source_identifier': h['source_identifier'],
            'source_url': h['source_url'],
            'import_batch_id': result.batchId,
          },
      ];

      final List<Map<String, dynamic>> inserted;
      try {
        inserted = await client.insert(
          'hadiths',
          rows,
          onConflict: 'collection_id,numbering_scheme,hadith_number',
          ignoreDuplicates: true,
        );
      } catch (e) {
        result.errors.add({'stage': 'hadiths', 'batch_start': '$start', 'message': '$e'});
        continue; // next batch; the run can be repeated later to resume
      }
      result.counts['hadiths_inserted'] = result.counts['hadiths_inserted']! + inserted.length;
      result.counts['hadiths_skipped_existing'] =
          result.counts['hadiths_skipped_existing']! + (chunk.length - inserted.length);

      final newIds = {for (final r in inserted) r['hadith_number'] as String: r['id'] as String};
      final translations = <Map<String, dynamic>>[];
      final gradings = <Map<String, dynamic>>[];
      final links = <Map<String, dynamic>>[];
      for (final h in chunk) {
        final id = newIds[h['hadith_number']];
        if (id == null) continue; // existing record: leave it alone
        for (final t in (h['translations'] as List? ?? const [])) {
          final m = t as Map<String, dynamic>;
          translations.add({
            'hadith_id': id,
            'language': m['language'] ?? 'so',
            'text': m['text'],
            'translator': m['translator'],
            'translation_source': m['translation_source'],
            'source_url': m['source_url'],
            'is_primary': m['is_primary'] == true,
            'import_batch_id': result.batchId,
          });
        }
        for (final g in (h['gradings'] as List? ?? const [])) {
          final m = g as Map<String, dynamic>;
          gradings.add({
            'hadith_id': id,
            'grade': m['grade'],
            'grade_label_ar': m['grade_label_ar'],
            'scholar': m['scholar'],
            'source_reference': m['source_reference'],
            'source_url': m['source_url'],
            'disagreement_notes': m['disagreement_notes'],
            'import_batch_id': result.batchId,
          });
        }
        for (final c in (h['categories'] as List? ?? const [])) {
          if (knownCategories.contains(c)) {
            links.add({'hadith_id': id, 'category_id': c});
          } else {
            result.errors.add({
              'stage': 'categories',
              'hadith_number': '${h['hadith_number']}',
              'message': 'unknown category "$c"',
            });
          }
        }
      }
      await _insertChild('translations', translations, result, 'translations_inserted');
      await _insertChild('gradings', gradings, result, 'gradings_inserted');
      await _insertChild('hadith_categories', links, result, 'categories_linked');
    }
  }

  Future<void> _insertChild(String table, List<Map<String, dynamic>> rows, ImportResult result, String counter) async {
    if (rows.isEmpty) return;
    try {
      final inserted = await client.insert(table, rows, ignoreDuplicates: true);
      result.counts[counter] = result.counts[counter]! + inserted.length;
    } catch (e) {
      result.errors.add({'stage': table, 'message': '$e'});
    }
  }
}

/// PostgREST over HTTPS with the project's SECRET key (server-side only).
class PostgrestClient implements RestClient {
  PostgrestClient(this.baseUrl, this._secretKey);

  final String baseUrl;
  final String _secretKey;
  final _http = HttpClient();

  Map<String, String> get _auth => {
    'apikey': _secretKey,
    // Legacy service_role keys are JWTs and also go in Authorization.
    if (_secretKey.startsWith('eyJ')) 'Authorization': 'Bearer $_secretKey',
  };

  Uri _uri(String table, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/rest/v1/$table').replace(queryParameters: query);

  Future<Object?> _send(String method, Uri uri, {Object? body, Map<String, String> headers = const {}}) async {
    final req = await _http.openUrl(method, uri);
    _auth.forEach(req.headers.set);
    headers.forEach(req.headers.set);
    req.headers.contentType = ContentType.json;
    if (body != null) req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close();
    final text = await utf8.decodeStream(res);
    if (res.statusCode >= 300) {
      // Server message only — never echo request headers (they hold the key).
      throw HttpException('$method ${uri.path} → ${res.statusCode}: $text');
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  @override
  Future<List<Map<String, dynamic>>> insert(
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
    bool ignoreDuplicates = false,
  }) async {
    final out = await _send(
      'POST',
      _uri(table, {'on_conflict': ?onConflict}),
      body: rows,
      headers: {
        'Prefer': ['return=representation', if (ignoreDuplicates) 'resolution=ignore-duplicates'].join(','),
      },
    );
    return [for (final r in (out as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
  }

  @override
  Future<List<Map<String, dynamic>>> select(String table, Map<String, String> query) async {
    final out = await _send('GET', _uri(table, query));
    return [for (final r in (out as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
  }

  @override
  Future<void> updateBatch(String batchId, Map<String, dynamic> values) async {
    await _send('PATCH', _uri('import_batches', {'id': 'eq.$batchId'}), body: values);
  }

  void close() => _http.close();
}
