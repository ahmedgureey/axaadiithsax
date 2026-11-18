import 'package:flutter/foundation.dart';

/// Where a record's content comes from.
enum SourceStatus {
  /// Placeholder content for UI development. Never shown as authentic.
  demo,

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

  bool get isVerified => sourceStatus == SourceStatus.verified;
  bool get hasTranslation => somaliText != null && somaliText!.trim().isNotEmpty;
}
