import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/widgets/widgets.dart';

/// Toggles a bookmark through the shared controller and confirms with a
/// short message. Removing offers "Celi" (undo).
Future<bool> toggleFavoriteWithFeedback(BuildContext context, String hadithId) async {
  final favorites = context.services.favorites;
  final added = await favorites.toggle(hadithId);
  if (!context.mounted) return added;
  if (added) {
    AppSnackbar.show(context, 'Waa la keydiyay', type: AppSnackType.success);
  } else {
    AppSnackbar.show(
      context,
      'Waa laga saaray kuwa la keydiyay',
      actionLabel: 'Celi',
      onAction: () => favorites.add(hadithId),
    );
  }
  return added;
}
