import 'package:flutter/foundation.dart';

import 'quiz_models.dart';

/// State of one quiz run. Each question accepts exactly one answer; later
/// submissions for the same question are ignored, so the score can't be
/// corrupted by double taps or rebuilds.
class QuizSession extends ChangeNotifier {
  QuizSession(this.questions, {this.config = const QuizConfig(), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _startedAt = (clock ?? DateTime.now)();

  final List<QuizQuestion> questions;
  final QuizConfig config;
  final DateTime Function() _clock;
  final DateTime _startedAt;
  final Map<int, int> _answers = {};
  int _index = 0;

  int get index => _index;
  int get total => questions.length;
  QuizQuestion get current => questions[_index];
  bool get isLast => _index >= questions.length - 1;
  int? answerFor(int questionIndex) => _answers[questionIndex];
  bool get currentAnswered => _answers.containsKey(_index);
  bool get currentCorrect => _answers[_index] == current.correctIndex;
  int get correctSoFar => _answers.entries.where((e) => questions[e.key].correctIndex == e.value).length;

  /// Records the answer for the current question. Returns false if it was
  /// already answered or the option is out of range.
  bool submit(int option) {
    if (currentAnswered || option < 0 || option >= current.options.length) return false;
    _answers[_index] = option;
    notifyListeners();
    return true;
  }

  /// Moves on only after the current question is answered.
  bool next() {
    if (!currentAnswered || isLast) return false;
    _index++;
    notifyListeners();
    return true;
  }

  QuizResult finish() => QuizResult(
    questions: questions,
    answers: Map.unmodifiable(_answers),
    duration: _clock().difference(_startedAt),
    config: config,
  );
}
