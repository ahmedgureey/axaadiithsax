import 'package:flutter/foundation.dart';

/// A single hadith with Arabic text and Somali translation.
///
/// [grade] must only be displayed when [isVerified] is true. Demo content
/// always has `isVerified: false` and must show a demo badge.
@immutable
class Hadith {
  const Hadith({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.number,
    required this.arabicText,
    required this.somaliText,
    this.narrator,
    this.grade,
    this.reference,
    this.categoryIds = const [],
    this.isVerified = false,
  });

  final String id;
  final String bookId;
  final String chapterId;

  /// Position inside the chapter (not an official hadith number unless
  /// [isVerified]).
  final int number;
  final String arabicText;
  final String somaliText;
  final String? narrator;
  final String? grade;
  final String? reference;
  final List<String> categoryIds;
  final bool isVerified;
}
