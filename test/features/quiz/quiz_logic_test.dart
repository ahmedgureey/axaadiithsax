import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/data/models/chapter.dart';
import 'package:xadiithapp/data/models/hadith.dart';
import 'package:xadiithapp/data/models/hadith_book.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';
import 'package:xadiithapp/features/quiz/domain/quiz_generator.dart';
import 'package:xadiithapp/features/quiz/domain/quiz_models.dart';
import 'package:xadiithapp/features/quiz/domain/quiz_session.dart';

import '../../support/test_library.dart';

const _book = HadithBook(id: 'b', nameSomali: 'Kitaab', nameArabic: 'كتاب', author: 'A', description: '');
const _chapter = Chapter(id: 'b-c1', bookId: 'b', number: 1, titleSomali: 'C', titleArabic: 'ب');

void main() {
  final repo = testRepository();
  QuizGenerator gen([HadithRepository? r]) => QuizGenerator(r ?? repo, random: Random(7));

  group('Generator', () {
    test('builds the requested number of valid questions from real data', () {
      final build = gen().generate(const QuizConfig(questionCount: 10));
      expect(build.questions, hasLength(10));
      for (final q in build.questions) {
        final h = repo.hadithById(q.hadithId)!;
        expect(q.options.length, inInclusiveRange(2, QuizGenerator.maxOptions));
        expect(q.options.toSet().length, q.options.length, reason: 'options are distinct');
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
        switch (q.type) {
          case QuizQuestionType.meaning:
            fail('whole-translation questions are no longer used');
          case QuizQuestionType.book:
            expect(q.correctAnswer, repo.bookById(h.bookId)!.nameSomali);
          case QuizQuestionType.topic:
            expect(q.correctAnswer, repo.categoryById(h.categoryIds.first)!.nameSomali);
          case QuizQuestionType.narrator:
            fail('demo narrators are identical placeholders — no narrator question may be made');
          case QuizQuestionType.word ||
              QuizQuestionType.wordArabic ||
              QuizQuestionType.companion ||
              QuizQuestionType.collection ||
              QuizQuestionType.understanding ||
              QuizQuestionType.arabicUnderstanding ||
              QuizQuestionType.general:
            fail('test records have no study notes');
        }
        expect(q.explanation, contains('(xog tusaale ah)'));
      }
    });

    test('category filter only uses hadith from that topic', () {
      final build = gen().generate(const QuizConfig(categoryId: 'salah'));
      expect(build.isEmpty, isFalse);
      expect(build.questions.every((q) => repo.hadithById(q.hadithId)!.categoryIds.contains('salah')), isTrue);
    });

    test('favorites / memorized sources with nothing saved explain why', () {
      final fav = gen().generate(const QuizConfig(source: QuizSource.favorites));
      expect(fav.isEmpty, isTrue);
      expect(fav.problem, contains('kaydin'));
      final mem = gen().generate(const QuizConfig(source: QuizSource.memorized), memorizedIds: {'bukhari-c1-h1'});
      expect(mem.questions.every((q) => q.hadithId == 'bukhari-c1-h1'), isTrue);
    });

    test('empty topic → informative empty build', () {
      final build = gen().generate(const QuizConfig(categoryId: 'sawm'));
      expect(build.isEmpty, isTrue);
      expect(build.problem, isNotNull);
    });

    test('insufficient data (no distractors) → no invalid questions', () {
      const only = Hadith(id: 'x', bookId: 'b', chapterId: 'b-c1', number: 1, arabicText: 'نص', somaliText: 'T');
      final tiny = HadithRepository(books: [_book], chapters: [_chapter], hadiths: [only], categories: []);
      final build = gen(tiny).generate(const QuizConfig());
      expect(build.isEmpty, isTrue);
      expect(build.problem, contains('kuma filna'));
    });

    test('narrator questions appear only when distinct narrators exist', () {
      const a = Hadith(id: 'a', bookId: 'b', chapterId: 'b-c1', number: 1, arabicText: 'أ', narrator: 'عن فلان');
      const b = Hadith(id: 'b2', bookId: 'b', chapterId: 'b-c1', number: 2, arabicText: 'ب', narrator: 'عن علان');
      final r = HadithRepository(books: [_book], chapters: [_chapter], hadiths: [a, b], categories: []);
      final build = gen(r).generate(const QuizConfig(questionCount: 2));
      expect(build.questions.map((q) => q.type).toSet(), {QuizQuestionType.narrator});
      expect(build.questions.first.options.toSet(), {'عن فلان', 'عن علان'});
    });
  });

  group('Session and scoring', () {
    List<QuizQuestion> questions() => gen().generate(const QuizConfig(questionCount: 5)).questions;

    test('one answer per question; next requires an answer', () {
      final s = QuizSession(questions());
      expect(s.next(), isFalse);
      expect(s.submit(s.current.correctIndex), isTrue);
      expect(s.submit((s.current.correctIndex + 1) % s.current.options.length), isFalse, reason: 'locked');
      expect(s.correctSoFar, 1);
      expect(s.submit(99), isFalse);
      expect(s.next(), isTrue);
    });

    test('score is computed from submitted answers', () {
      var t = DateTime(2026, 1, 1, 10);
      final qs = questions();
      final s = QuizSession(qs, clock: () => t);
      for (var i = 0; i < qs.length; i++) {
        // Correct on even questions, wrong on odd ones.
        final q = s.current;
        s.submit(i.isEven ? q.correctIndex : (q.correctIndex + 1) % q.options.length);
        if (!s.isLast) s.next();
      }
      t = t.add(const Duration(seconds: 42));
      final r = s.finish();
      expect(r.total, 5);
      expect(r.correct, 3);
      expect(r.incorrect, 2);
      expect(r.percentage, 60);
      expect(r.incorrectIndexes, [1, 3]);
      expect(r.duration, const Duration(seconds: 42));
    });

    test('unanswered counts as wrong; zero questions → 0%', () {
      final qs = questions();
      final partial = QuizResult(questions: qs, answers: {0: qs[0].correctIndex});
      expect(partial.correct, 1);
      expect(partial.incorrect, 4);
      const empty = QuizResult(questions: [], answers: {});
      expect(empty.percentage, 0);
      expect(empty.total, 0);
    });
  });
}
