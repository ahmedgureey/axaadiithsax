import 'package:flutter/foundation.dart';

/// Recently viewed hadith (in-memory, newest first).
class ReadingHistoryController extends ChangeNotifier {
  static const maxItems = 10;
  final List<String> _ids = [];

  List<String> get recentIds => List.unmodifiable(_ids);

  void record(String hadithId) {
    if (_ids.isNotEmpty && _ids.first == hadithId) return;
    _ids
      ..remove(hadithId)
      ..insert(0, hadithId);
    if (_ids.length > maxItems) _ids.removeLast();
    notifyListeners();
  }
}
