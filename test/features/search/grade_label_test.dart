import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/data/models/hadith.dart';
import 'package:xadiithapp/features/search/presentation/widgets/search_result_card.dart';

Hadith _h(List<HadithGrading> g) =>
    Hadith(id: 'x', bookId: 'b', chapterId: 'c', number: 1, arabicText: 'نص', gradings: g);

const _a = HadithGrading(grade: 'sahih', scholar: 'Scholar A', sourceReference: 'Ref A');
const _b = HadithGrading(grade: 'sahih', scholar: 'Scholar B', sourceReference: 'Ref B');
const _c = HadithGrading(grade: 'daif', scholar: 'Scholar C', sourceReference: 'Ref C');

void main() {
  test('no documented grading → no grade shown', () => expect(gradeLabel(_h(const [])), isNull));
  test('one grading shows grade and scholar', () => expect(gradeLabel(_h(const [_a])), 'Saxiix · Scholar A'));
  test('agreeing scholars show the grade', () => expect(gradeLabel(_h(const [_a, _b])), 'Saxiix'));
  test('differing scholars are never merged', () => expect(gradeLabel(_h(const [_a, _c])), 'Darajooyin kala duwan'));
}
