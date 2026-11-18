import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/not_found_screen.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/hadith.dart';

/// Focused reading screen (no bottom navigation).
class HadithDetailScreen extends StatefulWidget {
  const HadithDetailScreen({super.key, required this.hadithId});

  final String hadithId;

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Record after the frame so other tabs don't rebuild during this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final services = context.services;
      if (services.repository.hadithById(widget.hadithId) != null) {
        services.history.record(widget.hadithId);
      }
    });
  }

  Future<void> _copy(Hadith h, String source) async {
    await Clipboard.setData(ClipboardData(text: '${h.arabicText}\n\n${h.somaliText}\n— $source'));
    if (mounted) AppSnackbar.show(context, 'Waa la koobiyeeyay', type: AppSnackType.success);
  }

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    final hadith = repo.hadithById(widget.hadithId);
    if (hadith == null) {
      return const NotFoundScreen(
        title: 'Xadiiskan lama helin',
        message: 'Xadiiska aad furtay kuma jiro xogta app-ka.',
      );
    }
    final book = repo.bookById(hadith.bookId);
    final chapter = repo.chapterById(hadith.chapterId);
    final source = book?.nameSomali ?? '—';

    return ListenableBuilder(
      listenable: Listenable.merge([services.favorites, services.memorization]),
      builder: (context, _) {
        final isFavorite = services.favorites.isFavorite(hadith.id);
        final inPlan = services.memorization.planHadithIds.contains(hadith.id);
        final memorized = services.memorization.isMemorized(hadith.id);
        return Scaffold(
          appBar: AppBar(
            leading: backOrHomeLeading(context),
            title: Text(source),
            actions: [
              IconActionButton(
                icon: Icons.copy_rounded,
                tooltip: 'Koobiyee',
                onPressed: () => _copy(hadith, source),
              ),
              IconActionButton(
                icon: Icons.share_rounded,
                tooltip: 'La wadaag',
                onPressed: () => AppSnackbar.show(context, 'Wadaagista waxay iman doontaa dhowaan.'),
              ),
              IconActionButton(
                icon: Icons.bookmark_border_rounded,
                selectedIcon: Icons.bookmark_rounded,
                isSelected: isFavorite,
                tooltip: isFavorite ? 'Ka saar kuwa la jecel yahay' : 'Ku dar kuwa la jecel yahay',
                onPressed: () => services.favorites.toggle(hadith.id),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                AppPageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          MetaChip(label: source, icon: Icons.menu_book_rounded),
                          if (chapter != null)
                            MetaChip(label: chapter.titleSomali, color: context.appColors.goldText),
                          if (hadith.isVerified && hadith.grade != null)
                            MetaChip(
                              label: hadith.grade!,
                              icon: Icons.verified_rounded,
                              color: context.appColors.success,
                            ),
                          if (!hadith.isVerified) const DemoContentBadge(),
                        ],
                      ),
                      if (hadith.narrator != null) ...[
                        AppSpacing.gapLg,
                        ArabicText(hadith.narrator!, variant: ArabicTextVariant.narrator),
                      ],
                      AppSpacing.gapSm,
                      ArabicText(hadith.arabicText, selectable: true),
                      const OrnamentDivider(verticalPadding: AppSpacing.lg),
                      Text('Tarjumaadda', style: context.textStyles.labelMedium),
                      AppSpacing.gapXs,
                      SelectableText(hadith.somaliText, style: ArabicTextStyles.somaliTranslation(context)),
                      AppSpacing.gapXl,
                      Text('Tixraac', style: context.textStyles.labelMedium),
                      AppSpacing.gapXxs,
                      Text(
                        hadith.isVerified && hadith.reference != null
                            ? hadith.reference!
                            : 'Tixraac lama hayo — xogtan waa tusaale aan la xaqiijin.',
                        style: context.textStyles.bodyMedium,
                      ),
                      if (inPlan) ...[
                        AppSpacing.gapXl,
                        SecondaryButton(
                          label: memorized ? 'Waan xifdiyay ✓' : 'Calaamadee: waan xifdiyay',
                          icon: memorized ? Icons.check_circle_rounded : Icons.psychology_outlined,
                          onPressed: () => services.memorization.toggleMemorized(hadith.id),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
