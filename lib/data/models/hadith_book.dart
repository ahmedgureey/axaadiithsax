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
    this.isSourced = false,
  });

  final String id;
  final String nameSomali;
  final String nameArabic;
  final String author;
  final String description;

  /// True only when the book metadata (counts, description) has been checked
  /// against a reliable source.
  final bool isVerified;

  /// Real content from a documented source bundled with the app.
  final bool isSourced;

  /// Placeholder content (shown with a "Tusaale" badge).
  bool get isDemo => !isVerified && !isSourced;
}
