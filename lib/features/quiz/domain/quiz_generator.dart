import 'dart:math';

import '../../../data/models/hadith.dart';
import '../../../data/models/study_notes.dart';
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
  static const _studyTypes = [
    QuizQuestionType.word,
    QuizQuestionType.wordArabic,
    QuizQuestionType.companion,
    QuizQuestionType.collection,
    QuizQuestionType.understanding,
    QuizQuestionType.arabicUnderstanding,
  ];
  static const _dataTypes = [QuizQuestionType.book, QuizQuestionType.topic, QuizQuestionType.narrator];

  /// Hadith with study notes get word / companion / collection /
  /// understanding questions; others the questions their data supports.
  List<QuizQuestionType> _typesFor(Hadith h) => _repo.studyOf(h.id) != null ? _studyTypes : _dataTypes;

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
    // A few general questions in a full quiz (1 in 5), when available.
    final general = config.source == QuizSource.all && config.categoryId == null
        ? (_generalQuestions()..shuffle(_random)).take(config.questionCount ~/ 5).toList()
        : const <QuizQuestion>[];
    final target = config.questionCount - general.length;
    final questions = <QuizQuestion>[];
    final used = <String>{};
    // Round-robin over hadith and types for variety; stop at the target.
    for (var round = 0; round < _studyTypes.length && questions.length < target; round++) {
      for (final h in pool) {
        if (questions.length >= target) break;
        final types = [..._typesFor(h)]..shuffle(_random);
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
    for (final g in general) {
      questions.insert(_random.nextInt(questions.length + 1), g);
    }
    return QuizBuild(questions);
  }

  QuizQuestion? _build(QuizQuestionType type, Hadith h) => switch (type) {
    QuizQuestionType.meaning => _meaning(h),
    QuizQuestionType.book => _book(h),
    QuizQuestionType.topic => _topic(h),
    QuizQuestionType.narrator => _narrator(h),
    QuizQuestionType.word => _word(h),
    QuizQuestionType.wordArabic => _wordArabic(h),
    QuizQuestionType.companion => _companion(h),
    QuizQuestionType.collection => _collection(h),
    QuizQuestionType.understanding => _understanding(h),
    QuizQuestionType.arabicUnderstanding => _arabicUnderstanding(h),
    QuizQuestionType.general => null,
  };

  String _ref(Hadith h) {
    final book = _repo.bookById(h.bookId)?.nameSomali ?? '';
    final demo = h.isDemo ? ' (xog tusaale ah)' : '';
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
      arabicOptions: true,
    );
  }

  // ---- study-note questions -------------------------------------------------

  /// The Prophet's words from the Somali translation: from the first quote to
  /// before the attribution ("Waxaa wariyey …", "Xadiis xasan …"), so the
  /// narrator and collection are not given away.
  String? _matn(Hadith h) {
    final s = h.somaliText;
    if (s == null || s.trim().isEmpty) return null;
    var start = s.indexOf('"');
    if (start < 0) start = 0;
    var end = s.length;
    for (final marker in ['[Waxaa wariyey', 'Waxaa wariyey', 'Xadiis xasan', 'Riwaayad']) {
      final at = s.indexOf(marker, start + 1);
      if (at > start && at < end) end = at;
    }
    var text = s.substring(start, end).trim();
    text = _short(text);
    return text.isEmpty ? null : text;
  }

  /// Keeps questions short: the first sentence (or ~130 characters, cut at a
  /// word boundary).
  static String _short(String text, {int max = 130}) {
    final sentence = RegExp(r'^.{20,}?[.?!](?=\s|"|$)').firstMatch(text)?.group(0);
    var s = sentence ?? text;
    if (s.length > max) {
      final cut = s.lastIndexOf(' ', max);
      s = '${s.substring(0, cut > 40 ? cut : max).trimRight()}…';
    }
    if (s.startsWith('"') && !s.substring(1).contains('"')) s = s.substring(1);
    return s.trim();
  }

  QuizQuestion? _word(Hadith h) {
    final notes = _repo.studyOf(h.id);
    if (notes == null || notes.words.isEmpty) return null;
    final word = notes.words[_random.nextInt(notes.words.length)];
    final answer = word.somali.toLowerCase();
    final others = {
      for (final o in _repo.allHadiths)
        for (final w in _repo.studyOf(o.id)?.words ?? const <StudyWord>[])
          // Avoid near-identical distractors (e.g. "xumaan" vs "xumaanta").
          if (!w.somali.toLowerCase().contains(answer) && !answer.contains(w.somali.toLowerCase())) w.somali,
    }.toList();
    return _assemble(
      type: QuizQuestionType.word,
      hadith: h,
      prompt: 'Erayga Carabiga ah, Soomaali maxaa lagu wadaa?',
      arabic: word.arabic,
      correct: word.somali,
      distractors: others,
      explanation: '«${word.arabic}» macnihiisu waa «${word.somali}». Tixraac: ${_ref(h)}.',
    );
  }

  QuizQuestion? _companion(Hadith h) {
    final notes = _repo.studyOf(h.id);
    if (notes == null) return null;
    final others = {
      for (final o in _repo.allHadiths)
        if (_repo.studyOf(o.id)?.companion case final c? when c != notes.companion) c,
    }.toList();
    return _assemble(
      type: QuizQuestionType.companion,
      hadith: h,
      prompt: 'Yaa xadiiskan ka weriyey Nabiga (NNKH)?',
      context: _matn(h),
      correct: notes.companion,
      distractors: others,
      explanation: 'Xadiiskan waxaa ka weriyey ${notes.companion}. Tixraac: ${_ref(h)}.',
    );
  }

  QuizQuestion? _collection(Hadith h) {
    final collection = _repo.studyOf(h.id)?.collection;
    if (collection == null) return null;
    final others = {
      for (final o in _repo.allHadiths)
        if (_repo.studyOf(o.id)?.collection case final c? when c != collection) c,
    }.toList();
    return _assemble(
      type: QuizQuestionType.collection,
      hadith: h,
      prompt: 'Xadiiskan yaa wariyey (rawaahu)?',
      context: _matn(h),
      correct: collection,
      distractors: others,
      explanation: 'Xadiiskan waxaa wariyey: $collection. Tixraac: ${_ref(h)}.',
    );
  }

  QuizQuestion? _understanding(Hadith h) {
    final notes = _repo.studyOf(h.id);
    final matn = _matn(h);
    if (notes == null || matn == null) return null;
    final others = {
      for (final o in _repo.allHadiths)
        if (_repo.studyOf(o.id)?.topic case final t? when t != notes.topic) t,
    }.toList();
    return _assemble(
      type: QuizQuestionType.understanding,
      hadith: h,
      prompt: 'Macnaha guud, muxuu xadiisku ka hadlayaa?',
      context: matn,
      correct: notes.topic,
      distractors: others,
      explanation: 'Mowduuca xadiiskan: ${notes.topic}. Tixraac: ${_ref(h)}.',
    );
  }

  /// Somali meaning → which Arabic word?
  QuizQuestion? _wordArabic(Hadith h) {
    final notes = _repo.studyOf(h.id);
    if (notes == null || notes.words.isEmpty) return null;
    final word = notes.words[_random.nextInt(notes.words.length)];
    final others = {
      for (final o in _repo.allHadiths)
        for (final w in _repo.studyOf(o.id)?.words ?? const <StudyWord>[])
          if (w.arabic != word.arabic && w.somali.toLowerCase() != word.somali.toLowerCase()) w.arabic,
    }.toList();
    return _assemble(
      type: QuizQuestionType.wordArabic,
      hadith: h,
      prompt: '«${word.somali}» — Carabigiisa maxaa lagu wadaa?',
      correct: word.arabic,
      distractors: others,
      arabicOptions: true,
      explanation: '«${word.somali}» Carabigiisu waa «${word.arabic}». Tixraac: ${_ref(h)}.',
    );
  }

  /// The hadith's Arabic words (without the chain) → its general subject.
  QuizQuestion? _arabicUnderstanding(Hadith h) {
    final notes = _repo.studyOf(h.id);
    final arabic = arabicMatn(h.arabicText);
    if (notes == null || arabic == null) return null;
    final others = {
      for (final o in _repo.allHadiths)
        if (_repo.studyOf(o.id)?.topic case final t? when t != notes.topic) t,
    }.toList();
    return _assemble(
      type: QuizQuestionType.arabicUnderstanding,
      hadith: h,
      prompt: 'Qoraalkan Carabiga ah, macnaha guud muxuu ka hadlayaa?',
      arabic: arabic,
      correct: notes.topic,
      distractors: others,
      explanation: 'Mowduuca xadiiskan: ${notes.topic}. Tixraac: ${_ref(h)}.',
    );
  }

  /// The Prophet's words from the Arabic text: after "صلى الله عليه وسلم …:"
  /// (skipping the chain of narrators), cut to ~110 characters at a word.
  static String? arabicMatn(String text, {int max = 110}) {
    var start = 0;
    final salla = text.indexOf('صلى الله عليه');
    if (salla >= 0) {
      final colon = text.indexOf(':', salla);
      if (colon > 0 && colon - salla < 40) start = colon + 1;
    }
    var s = text.substring(start).replaceAll(RegExp('^[\\s"«“]+'), '').trim();
    if (s.length < 15) return null;
    if (s.length > max) {
      final cut = s.lastIndexOf(' ', max);
      s = '${s.substring(0, cut > 40 ? cut : max).trimRight()} …';
    }
    return s;
  }

  // ---- general questions ----------------------------------------------------

  /// Well-known facts around the bundled collection. Each is attached to the
  /// hadith it comes from and only used when that hadith exists.
  List<QuizQuestion> _generalQuestions() {
    final out = <QuizQuestion>[];
    void add(String hadithId, String prompt, String correct, List<String> wrong, String explanation) {
      final h = _repo.hadithById(hadithId);
      if (h == null || _repo.studyOf(h.id) == null) return;
      final q = _assemble(
        type: QuizQuestionType.general,
        hadith: h,
        prompt: prompt,
        correct: correct,
        distractors: wrong,
        explanation: explanation,
      );
      if (q != null) out.add(q);
    }

    final book = _repo.bookById('nawawi40');
    if (book != null) {
      final count = _repo.hadithCountOfBook(book.id);
      add('nawawi40-1', 'Kitaabka «${book.nameSomali}» yaa ururiyey?', book.author, const [
        'Imaam al-Bukhaari',
        'Imaam Muslim',
        'Imaam Maalik',
      ], '«${book.nameSomali}» waxaa ururiyey ${book.author}.');
      if (count > 0) {
        add('nawawi40-1', '«${book.nameSomali}» imisa xadiis ayuu ka kooban yahay?', '$count', [
          for (final n in const [30, 40, 45, 50])
            if (n != count) '$n',
        ], 'Magaciisu waa «Afartanka», laakiin wuxuu ka kooban yahay $count xadiis.');
      }
    }
    add('nawawi40-3', 'Tiirarka Islaamku waa imisa?', '5', const [
      '3',
      '6',
      '7',
    ], 'Islaamka waxaa lagu dhisay shan tiir (Xadiiska 3).');
    add('nawawi40-2', 'Tiirarka Iimaanku waa imisa?', '6', const [
      '4',
      '5',
      '7',
    ], 'Iimaanku waa lix: Allah, malaa\'igta, kutubta, rusulka, maalinta aakhiro iyo qadarka (Xadiiska 2).');
    add('nawawi40-1', 'Labada «Saxiix» (Saxiixayn) waa kuwee?', 'Al-Bukhaari iyo Muslim', const [
      'Abuu Daawuud iyo at-Tirmidhi',
      'An-Nasaa\'i iyo Ibnu Maajah',
      'Maalik iyo Axmad',
    ], 'Saxiixayn waa Saxiix al-Bukhaari iyo Saxiix Muslim (Xadiiska 1).');
    return out;
  }

  /// Needs at least one distinct distractor; otherwise the question is invalid.
  QuizQuestion? _assemble({
    required QuizQuestionType type,
    required Hadith hadith,
    required String prompt,
    String? arabic,
    String? context,
    bool arabicOptions = false,
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
      contextText: context,
      arabicOptions: arabicOptions,
      options: options,
      correctIndex: options.indexOf(correct),
      explanation: explanation,
    );
  }
}
