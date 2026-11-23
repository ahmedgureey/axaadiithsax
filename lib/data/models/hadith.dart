import 'package:flutter/foundation.dart';

/// Where a record's content comes from.
enum SourceStatus {
  /// Placeholder content for UI development. Never shown as authentic.
  demo,

  /// Real text taken unchanged from a documented source (e.g. the bundled
  /// an-Nawawi collection). Not placeholder content; scholarly grading is
  /// shown only for [verified] records.
  sourced,

  /// Text, translation and metadata checked against a reliable source.
  verified,
}

/// A single hadith record.
///
/// * [id] is the stable record identifier used everywhere (routes,
///   favourites, search). [number] is NOT globally unique — it is the
///   position inside its chapter unless the record is verified.
/// * Book name / chapter title are not duplicated here: resolve them through
///   the repository from [bookId] / [chapterId] so they never drift.
/// * Optional fields are `null` when unavailable — screens show an explicit
///   "lama hayo" message instead of inventing content.
/// * [grade] is displayed only when [isVerified].
@immutable
class Hadith {
  const Hadith({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.number,
    required this.arabicText,
    this.somaliText,
    this.narrator,
    this.grade,
    this.reference,
    this.categoryIds = const [],
    this.sourceStatus = SourceStatus.demo,
    this.source,
    this.audio,
    this.numberLabel,
    this.translator,
    this.translationSource,
    this.sourceUrl,
    this.gradings = const [],
    this.narrators = const [],
  });

  final String id;
  final String bookId;
  final String chapterId;

  /// Hadith number (position in chapter for demo records).
  final int number;
  final String arabicText;

  /// Somali translation, or `null` when not yet available.
  final String? somaliText;

  /// Narrator line (Arabic), or `null` when unknown.
  final String? narrator;

  /// Authenticity grade from a reliable source; `null` when unknown.
  final String? grade;

  /// Official reference (e.g. book + number) for verified records.
  final String? reference;

  /// Topic identifiers (see `HadithCategory`).
  final List<String> categoryIds;

  final SourceStatus sourceStatus;

  /// Human-readable description of where the content came from.
  final String? source;

  /// Arabic recitation of this hadith, or `null` — none is ever invented.
  /// Backend records only carry it once the recording's source and licence
  /// were checked and it was published.
  final HadithAudio? audio;

  /// Hadith number exactly as the source gives it (e.g. "52a"). [number]
  /// is the position used for ordering; display [displayNumber].
  final String? numberLabel;

  /// Translator and origin of [somaliText] (backend records).
  final String? translator;
  final String? translationSource;

  /// Link to the record in its documented source.
  final String? sourceUrl;

  /// Scholarly gradings, each with its scholar and reference. Several may
  /// exist and may differ; they are shown as they are, never merged.
  final List<HadithGrading> gradings;

  /// Narrator names as linked in the backend (Arabic).
  final List<String> narrators;

  String get displayNumber => numberLabel ?? number.toString();

  bool get isVerified => sourceStatus == SourceStatus.verified;

  /// Placeholder content (shown with a "Tusaale" badge).
  bool get isDemo => sourceStatus == SourceStatus.demo;
  bool get hasAudio => audio != null;
  bool get hasTranslation => somaliText != null && somaliText!.trim().isNotEmpty;
}

/// One scholar's documented classification of a hadith.
@immutable
class HadithGrading {
  const HadithGrading({
    required this.grade,
    required this.scholar,
    required this.sourceReference,
    this.label,
    this.sourceUrl,
    this.notes,
  });

  /// sahih, hasan, hasan_sahih, daif, daif_jiddan, mawdu or other.
  final String grade;

  /// Wording as the scholar gave it (Arabic), if recorded.
  final String? label;
  final String scholar;
  final String sourceReference;
  final String? sourceUrl;
  final String? notes;

  /// Somali display name for [grade]; [label] wins for "other".
  String get displayName => switch (grade) {
    'sahih' => 'Saxiix',
    'hasan' => 'Xasan',
    'hasan_sahih' => 'Xasan Saxiix',
    'daif' => 'Daciif',
    'daif_jiddan' => 'Daciif aad u ah',
    'mawdu' => 'Mawduuc (been abuur)',
    _ => label ?? grade,
  };
}

/// A recitation of a hadith (metadata only; the audio itself is streamed).
@immutable
class HadithAudio {
  const HadithAudio({
    required this.url,
    required this.reciter,
    required this.sourceName,
    required this.license,
    this.sourceUrl,
    this.duration,
    this.language = 'ar',
    this.verified = false,
  });

  /// Streaming URL (https). Loaded only when the user presses play.
  final Uri url;
  final String reciter;
  final String sourceName;
  final String? sourceUrl;

  /// Licence or written permission for streaming in the app.
  final String license;
  final Duration? duration;
  final String language;

  /// Checked by a reviewer against the Arabic text (source, completeness).
  final bool verified;
}
