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
    // The four Sunan collections are listed so users can browse them, but no
    // content has been added yet — the UI shows "weli lama darin".
    HadithBook(
      id: 'abudawud',
      nameSomali: 'Sunan Abi Daawuud',
      nameArabic: 'سنن أبي داود',
      author: 'Imaam Abu Daawuud',
      description: 'Mid ka mid ah kutubta Sunanka. Noocan tijaabada ah weli xadiis lagu ma darin.',
    ),
    HadithBook(
      id: 'tirmidhi',
      nameSomali: 'Jaamic at-Tirmidhi',
      nameArabic: 'جامع الترمذي',
      author: 'Imaam at-Tirmidhi',
      description: 'Mid ka mid ah kutubta Sunanka. Noocan tijaabada ah weli xadiis lagu ma darin.',
    ),
    HadithBook(
      id: 'nasai',
      nameSomali: 'Sunan an-Nasaa\'i',
      nameArabic: 'سنن النسائي',
      author: 'Imaam an-Nasaa\'i',
      description: 'Mid ka mid ah kutubta Sunanka. Noocan tijaabada ah weli xadiis lagu ma darin.',
    ),
    HadithBook(
      id: 'ibnmajah',
      nameSomali: 'Sunan Ibn Maajah',
      nameArabic: 'سنن ابن ماجه',
      author: 'Imaam Ibn Maajah',
      description: 'Mid ka mid ah kutubta Sunanka. Noocan tijaabada ah weli xadiis lagu ma darin.',
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

  /// Books that have (demo) chapters and hadith in this dataset.
  static const _booksWithContent = {'bukhari', 'muslim', 'nawawi40'};

  static const List<HadithCategory> categories = [
    HadithCategory(
      id: 'iman',
      nameSomali: 'Iimaanka',
      nameArabic: 'الإيمان',
      iconKey: 'spark',
      description: 'Rukummada iimaanka',
    ),
    HadithCategory(
      id: 'salah',
      nameSomali: 'Salaadda',
      nameArabic: 'الصلاة',
      iconKey: 'mosque',
      description: 'Tukashada iyo waqtiyadeeda',
    ),
    HadithCategory(
      id: 'akhlaq',
      nameSomali: 'Akhlaaqda',
      nameArabic: 'الأخلاق',
      iconKey: 'heart',
      description: 'Dabeecadda wanaagsan',
    ),
    HadithCategory(
      id: 'sabr',
      nameSomali: 'Dulqaadka',
      nameArabic: 'الصبر',
      iconKey: 'hourglass',
      description: 'Samirka iyo adkaysiga',
    ),
    HadithCategory(
      id: 'parents',
      nameSomali: 'Waalidka',
      nameArabic: 'بر الوالدين',
      iconKey: 'family',
      description: 'U wanaagsanaanta waalidka',
    ),
    HadithCategory(
      id: 'sadaqah',
      nameSomali: 'Sadaqada',
      nameArabic: 'الصدقة',
      iconKey: 'giving',
      description: 'Bixinta iyo deeqda',
    ),
    HadithCategory(
      id: 'ilm',
      nameSomali: 'Cilmiga',
      nameArabic: 'العلم',
      iconKey: 'school',
      description: 'Barashada iyo aqoonta',
    ),
    HadithCategory(
      id: 'dua',
      nameSomali: 'Ducada',
      nameArabic: 'الدعاء',
      iconKey: 'night',
      description: 'Baryada Alle',
    ),
  ];

  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static String _ar(int n) => n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

  static final List<Chapter> chapters = [
    for (final book in books)
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

  /// Chapter whose last record has no translation / narrator (demo of
  /// missing-content states).
  static const incompleteChapterId = 'nawawi40-c3';

  static final List<Hadith> hadiths = () {
    final result = <Hadith>[];
    var serial = 0;
    for (final chapter in chapters) {
      for (var h = 1; h <= 3; h++) {
        serial++;
        // One record deliberately lacks translation and narrator so the
        // "lama hayo" states are visible and testable.
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
            categoryIds: [categories[serial % categories.length].id],
            source: demoSource,
          ),
        );
      }
    }
    return List<Hadith>.unmodifiable(result);
  }();
}
