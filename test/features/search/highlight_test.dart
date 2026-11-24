import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/utils/arabic_normalizer.dart';
import 'package:xadiithapp/features/search/presentation/widgets/search_result_card.dart';

const _hl = TextStyle(fontWeight: FontWeight.w700);

List<String> _highlighted(String text, String query) => [
  for (final s in highlightSpans(text, ArabicNormalizer.tokens(query), _hl))
    if (s.style == _hl) s.text!,
];

void main() {
  test('Arabic: query without tashkeel highlights the vowelled word, text unchanged', () {
    const text = 'إنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ';
    expect(_highlighted(text, 'انما'), ['إنَّمَا']);
    expect(_highlighted(text, 'الاعمال'), ['الْأَعْمَالُ']);
    final all = highlightSpans(text, ArabicNormalizer.tokens('انما'), _hl).map((s) => s.text).join();
    expect(all, text, reason: 'original text is never changed');
  });

  test('Arabic letter variants (ة/ه, ى/ي) and every occurrence', () {
    expect(_highlighted('الصَّلاةُ عَلَى الهُدَى', 'الصلاه'), ['الصَّلاةُ']);
    expect(_highlighted('نص ونص', 'نص'), ['نص', 'نص']);
  });

  test('Somali: case-insensitive, several words', () {
    expect(_highlighted('Waxaan maqlay Rasuulka Allah', 'rasuulka allah'), ['Rasuulka', 'Allah']);
    expect(_highlighted('Xasan', 'hasan'), isEmpty, reason: 'x and h stay distinct');
  });

  test('no query → plain text', () {
    expect(highlightSpans('abc', const [], _hl).single.text, 'abc');
  });

  test('excerpt starts near a late match so it is visible', () {
    final text = '${'eray ' * 30}niyadda dhamaad';
    final ex = excerptAroundMatch(text, ArabicNormalizer.tokens('niyadda'));
    expect(ex.startsWith('… '), isTrue);
    expect(ex, contains('niyadda'));
    expect(excerptAroundMatch('niyadda hore', ArabicNormalizer.tokens('niyadda')), 'niyadda hore');
  });
}
