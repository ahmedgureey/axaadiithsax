import '../models/chapter.dart';
import '../models/hadith.dart';
import '../models/hadith_book.dart';
import '../models/hadith_category.dart';

/// Local demo dataset.
///
/// ⚠️ NO HADITH TEXT IN THIS FILE IS REAL. Every hadith entry is a clearly
/// marked placeholder (`isVerified: false`). Book names and authors are the
/// well-known titles of these collections; chapter titles, numbering and
/// topic assignments are demo structure only. Replace this file with a
/// verified dataset before release.
abstract final class MockLibrary {
  static const List<HadithBook> books = [
    HadithBook(
      id: 'bukhari',
      nameSomali: 'Saxiix al-Bukhaari',
      nameArabic: 'صحيح البخاري',
      author: 'Imaam al-Bukhaari',
      description:
          'Mid ka mid ah kutubta xadiiska ee ugu caansan. '
          'Xogta halkan ku jirta waa tusaale.',
    ),
    HadithBook(
      id: 'muslim',
      nameSomali: 'Saxiix Muslim',
      nameArabic: 'صحيح مسلم',
      author: 'Imaam Muslim',
      description:
          'Mid ka mid ah kutubta xadiiska ee ugu caansan. '
          'Xogta halkan ku jirta waa tusaale.',
    ),
    HadithBook(
      id: 'nawawi40',
      nameSomali: 'Al-Arbaciin an-Nawawiyya',
      nameArabic: 'الأربعون النووية',
      author: 'Imaam an-Nawawi',
      description:
          'Ururin caan ah oo loogu talagalay barashada iyo xifdinta. '
          'Xogta halkan ku jirta waa tusaale.',
    ),
  ];

  static const List<HadithCategory> categories = [
    HadithCategory(id: 'salah', nameSomali: 'Salaadda', nameArabic: 'الصلاة', iconKey: 'mosque'),
    HadithCategory(id: 'akhlaq', nameSomali: 'Akhlaaqda', nameArabic: 'الأخلاق', iconKey: 'heart'),
    HadithCategory(id: 'ilm', nameSomali: 'Cilmiga', nameArabic: 'العلم', iconKey: 'school'),
    HadithCategory(id: 'niyyah', nameSomali: 'Niyadda', nameArabic: 'النية', iconKey: 'spark'),
    HadithCategory(id: 'family', nameSomali: 'Qoyska', nameArabic: 'الأسرة', iconKey: 'family'),
  ];

  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static String _ar(int n) => n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

  static final List<Chapter> chapters = [
    for (final book in books)
      for (var c = 1; c <= 3; c++)
        Chapter(
          id: '${book.id}-c$c',
          bookId: book.id,
          number: c,
          titleSomali: 'Cutub tusaale $c',
          titleArabic: 'باب تجريبي ${_ar(c)}',
        ),
  ];

  static final List<Hadith> hadiths = () {
    final result = <Hadith>[];
    var serial = 0;
    for (final chapter in chapters) {
      for (var h = 1; h <= 3; h++) {
        serial++;
        result.add(
          Hadith(
            id: '${chapter.id}-h$h',
            bookId: chapter.bookId,
            chapterId: chapter.id,
            number: h,
            arabicText:
                'نص تجريبي رقم ${_ar(serial)}، يُستبدل بنص الحديث '
                'الموثّق من المصادر المعتمدة قبل نشر التطبيق',
            somaliText:
                'Qoraal tusaale ah (#$serial). Halkan waxaa geli doona '
                'tarjumaadda Af-Soomaaliga ee xadiis la xaqiijiyay.',
            narrator: 'اسم الراوي',
            categoryIds: [categories[serial % categories.length].id],
          ),
        );
      }
    }
    return List<Hadith>.unmodifiable(result);
  }();
}
