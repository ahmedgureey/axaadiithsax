import 'package:flutter/foundation.dart';

enum QuizQuestionType {
  meaning('Macnaha'),
  book('Kitaabka'),
  topic('Mowduuca'),
  narrator('Weriyaha');

  const QuizQuestionType(this.label);
  final String label;
}

/// Where quiz questions come from.
enum QuizSource {
  all('Dhammaan'),
  favorites('Kuwa la keydiyay'),
  memorized('Kuwa aan xifdiyey');

  const QuizSource(this.label);
  final String label;
}

@immutable
class QuizConfig {
  const QuizConfig({this.questionCount = 5, this.categoryId, this.source = QuizSource.all});

  static const countOptions = [5, 10];

  final int questionCount;
  final String? categoryId;
  final QuizSource source;
}

@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.type,
    required this.hadithId,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.arabicExcerpt,
  });

  final QuizQuestionType type;
  final String hadithId;
  final String prompt;

  /// Arabic text shown with the question (RTL), if any.
  final String? arabicExcerpt;
  final List<String> options;
  final int correctIndex;

  /// Built only from the record's own data.
  final String explanation;

  String get correctAnswer => options[correctIndex];
}

/// Result of generating a quiz: questions, or why none could be made.
@immutable
class QuizBuild {
  const QuizBuild(this.questions, {this.problem});

  final List<QuizQuestion> questions;

  /// Somali explanation when the data can't support a quiz.
  final String? problem;

  bool get isEmpty => questions.isEmpty;
}

/// Scored outcome, computed from submitted answers only.
@immutable
class QuizResult {
  const QuizResult({required this.questions, required this.answers, this.duration, this.config = const QuizConfig()});

  final List<QuizQuestion> questions;

  /// Selected option per question index (missing = unanswered = wrong).
  final Map<int, int> answers;
  final Duration? duration;
  final QuizConfig config;

  int get total => questions.length;
  int get correct => [
    for (var i = 0; i < questions.length; i++)
      if (answers[i] == questions[i].correctIndex) i,
  ].length;
  int get incorrect => total - correct;
  int get percentage => total == 0 ? 0 : (correct * 100 / total).round();

  List<int> get incorrectIndexes => [
    for (var i = 0; i < questions.length; i++)
      if (answers[i] != questions[i].correctIndex) i,
  ];
}
