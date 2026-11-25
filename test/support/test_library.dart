import 'package:xadiithapp/core/audio/audio_engine.dart';
import 'package:xadiithapp/core/notifications/notification_gateway.dart';
import 'package:xadiithapp/core/update/update_checker.dart';
import 'package:xadiithapp/app/app_services.dart';
import 'package:xadiithapp/core/services/share_service.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/data/mock_data/mock_library.dart';
import 'package:xadiithapp/data/models/chapter.dart';
import 'package:xadiithapp/data/models/hadith.dart';
import 'package:xadiithapp/data/models/hadith_category.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';

/// TEST-ONLY fixture. Not part of the app.
///
/// The placeholder dataset that used to ship in `lib/data/mock_data` was moved
/// here (2026-11-19) so widget/unit tests keep exercising non-empty states.
/// NONE of this text is a hadith: every record is a clearly marked placeholder
/// (`SourceStatus.demo`).
abstract final class TestLibrary {
  /// Books that have placeholder chapters and records in this fixture.
  static const _booksWithContent = {'bukhari', 'muslim', 'nawawi40'};

  /// Placeholder records are spread over the first eight topics only.
  static List<HadithCategory> get _assignedCategories => MockLibrary.categories.take(8).toList();

  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static String _ar(int n) => n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

  static final List<Chapter> chapters = [
    for (final book in MockLibrary.books)
      if (_booksWithContent.contains(book.id))
        for (var c = 1; c <= 3; c++)
          Chapter(
            id: '${book.id}-c$c',
            bookId: book.id,
            number: c,
            titleSomali: 'Cutub tusaale $c',
            titleArabic: 'باب تجريبي ${_ar(c)}',
          ),
  ];

  static const demoSource = 'Xog tusaale ah oo loo sameeyay horumarinta app-ka — ma aha qoraal xadiis.';

  /// Chapter whose last record has no translation / narrator (tests the
  /// missing-content states).
  static const incompleteChapterId = 'nawawi40-c3';

  static final List<Hadith> hadiths = () {
    final result = <Hadith>[];
    var serial = 0;
    for (final chapter in chapters) {
      for (var h = 1; h <= 3; h++) {
        serial++;
        final incomplete = chapter.id == incompleteChapterId && h == 3;
        result.add(
          Hadith(
            id: '${chapter.id}-h$h',
            bookId: chapter.bookId,
            chapterId: chapter.id,
            number: h,
            arabicText:
                'نص تجريبي رقم ${_ar(serial)}، يُستبدل بنص الحديث '
                'الموثّق من المصادر المعتمدة قبل نشر التطبيق',
            somaliText: incomplete
                ? null
                : 'Qoraal tusaale ah (#$serial). Halkan waxaa geli doona '
                      'tarjumaadda Af-Soomaaliga ee xadiis la xaqiijiyay.',
            narrator: incomplete ? null : 'اسم الراوي',
            categoryIds: [_assignedCategories[serial % _assignedCategories.length].id],
            source: demoSource,
          ),
        );
      }
    }
    return List<Hadith>.unmodifiable(result);
  }();
}

/// Repository over the real catalogue (books, topics) plus the test-only
/// placeholder records.
HadithRepository testRepository() => HadithRepository(chapters: TestLibrary.chapters, hadiths: TestLibrary.hadiths);

/// `AppServices.create` backed by [testRepository] unless a repository is
/// given (the app itself ships without hadith records).
Future<AppServices> createTestServices(
  SettingsStore store, {
  HadithRepository? repository,
  ShareService? share,
  AudioEngineFactory? audioEngineFactory,
  NotificationGateway? notificationGateway,
  UpdateChecker? updateChecker,
  DateTime Function()? clock,
}) => AppServices.create(
  store,
  repository: repository ?? testRepository(),
  share: share,
  clock: clock,
  audioEngineFactory: audioEngineFactory,
  notificationGateway: notificationGateway,
  updateChecker: updateChecker,
);
