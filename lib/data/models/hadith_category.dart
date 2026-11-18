import 'package:flutter/foundation.dart';

/// Topic used to group hadith (Salaadda, Akhlaaqda, ...).
@immutable
class HadithCategory {
  const HadithCategory({
    required this.id,
    required this.nameSomali,
    required this.nameArabic,
    required this.iconKey,
    this.description = '',
  });

  final String id;
  final String nameSomali;
  final String nameArabic;

  /// UI maps this key to an icon (keeps models free of Flutter UI types).
  final String iconKey;

  /// Short Somali description of the topic (not a religious claim).
  final String description;
}
