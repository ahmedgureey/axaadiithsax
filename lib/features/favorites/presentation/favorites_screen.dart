import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/remote/catalog_api.dart';
import '../favorites_controller.dart';
import '../../../data/models/hadith.dart';
import '../../hadith/hadith_actions.dart';
import 'widgets/favorites_empty_state.dart';

enum FavoritesSort {
  recent('Kuwii ugu dambeeyay'),
  book('Magaca kitaabka');

  const FavoritesSort(this.label);
  final String label;
}

/// "Xadiisyada aan Kaydiyey" — reads the shared favourites controller.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  static const title = 'Xadiisyada aan Kaydiyey';

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  FavoritesSort _sort = FavoritesSort.recent;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final favorites = services.favorites;
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleFavorites), leading: backOrHomeLeading(context)),
      body: ListenableBuilder(
        listenable: favorites,
        builder: (context, _) {
          if (!favorites.isLoaded) return const LoadingIndicator(message: 'Waa la soo rarayaa…');
          if (favorites.loadFailed) {
            return ErrorStateWidget(
              title: 'Kuwa la keydiyay lama soo rari karin',
              message: 'Kaydka qalabka lama akhrin karin. Fadlan isku day mar kale.',
              onRetry: favorites.load,
            );
          }
          // Backend: download saved records first, so "missing" is never a
          // network problem in disguise.
          return EnsureHadiths(
            ids: favorites.ids,
            builder: (context, loading, failure, retry) => _list(context, favorites, loading, failure, retry),
          );
        },
      ),
    );
  }

  Widget _list(
    BuildContext context,
    FavoritesController favorites,
    bool loading,
    CatalogFailure? failure,
    VoidCallback retry,
  ) {
    final repo = context.services.repository;
    // Saved IDs that no longer exist in the dataset are skipped.
    final items = [for (final id in favorites.ids) ?repo.hadithById(id)];
    final missing = favorites.count - items.length;
    if (items.isEmpty && missing == 0) return const FavoritesEmptyState();
    if (loading && missing > 0) return const LoadingIndicator(message: 'Kuwa la keydiyay waa la soo rarayaa…');
    if (failure != null && items.isEmpty) {
      return ErrorStateWidget(title: 'Kuwa la keydiyay lama soo rari karin', message: failure.message, onRetry: retry);
    }

    final sorted = switch (_sort) {
      FavoritesSort.recent => items,
      FavoritesSort.book =>
        [...items]..sort((a, b) {
          // Case-insensitive, like the search screen's book sort.
          final c = ArabicNormalizer.normalize(repo.bookById(a.bookId)?.nameSomali ?? '')
              .compareTo(ArabicNormalizer.normalize(repo.bookById(b.bookId)?.nameSomali ?? ''));
          return c != 0 ? c : items.indexOf(a).compareTo(items.indexOf(b));
        }),
    };

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: sorted.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          // Unknown while downloading or after a failed download: only
          // offer "remove missing" when the records truly don't exist.
          return _Header(
            count: items.length,
            missing: failure == null && !loading ? missing : 0,
            sort: _sort,
            onSort: _setSort,
          );
        }
        final h = sorted[i - 1];
        return AppPageBody(
          key: ValueKey(h.id),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: _FavoriteTile(hadith: h),
        );
      },
    );
  }

  void _setSort(FavoritesSort s) => setState(() => _sort = s);
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.missing, required this.sort, required this.onSort});

  final int count;
  final int missing;
  final FavoritesSort sort;
  final ValueChanged<FavoritesSort> onSort;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    return AppPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text('$count xadiis ayaa la keydiyay', style: context.textStyles.titleMedium),
          ),
          AppSpacing.gapXs,
          const Align(
            alignment: Alignment.centerLeft,
            child: OfflineStatusIndicator(status: OfflineAvailability.savedOnDevice),
          ),
          if (missing > 0) ...[
            AppSpacing.gapSm,
            FormValidationMessage(
              type: FormMessageType.info,
              message: '$missing xadiis oo la keydiyay hadda kuma jiraan xogta app-ka.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AppTextButton(
                label: 'Ka saar kuwa maqan',
                onPressed: () => services.favorites.removeMissing((id) => services.repository.hadithById(id) != null),
              ),
            ),
          ],
          if (count > 1) ...[
            AppSpacing.gapSm,
            SegmentedButton<FavoritesSort>(
              showSelectedIcon: false,
              segments: [
                for (final s in FavoritesSort.values)
                  ButtonSegment(
                    value: s,
                    label: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              selected: {sort},
              onSelectionChanged: (s) => onSort(s.first),
            ),
          ],
          AppSpacing.gapMd,
        ],
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    void open() => context.push(AppRoutes.hadith(hadith.id));
    return FavoriteHadithCard(
      arabicText: hadith.arabicText,
      somaliText: hadith.somaliText ?? missingTranslationText,
      source: repo.bookById(hadith.bookId)?.nameSomali ?? '—',
      reference: repo.referenceLabel(hadith),
      isVerified: hadith.isVerified,
      onTap: open,
      onOpen: open,
      onRemove: () async {
        final ok = await showConfirmDialog(
          context,
          title: 'Ka saar?',
          message: 'Xadiiskan waa laga saarayaa kuwa la keydiyay.',
          confirmLabel: 'Ka saar',
          isDestructive: true,
        );
        if (!ok) return;
        await services.favorites.remove(hadith.id);
        if (context.mounted) AppSnackbar.show(context, 'Waa laga saaray kuwa la keydiyay');
      },
    );
  }
}
