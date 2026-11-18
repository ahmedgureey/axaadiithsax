import 'package:flutter/material.dart';

import '../../../../app/app_services.dart';
import '../../../../core/widgets/widgets.dart';
import '../../favorite_actions.dart';

/// Bookmark toggle bound to the shared favourites controller, so its state is
/// identical on every screen. Filled = saved, outline = not saved.
class HadithBookmarkButton extends StatelessWidget {
  const HadithBookmarkButton({super.key, required this.hadithId, this.color});

  final String hadithId;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final favorites = context.services.favorites;
    return ListenableBuilder(
      listenable: favorites,
      builder: (context, _) {
        final saved = favorites.isFavorite(hadithId);
        return IconActionButton(
          icon: Icons.bookmark_border_rounded,
          selectedIcon: Icons.bookmark_rounded,
          isSelected: saved,
          color: color,
          tooltip: saved ? 'Ka saar kuwa la jecel yahay' : 'Ku dar kuwa la jecel yahay',
          onPressed: () => toggleFavoriteWithFeedback(context, hadithId),
        );
      },
    );
  }
}
