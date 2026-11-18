import 'dart:math';

import '../../../data/models/hadith.dart';
import '../../../data/repositories/hadith_repository.dart';
import 'quiz_models.dart';

/// Builds multiple-choice questions strictly from data that exists.
///
/// A question type is only used for a hadith when the record has that field
/// AND at least one *different* value exists elsewhere to act as a
/// distractor. Example: every demo narrator is the same placeholder, so no
/// narrator questions are produced — instead of inventing names.
class QuizGenerator {
  QuizGenerator(this._repo, {Random? random}) : _random = random ?? Random();

  static const maxOptions = 4;

  final HadithRepository _repo;
  final Random _random;

  QuizBuild generate(QuizConfig config, {Set<String> favoriteIds = const {}, Set<String> memorizedIds = const {}}) {
    var pool = _repo.allHadiths.toList();
    if (config.categoryId != null) {
      pool = pool.where((h) => h.categoryIds.contains(config.categoryId)).toList();
    }
    pool = switch (config.source) {
      QuizSource.all => pool,
      QuizSource.favorites => pool.where((h) => favoriteIds.contains(h.id)).toList(),
      QuizSource.memorized => pool.where((h) => memorizedIds.contains(h.id)).toList(),
    };
    if (pool.isEmpty) {
      return QuizBuild(
        const [],
        problem: switch (config.source) {
          QuizSource.favorites => 'Weli ma kaydin xadiis ku habboon doorashadan.',
          QuizSource.memorized => 'Weli ma xifdin xadiis ku habboon doorashadan.',
          QuizSource.all => 'Mowduucan xadiis kuma jiro, sidaas darteed imtixaan lama samayn karo.',
        },
      );
    }

    pool.shuffle(_random);
    final questions = <QuizQuestion>[];
    final used = <String>{};
    // Round-robin over hadith and types for variety; stop at the target.
    for (var round = 0; round < QuizQuestionType.values.length && questions.length < config.questionCount; round++) {
      for (final h in pool) {
        if (questions.length >= config.questionCount) break;
        final types = [...QuizQuestionType.values]..shuffle(_random);
        for (final type in types) {
          final key = '${h.id}:${type.name}';
          if (used.contains(key)) continue;
          final q = _build(type, h);
          if (q != null) {
            used.add(key);
            questions.add(q);
            break;
          }
        }
      }
    }
    if (questions.isEmpty) {
      return const QuizBuild([], problem: 'Xogta la heli karo kuma filna su\'aalo sax ah.');
    }
    return QuizBuild(questions);
  }

  QuizQuestion? _build(QuizQuestionType type, Hadith h) => switch (type) {
    QuizQuestionType.meaning => _meaning(h),
    QuizQuestionType.book => _book(h),
    QuizQuestionType.topic => _topic(h),
    QuizQuestionType.narrator => _narrator(h),
  };

  String _ref(Hadith h) {
    final book = _repo.bookById(h.bookId)?.nameSomali ?? '';
    final demo = h.isVerified ? '' : ' (xog tusaale ah)';
    return '$book · ${_repo.referenceLabel(h)}$demo';
  }

  QuizQuestion? _meaning(Hadith h) {
    if (!h.hasTranslation) return null;
    final others = {
      for (final o in _repo.allHadiths)
        if (o.id != h.id && o.hasTranslation && o.somaliText != h.somaliText) o.somaliText!,
    }.toList();
    return _assemble(
      type: QuizQuestionType.meaning,
      hadith: h,
      prompt: 'Waa maxay macnaha Af-Soomaaliga ee xadiiskan?',
      arabic: h.arabicText,
      correct: h.somaliText!,
      distractors: others,
      explanation: 'Tarjumaadda ku jirta xogta xadiiskan waa jawaabta saxda ah. Tixraac: ${_ref(h)}.',
    );
  }

  QuizQuestion? _book(Hadith h) {
    final book = _repo.bookById(h.bookId);
    if (book == null) return null;
    final others = [
      for (final b in _repo.books)
        if (b.id != book.id && _repo.hadithCountOfBook(b.id) > 0) b.nameSomali,
    ];
    return _assemble(
      type: QuizQuestionType.book,
      hadith: h,
      prompt: 'Xadiiskan kee kitaab ayuu ku jiraa?',
      arabic: h.arabicText,
      correct: book.nameSomali,
      distractors: others,
      explanation: 'Xadiiskan wuxuu ku jiraa ${_ref(h)}.',
    );
  }

  QuizQuestion? _topic(Hadith h) {
    if (h.categoryIds.isEmpty) return null;
    final topic = _repo.categoryById(h.categoryIds.first);
    if (topic == null) return null;
    final others = [
      for (final c in _repo.categories)
        if (!h.categoryIds.contains(c.id) && _repo.hadithCountOfCategory(c.id) > 0) c.nameSomali,
    ];
    return _assemble(
      type: QuizQuestionType.topic,
      hadith: h,
      prompt: 'Xadiiskan mowduucee ayaa loogu calaamadeeyay app-ka?',
      arabic: h.arabicText,
      correct: topic.nameSomali,
      distractors: others,
      explanation: 'Xogta app-ka xadiiskan waxay u calaamadeysay mowduuca "${topic.nameSomali}". Tixraac: ${_ref(h)}.',
    );
  }

  QuizQuestion? _narrator(Hadith h) {
    final narrator = h.narrator;
    if (narrator == null) return null;
    final others = {
      for (final o in _repo.allHadiths)
        if (o.narrator != null && o.narrator != narrator) o.narrator!,
    }.toList();
    return _assemble(
      type: QuizQuestionType.narrator,
      hadith: h,
      prompt: 'Yaa weriyay xadiiskan?',
      arabic: h.arabicText,
      correct: narrator,
      distractors: others,
      explanation: 'Weriyaha ku qoran xogta xadiiskan waa: $narrator. Tixraac: ${_ref(h)}.',
    );
  }

  /// Needs at least one distinct distractor; otherwise the question is invalid.
  QuizQuestion? _assemble({
    required QuizQuestionType type,
    required Hadith hadith,
    required String prompt,
    required String arabic,
    required String correct,
    required List<String> distractors,
    required String explanation,
  }) {
    final unique = distractors.where((d) => d != correct).toSet().toList()..shuffle(_random);
    if (unique.isEmpty) return null;
    final options = [correct, ...unique.take(maxOptions - 1)]..shuffle(_random);
    return QuizQuestion(
      type: type,
      hadithId: hadith.id,
      prompt: prompt,
      arabicExcerpt: arabic,
      options: options,
      correctIndex: options.indexOf(correct),
      explanation: explanation,
    );
  }
}
