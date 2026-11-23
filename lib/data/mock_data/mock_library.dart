import '../models/chapter.dart';
import '../models/hadith.dart';
import '../models/hadith_book.dart';
import '../models/hadith_category.dart';

/// Local catalogue bundled with the app.
///
/// Contains ONLY the names of the well-known hadith collections and the topic
/// list used for browsing. The placeholder chapters and hadith records that
/// were used for UI development have been removed (2026-11-19): the app ships
/// with NO hadith until a verified dataset is added. Screens show empty states
/// in the meantime.
///
/// (The file/class keep their original name so imports stay unchanged. Test
/// fixtures live in `test/support/test_library.dart`.)
abstract final class MockLibrary {
  static const List<HadithBook> books = [
    HadithBook(
      id: 'bukhari',
      nameSomali: 'Saxiix al-Bukhaari',
      nameArabic: 'صَحِيحُ الْبُخَارِيِّ',
      author: 'Imaam al-Bukhaari',
      description: 'Mid ka mid ah kutubta xadiiska ee ugu caansan.',
    ),
    HadithBook(
      id: 'muslim',
      nameSomali: 'Saxiix Muslim',
      nameArabic: 'صَحِيحُ مُسْلِمٍ',
      author: 'Imaam Muslim',
      description: 'Mid ka mid ah kutubta xadiiska ee ugu caansan.',
    ),
    HadithBook(
      id: 'abudawud',
      nameSomali: 'Sunan Abii Daawuud',
      nameArabic: 'سُنَنُ أَبِي دَاوُدَ',
      author: 'Imaam Abu Daawuud',
      description: 'Mid ka mid ah kutubta Sunanka.',
    ),
    HadithBook(
      id: 'tirmidhi',
      nameSomali: 'Jaamic at-Tirmidi',
      nameArabic: 'جَامِعُ التِّرْمِذِيِّ',
      author: 'Imaam at-Tirmidi',
      description: 'Mid ka mid ah kutubta Sunanka.',
    ),
    HadithBook(
      id: 'nasai',
      nameSomali: 'Sunan an-Nasaa\'i',
      nameArabic: 'سُنَنُ النَّسَائِيِّ',
      author: 'Imaam an-Nasaa\'i',
      description: 'Mid ka mid ah kutubta Sunanka.',
    ),
    HadithBook(
      id: 'ibnmajah',
      nameSomali: 'Sunan Ibnu Maajah',
      nameArabic: 'سُنَنُ ابْنِ مَاجَهْ',
      author: 'Imaam Ibnu Maajah',
      description: 'Mid ka mid ah kutubta Sunanka.',
    ),
    HadithBook(
      id: 'nawawi40',
      nameSomali: 'Al-Arbaciin an-Nawawiyya',
      nameArabic: 'الْأَرْبَعُونَ النَّوَوِيَّةُ',
      author: 'Imaam an-Nawawi',
      description: 'Ururin caan ah oo loogu talagalay barashada iyo xifdinta.',
    ),
  ];

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
    HadithCategory(
      id: 'sawm',
      nameSomali: 'Soonka',
      nameArabic: 'الصيام',
      iconKey: 'crescent',
      description: 'Soonka iyo Ramadaan',
    ),
    HadithCategory(
      id: 'tawbah',
      nameSomali: 'Tawbad keenka',
      nameArabic: 'التوبة',
      iconKey: 'return',
      description: 'Ka toobad keenka iyo dambi dhaafka',
    ),
  ];

  /// No chapters yet — they arrive with a verified dataset.
  static const List<Chapter> chapters = [];

  /// No hadith yet — never add placeholder or unverified text here.
  static const List<Hadith> hadiths = [];
}
