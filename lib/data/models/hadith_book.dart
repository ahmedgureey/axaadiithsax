import 'package:flutter/foundation.dart';

/// A hadith collection (e.g. Saxiix al-Bukhaari).
@immutable
class HadithBook {
  const HadithBook({
    required this.id,
    required this.nameSomali,
    required this.nameArabic,
    required this.author,
    required this.description,
    this.isVerified = false,
  });

  final String id;
  final String nameSomali;
  final String nameArabic;
  final String author;
  final String description;

  /// True only when the book metadata (counts, description) has been checked
  /// against a reliable source.
  final bool isVerified;
}
