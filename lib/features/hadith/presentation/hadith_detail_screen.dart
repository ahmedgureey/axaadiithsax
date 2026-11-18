import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/not_found_screen.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/hadith.dart';
import '../hadith_actions.dart';
import 'widgets/arabic_font_controls.dart';
import 'widgets/hadith_reference_section.dart';

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
    final neighbours = repo.neighboursOf(hadith);
    final related = repo.relatedTo(hadith);

    return ListenableBuilder(
      listenable: Listenable.merge([services.favorites, services.memorization, services.settings]),
      builder: (context, _) {
        final isFavorite = services.favorites.isFavorite(hadith.id);
        final inPlan = services.memorization.planHadithIds.contains(hadith.id);
        final memorized = services.memorization.isMemorized(hadith.id);
        return Scaffold(
          appBar: AppBar(
            leading: backOrHomeLeading(context),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(book?.nameSomali ?? 'Xadiis', maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${chapter?.titleSomali ?? ''} · #${hadith.number}',
                  style: context.textStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              IconActionButton(
                icon: Icons.bookmark_border_rounded,
                selectedIcon: Icons.bookmark_rounded,
                isSelected: isFavorite,
                tooltip: isFavorite ? 'Ka saar kuwa la jecel yahay' : 'Ku dar kuwa la jecel yahay',
                onPressed: () => services.favorites.toggle(hadith.id),
              ),
              IconActionButton(
                icon: Icons.share_rounded,
                tooltip: 'La wadaag',
                onPressed: () => shareHadith(context, hadith),
              ),
            ],
          ),
          bottomNavigationBar: _PreviousNextBar(previous: neighbours.previous, next: neighbours.next),
          body: SafeArea(
            bottom: false,
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
                          MetaChip(label: book?.nameSomali ?? '—', icon: Icons.menu_book_rounded),
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
                      AppSpacing.gapLg,
                      const _SectionLabel('Weriyaha'),
                      if (hadith.narrator != null)
                        ArabicText(hadith.narrator!, variant: ArabicTextVariant.narrator)
                      else
                        const _MissingText('Weriyaha lama hayo.'),
                      AppSpacing.gapLg,
                      Row(
                        children: [
                          const Expanded(child: _SectionLabel('Qoraalka Carabiga')),
                          ArabicFontControls(settings: services.settings),
                        ],
                      ),
                      AppSpacing.gapXs,
                      ArabicText(hadith.arabicText, selectable: true),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppTextButton(
                          label: 'Koobiyee Carabiga',
                          icon: Icons.copy_rounded,
                          onPressed: () =>
                              copyText(context, hadith.arabicText, 'Qoraalka Carabiga waa la koobiyeeyay'),
                        ),
                      ),
                      const OrnamentDivider(verticalPadding: AppSpacing.md),
                      const _SectionLabel('Tarjumaadda Af Soomaaliga'),
                      if (hadith.hasTranslation) ...[
                        SelectableText(
                          hadith.somaliText!,
                          style: ArabicTextStyles.somaliTranslation(context),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppTextButton(
                            label: 'Koobiyee tarjumaadda',
                            icon: Icons.copy_rounded,
                            onPressed: () =>
                                copyText(context, hadith.somaliText!, 'Tarjumaadda waa la koobiyeeyay'),
                          ),
                        ),
                      ] else
                        const _MissingText(missingTranslationText),
                      if (inPlan) ...[
                        AppSpacing.gapLg,
                        SecondaryButton(
                          label: memorized ? 'Waan xifdiyay ✓' : 'Calaamadee: waan xifdiyay',
                          icon: memorized ? Icons.check_circle_rounded : Icons.psychology_outlined,
                          onPressed: () => services.memorization.toggleMemorized(hadith.id),
                        ),
                      ],
                      AppSpacing.gapXl,
                      const SectionHeader(title: 'Tixraaca'),
                      AppSpacing.gapSm,
                      HadithReferenceSection(hadith: hadith),
                      if (related.isNotEmpty) ...[
                        AppSpacing.gapXl,
                        const SectionHeader(title: 'Xadiisyo la xiriira'),
                        AppSpacing.gapSm,
                        for (final r in related) _RelatedTile(hadith: r),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Text(text, style: context.textStyles.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
    ),
  );
}

class _MissingText extends StatelessWidget {
  const _MissingText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.textStyles.bodyMedium?.copyWith(
      color: context.appColors.textSecondary,
      fontStyle: FontStyle.italic,
    ),
  );
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.hadith});
  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        onTap: () => context.push(AppRoutes.hadith(hadith.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArabicText(hadith.arabicText, maxLines: 1, fontSize: 18),
            AppSpacing.gapXxs,
            Text(
              hadith.somaliText ?? missingTranslationText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.bodySmall,
            ),
            Text(
              '${repo.bookById(hadith.bookId)?.nameSomali ?? ''} · ${repo.referenceLabel(hadith)}',
              style: context.textStyles.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Previous / next record in the same book. Replaces the current page so the
/// back stack doesn't grow while paging.
class _PreviousNextBar extends StatelessWidget {
  const _PreviousNextBar({required this.previous, required this.next});

  final Hadith? previous;
  final Hadith? next;

  @override
  Widget build(BuildContext context) {
    if (previous == null && next == null) return const SizedBox.shrink();
    void open(Hadith h) => context.pushReplacement(AppRoutes.hadith(h.id));
    return Material(
      color: context.colors.surface,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.appColors.divider)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: AppTextButton(
                    label: 'Xadiiskii hore',
                    icon: Icons.chevron_left_rounded,
                    onPressed: previous == null ? null : () => open(previous!),
                  ),
                ),
                AppSpacing.gapXs,
                Expanded(
                  child: Directionality(
                    // Icon after the label: "Xadiiska xiga ›".
                    textDirection: TextDirection.rtl,
                    child: AppTextButton(
                      label: 'Xadiiska xiga',
                      icon: Icons.chevron_left_rounded,
                      onPressed: next == null ? null : () => open(next!),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
