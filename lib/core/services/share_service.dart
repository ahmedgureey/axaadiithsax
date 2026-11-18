import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

enum ShareOutcome {
  /// The system share sheet completed (or the platform cannot tell).
  shared,

  /// The user closed the share sheet.
  dismissed,

  /// Sharing is not available here — callers should fall back (e.g. copy).
  unavailable,
}

/// Abstraction over the platform share sheet so widgets stay testable.
abstract interface class ShareService {
  Future<ShareOutcome> shareText(String text, {String? subject});
}

/// Uses the native share sheet (Android / iOS) or the Web Share API.
class PlatformShareService implements ShareService {
  const PlatformShareService();

  @override
  Future<ShareOutcome> shareText(String text, {String? subject}) async {
    try {
      final result = await SharePlus.instance.share(ShareParams(text: text, subject: subject));
      return switch (result.status) {
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        ShareResultStatus.unavailable => ShareOutcome.unavailable,
        _ => ShareOutcome.shared,
      };
    } catch (error) {
      debugPrint('Share unavailable: $error');
      return ShareOutcome.unavailable;
    }
  }
}
