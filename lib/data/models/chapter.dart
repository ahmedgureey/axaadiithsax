import 'package:flutter/foundation.dart';

/// A chapter (kitaab / baab) inside a [HadithBook].
@immutable
class Chapter {
  const Chapter({
    required this.id,
    required this.bookId,
    required this.number,
    required this.titleSomali,
    required this.titleArabic,
  });

  final String id;
  final String bookId;
  final int number;
  final String titleSomali;
  final String titleArabic;
}
