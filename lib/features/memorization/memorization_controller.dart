import 'package:flutter/foundation.dart';

/// Memorisation plan progress. In-memory for this phase (Phase 9 adds
/// persistence, schedules and revision).
class MemorizationController extends ChangeNotifier {
  MemorizationController({required List<String> planHadithIds}) : _planIds = List.unmodifiable(planHadithIds);

  final List<String> _planIds;
  final Set<String> _memorized = {};

  List<String> get planHadithIds => _planIds;
  int get memorizedCount => _planIds.where(_memorized.contains).length;
  int get total => _planIds.length;
  bool isMemorized(String hadithId) => _memorized.contains(hadithId);

  /// First plan item not yet memorised, or null when the plan is complete.
  String? get nextHadithId {
    for (final id in _planIds) {
      if (!_memorized.contains(id)) return id;
    }
    return null;
  }

  void toggleMemorized(String hadithId) {
    _memorized.contains(hadithId) ? _memorized.remove(hadithId) : _memorized.add(hadithId);
    notifyListeners();
  }
}
