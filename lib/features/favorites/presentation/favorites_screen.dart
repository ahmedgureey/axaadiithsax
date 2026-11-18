import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../hadith/hadith_actions.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    return Scaffold(
      appBar: AppTopBar(title: 'Kuwa la jecel yahay', leading: backOrHomeLeading(context)),
      body: ListenableBuilder(
        listenable: services.favorites,
        builder: (context, _) {
          // Skip IDs that no longer exist in the dataset.
          final items = [for (final id in services.favorites.ids) ?repo.hadithById(id)];
          if (items.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.bookmark_border_rounded,
              title: 'Weli wax ma keydsan',
              message: 'Riix calaamadda keydinta ee xadiis kasta si uu halkan u yimaado.',
              actionLabel: 'Baadh kutubta',
              onAction: () => context.go(AppRoutes.books),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => AppSpacing.gapSm,
            itemBuilder: (context, i) {
              final h = items[i];
              return AppPageBody(
                child: FavoriteHadithCard(
                  arabicText: h.arabicText,
                  somaliText: h.somaliText ?? missingTranslationText,
                  source: repo.bookById(h.bookId)?.nameSomali ?? '—',
                  isVerified: h.isVerified,
                  onTap: () => context.push(AppRoutes.hadith(h.id)),
                  onRemove: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Ka saar?',
                      message: 'Xadiiskan waa laga saarayaa kuwa la jecel yahay.',
                      confirmLabel: 'Ka saar',
                      isDestructive: true,
                    );
                    if (ok) await services.favorites.toggle(h.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
