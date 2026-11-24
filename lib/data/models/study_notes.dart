import 'package:flutter/foundation.dart';

/// An Arabic word from a hadith with its Somali meaning.
@immutable
class StudyWord {
  const StudyWord({required this.arabic, required this.somali});

  final String arabic;
  final String somali;
}

/// Study/quiz notes for one hadith (kept apart from the hadith text).
@immutable
class StudyNotes {
  const StudyNotes({required this.companion, required this.topic, this.collection, this.words = const []});

  /// Companion who narrated it from the Prophet ﷺ (as named in the isnad).
  final String companion;

  /// Who recorded it ("Muslim", "Al-Bukhaari iyo Muslim" …); null when the
  /// attribution is mixed or unclear.
  final String? collection;

  /// Short summary of the subject (general understanding).
  final String topic;
  final List<StudyWord> words;
}
