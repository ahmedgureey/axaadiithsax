import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_services.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';

/// "Xadiiska Maalinta" — uses the shared favorites controller for bookmarks.
class DailyHadithSection extends StatelessWidget {
  const DailyHadithSection({super.key, required this.hadith});

  final Hadith? hadith;

  Future<void> _share(BuildContext context, Hadith h, String source) async {
    // No share plugin yet: copy the text so it can be pasted anywhere.
    await Clipboard.setData(ClipboardData(text: '${h.arabicText}\n\n${h.somaliText}\n— $source'));
    if (context.mounted) {
      AppSnackbar.show(context, 'Qoraalka waa la koobiyeeyay si aad u wadaagto.', type: AppSnackType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = hadith;
    if (h == null) {
      return const AppCard(
        child: SizedBox(
          height: 240,
          child: EmptyStateWidget(
            icon: Icons.menu_book_outlined,
            title: 'Xadiiska maalinta lama heli karo',
            message: 'Weli xadiis laguma darin app-ka.',
          ),
        ),
      );
    }
    final services = context.services;
    final repo = services.repository;
    final source = repo.bookById(h.bookId)?.nameSomali ?? '—';
    void open() => context.push(AppRoutes.hadith(h.id));

    return ListenableBuilder(
      listenable: services.favorites,
      builder: (context, _) {
        final saved = services.favorites.isFavorite(h.id);
        return DailyHadithCard(
          arabicText: h.arabicText,
          somaliText: h.somaliText,
          narrator: h.narrator,
          source: source,
          reference: repo.referenceLabel(h),
          grade: h.grade,
          isVerified: h.isVerified,
          isFavorite: saved,
          onTap: open,
          onRead: open,
          onShare: () => _share(context, h, source),
          onBookmark: () async {
            final added = await services.favorites.toggle(h.id);
            if (context.mounted) {
              AppSnackbar.show(context, added ? 'Waa la keydiyay' : 'Waa laga saaray kuwa la keydiyay');
            }
          },
        );
      },
    );
  }
}
