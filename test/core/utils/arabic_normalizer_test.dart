import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/utils/arabic_normalizer.dart';

String n(String s) => ArabicNormalizer.normalize(s);

void main() {
  group('Arabic', () {
    test('removes tashkeel, Quranic marks and tatweel', () {
      expect(n('الصَّلَاةُ'), n('الصلاة'));
      expect(n('الـــصلاة'), n('الصلاة'));
      expect(n('بِسْمِ'), 'بسم');
    });

    test('unifies alef forms, alef maqsura, hamza carriers and taa marbuta', () {
      expect(n('إيمان'), 'ايمان');
      expect(n('أحمد'), 'احمد');
      expect(n('آمن'), 'امن');
      expect(n('موسى'), 'موسي');
      expect(n('مؤمن'), 'مومن');
      expect(n('سائل'), 'سايل');
      expect(n('رحمة'), n('رحمه'));
    });

    test('maps Persian look-alikes and Arabic-Indic digits', () {
      expect(n('کتاب'), n('كتاب'));
      expect(n('علی'), n('علي'));
      expect(n('رقم ٣٢'), 'رقم 32');
      expect(n('۴'), '4');
    });

    test('does not change unrelated Arabic letters', () {
      expect(n('صبر'), isNot(n('سبر')));
      expect(n('ذكر'), isNot(n('زكر')));
    });
  });

  group('Somali / Latin', () {
    test('case-insensitive and whitespace-normalised', () {
      expect(n('  SALAADDA   Maanta '), 'salaadda maanta');
    });

    test('keeps distinct Somali letters distinct', () {
      expect(n('xasan'), isNot(n('hasan')));
      expect(n('cali'), isNot(n('ali')));
      expect(n('qalin'), isNot(n('galin')));
      expect(n('dhul'), isNot(n('dul')));
      expect(n('shan'), isNot(n('san')));
      expect(n('khayr'), isNot(n('kayr')));
    });

    test('unifies apostrophe variants (glottal stop)', () {
      expect(n('Nasaa’i'), n("Nasaa'i"));
      expect(n('Nasaa`i'), n("Nasaa'i"));
    });
  });

  test('tokens: empty / whitespace query has none', () {
    expect(ArabicNormalizer.tokens(''), isEmpty);
    expect(ArabicNormalizer.tokens('   '), isEmpty);
    expect(ArabicNormalizer.tokens(' Saxiix  Muslim '), ['saxiix', 'muslim']);
  });

  test('normalisation never mutates the input string', () {
    const original = 'الصَّلَاةُ';
    n(original);
    expect(original, 'الصَّلَاةُ');
  });
}
