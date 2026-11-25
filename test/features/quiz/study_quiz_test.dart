import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/utils/arabic_normalizer.dart';
import 'package:xadiithapp/data/bundled/bundled_dataset.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';
import 'package:xadiithapp/features/quiz/domain/quiz_generator.dart';
import 'package:xadiithapp/features/quiz/domain/quiz_models.dart';
import 'package:xadiithapp/features/quiz/presentation/quiz_results_screen.dart';

/// Uses the REAL shipped assets (an-Nawawi + study notes).
HadithRepository _repo() {
  final data = BundledDataset.parse(jsonDecode(File(BundledDataset.asset).readAsStringSync()) as Map<String, dynamic>)!;
  final study = parseStudyNotes(jsonDecode(File(bundledStudyAsset).readAsStringSync()) as Map<String, dynamic>);
  return HadithRepository(
    books: [data.book],
    chapters: [data.chapter],
    hadiths: data.hadiths,
    categories: const [],
    studyNotes: study,
  );
}

void main() {
  final repo = _repo();

  test('study notes exist for all 42 hadith, and every Arabic word occurs in its hadith', () {
    for (final h in repo.allHadiths) {
      final notes = repo.studyOf(h.id);
      expect(notes, isNotNull, reason: h.id);
      expect(notes!.words, isNotEmpty, reason: h.id);
      final text = ArabicNormalizer.normalize(h.arabicText);
      for (final w in notes.words) {
        expect(text, contains(ArabicNormalizer.normalize(w.arabic)), reason: '${h.id}: ${w.arabic}');
        expect(RegExp(r'[؀-ۿ]').hasMatch(w.somali), isFalse, reason: 'Somali meaning has no Arabic');
      }
    }
  });

  test('the collection named in the notes matches Nawawi\'s attribution in the Arabic text', () {
    const names = {
      'Al-Bukhaari': 'البخاري',
      'Muslim': 'مسلم',
      'At-Tirmidi': 'الترمذي',
      'Ibnu Maajah': 'ابن ماجه',
      'Ad-Daaraqudni': 'الدارقطني',
      'Al-Bayhaqi': 'البيهقي',
      'Abuu Daawuud': 'أبو داود',
    };
    for (final h in repo.allHadiths) {
      final c = repo.studyOf(h.id)!.collection;
      if (c == null) continue;
      final text = ArabicNormalizer.normalize(h.arabicText);
      names.forEach((so, ar) {
        if (c.toLowerCase().contains(so.toLowerCase())) {
          expect(text, contains(ArabicNormalizer.normalize(ar)), reason: '${h.id}: $so');
        }
      });
    }
  });

  test('quiz uses word, companion, collection and understanding questions — not whole translations', () {
    final types = <QuizQuestionType>{};
    for (var seed = 0; seed < 8; seed++) {
      final build = QuizGenerator(repo, random: Random(seed)).generate(const QuizConfig(questionCount: 10));
      expect(build.questions, hasLength(10));
      for (final q in build.questions) {
        types.add(q.type);
        final notes = repo.studyOf(q.hadithId)!;
        expect(q.options.toSet().length, q.options.length);
        // Short questions: short context and short answers (never whole translations).
        expect(q.contextText == null || q.contextText!.length <= 132, isTrue, reason: q.contextText);
        expect(q.arabicExcerpt == null || q.arabicExcerpt!.length <= 115, isTrue, reason: q.arabicExcerpt);
        expect(q.options.every((o) => o.length <= 80), isTrue, reason: q.options.join(' | '));
        expect(q.type, isNot(QuizQuestionType.meaning));
        switch (q.type) {
          case QuizQuestionType.word:
            expect(notes.words.map((w) => w.somali), contains(q.correctAnswer));
            expect(notes.words.map((w) => w.arabic), contains(q.arabicExcerpt));
          case QuizQuestionType.wordArabic:
            expect(q.arabicOptions, isTrue);
            expect(notes.words.map((w) => w.arabic), contains(q.correctAnswer));
          case QuizQuestionType.arabicUnderstanding:
            expect(q.correctAnswer, notes.topic);
            expect(q.arabicExcerpt, isNotNull);
          case QuizQuestionType.general:
            expect(q.explanation, isNotEmpty);
          case QuizQuestionType.companion:
            expect(q.correctAnswer, notes.companion);
            expect(q.contextText, isNotNull);
          case QuizQuestionType.collection:
            expect(q.correctAnswer, notes.collection);
            expect(q.contextText!.contains('Waxaa wariyey'), isFalse, reason: 'answer not given away');
          case QuizQuestionType.understanding:
            expect(q.correctAnswer, notes.topic);
          default:
            fail('unexpected type ${q.type}');
        }
      }
    }
    expect(types, {
      QuizQuestionType.word,
      QuizQuestionType.wordArabic,
      QuizQuestionType.companion,
      QuizQuestionType.collection,
      QuizQuestionType.understanding,
      QuizQuestionType.arabicUnderstanding,
      QuizQuestionType.general,
    });
  });

  test('general questions: 2 in a 10-question quiz, correct facts', () {
    final build = QuizGenerator(repo, random: Random(1)).generate(const QuizConfig(questionCount: 10));
    final general = build.questions.where((q) => q.type == QuizQuestionType.general).toList();
    expect(general, hasLength(2));
    for (var seed = 0; seed < 20; seed++) {
      for (final q in QuizGenerator(
        repo,
        random: Random(seed),
      ).generate(const QuizConfig(questionCount: 10)).questions) {
        if (q.prompt == 'Tiirarka Islaamku waa imisa?') expect(q.correctAnswer, '5');
        if (q.prompt == 'Tiirarka Iimaanku waa imisa?') expect(q.correctAnswer, '6');
        if (q.prompt.contains('imisa xadiis')) expect(q.correctAnswer, '${repo.hadithCountOfBook('nawawi40')}');
      }
    }
  });

  test('Arabic excerpt skips the chain of narrators', () {
    final h = repo.hadithById('nawawi40-1')!;
    final excerpt = QuizGenerator.arabicMatn(h.arabicText)!;
    expect(excerpt.contains('أَمِيرِ الْمُؤْمِنِينَ'), isFalse);
    expect(excerpt.startsWith('إنَّمَا'), isTrue, reason: excerpt);
  });

  test('result message: most correct → Jazakallahu khairan', () {
    expect(QuizResultsScreen.messageFor(80), QuizResultsScreen.successMessage);
    expect(QuizResultsScreen.messageFor(60), QuizResultsScreen.successMessage);
    expect(QuizResultsScreen.messageFor(30), contains('Ha quusan'));
  });
}
