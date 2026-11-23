import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/not_found_screen.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/hadith.dart';
import '../../../data/remote/catalog_api.dart';
import '../hadith_actions.dart';
import '../../favorites/presentation/widgets/hadith_bookmark_button.dart';
import 'widgets/arabic_font_controls.dart';
import 'widgets/hadith_audio_player.dart';
import 'widgets/hadith_reading_actions.dart';
import 'widgets/hadith_reference_section.dart';
import '../../settings/presentation/widgets/reading_preferences_card.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final services = context.services;
      // Backend: fetch the full published record (translations, gradings,
      // narrators). Only a record that exists is added to history.
      final found = services.catalog == null
          ? services.repository.hadithById(widget.hadithId)
          : await services.catalog!.ensureDetail(widget.hadithId);
      if (mounted && found != null) services.history.record(widget.hadithId);
    });
  }

  @override
  Widget build(BuildContext context) => CatalogBuilder(builder: _build);

  Widget _build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    final hadith = repo.hadithById(widget.hadithId);
    final catalog = services.catalog;
    if (hadith == null) {
      final load = catalog?.detailState(widget.hadithId);
      if (load != null && !load.isFailed) {
        return Scaffold(
          appBar: AppBar(leading: backOrHomeLeading(context)),
          body: const LoadingIndicator(message: 'Xadiiska waa la soo rarayaa'),
        );
      }
      if (load != null && load.failure?.kind != CatalogFailureKind.notFound) {
        return Scaffold(
          appBar: AppBar(leading: backOrHomeLeading(context)),
          body: ErrorStateWidget(
            title: 'Xadiiska lama soo rari karin',
            message: load.failure!.message,
            onRetry: () => catalog!.ensureDetail(widget.hadithId, force: true),
          ),
        );
      }
      return const NotFoundScreen(
        title: 'Xadiiskan lama helin',
        message: 'Xadiiska aad furtay kuma jiro, ama weli lama daabicin.',
      );
    }
    final book = repo.bookById(hadith.bookId);
    final chapter = repo.chapterById(hadith.chapterId);
    final neighbours = repo.neighboursOf(hadith);
    final related = repo.relatedTo(hadith);

    return ListenableBuilder(
      // Favourites are handled by HadithBookmarkButton / HadithReadingActions.
      listenable: Listenable.merge([services.memorization, services.settings]),
      builder: (context, _) {
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
                  '${chapter?.titleSomali ?? ''} · #${hadith.displayNumber}',
                  style: context.textStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              IconActionButton(
                icon: Icons.text_fields_rounded,
                tooltip: context.tr(AppText.readerSettings),
                onPressed: () => showReadingSettingsSheet(context),
              ),
              HadithBookmarkButton(hadithId: hadith.id),
              IconActionButton(
                icon: Icons.share_rounded,
                tooltip: context.tr(AppText.actionShare),
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
                          if (chapter != null) MetaChip(label: chapter.titleSomali, color: context.appColors.goldText),
                          if (hadith.isVerified && hadith.gradings.isNotEmpty)
                            // One chip only when every documented grading
                            // agrees; otherwise point to the full list.
                            {for (final g in hadith.gradings) g.grade}.length == 1
                                ? MetaChip(
                                    label: hadith.gradings.length == 1
                                        ? '${hadith.gradings.first.displayName} · ${hadith.gradings.first.scholar}'
                                        : hadith.gradings.first.displayName,
                                    icon: Icons.verified_rounded,
                                    color: context.appColors.success,
                                  )
                                : MetaChip(
                                    label: 'Darajooyin kala duwan — eeg Tixraaca',
                                    icon: Icons.balance_rounded,
                                    color: context.appColors.goldText,
                                  )
                          else if (hadith.isVerified && hadith.grade != null)
                            MetaChip(
                              label: hadith.grade!,
                              icon: Icons.verified_rounded,
                              color: context.appColors.success,
                            ),
                          if (!hadith.isVerified) const DemoContentBadge(),
                        ],
                      ),
                      AppSpacing.gapXs,
                      // The demo text is bundled with the app, so it is readable offline.
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OfflineStatusIndicator(status: OfflineAvailability.availableLocally),
                      ),
                      _BookPosition(order: repo.readingOrderOf(hadith.bookId), current: hadith),
                      AppSpacing.gapLg,
                      _SectionLabel(context.tr(AppText.readerNarrator)),
                      if (hadith.narrator != null)
                        ArabicText(hadith.narrator!, variant: ArabicTextVariant.narrator)
                      else
                        const _MissingText('Weriyaha lama hayo.'),
                      AppSpacing.gapLg,
                      Row(
                        children: [
                          Expanded(child: _SectionLabel(context.tr(AppText.readerArabic))),
                          ArabicFontControls(settings: services.settings),
                        ],
                      ),
                      AppSpacing.gapXs,
                      ArabicText(hadith.arabicText, selectable: true),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: AppTextButton(
                          label: context.tr(AppText.actionCopyArabic),
                          icon: Icons.copy_rounded,
                          onPressed: () => copyText(context, hadith.arabicText, 'Qoraalka Carabiga waa la koobiyeeyay'),
                        ),
                      ),
                      const OrnamentDivider(verticalPadding: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(child: _SectionLabel(context.tr(AppText.readerTranslation))),
                          Semantics(
                            label: context.tr(AppText.readerShowTranslation),
                            excludeSemantics: true,
                            toggled: services.settings.showTranslation,
                            child: Switch(
                              value: services.settings.showTranslation,
                              onChanged: services.settings.setShowTranslation,
                            ),
                          ),
                        ],
                      ),
                      if (!services.settings.showTranslation)
                        _MissingText(context.tr(AppText.readerTranslationHidden))
                      else if (hadith.hasTranslation) ...[
                        SelectableText(hadith.somaliText!, style: ArabicTextStyles.somaliTranslation(context)),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: AppTextButton(
                            label: context.tr(AppText.actionCopyTranslation),
                            icon: Icons.copy_rounded,
                            onPressed: () => copyText(context, hadith.somaliText!, 'Tarjumaadda waa la koobiyeeyay'),
                          ),
                        ),
                      ] else
                        const _MissingText(missingTranslationText),
                      AppSpacing.gapMd,
                      HadithReadingActions(hadith: hadith),
                      AppSpacing.gapLg,
                      HadithAudioPlayer(hadith: hadith),
                      AppSpacing.gapLg,
                      // Same progress record as the Xifdinta tab.
                      SecondaryButton(
                        label: memorized ? 'Waan xifdiyey ✓ (ka noqo)' : 'Calaamadee: Waan Xifdiyey',
                        icon: memorized ? Icons.check_circle_rounded : Icons.psychology_outlined,
                        onPressed: () => memorized
                            ? services.memorization.undoMemorized(hadith.id)
                            : services.memorization.markMemorized(hadith.id),
                      ),
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
    style: context.textStyles.bodyMedium?.copyWith(color: context.appColors.textSecondary, fontStyle: FontStyle.italic),
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

/// Position of this record in its book's reading order. It shows *where* the
/// reader is, not how much has been read.
class _BookPosition extends StatelessWidget {
  const _BookPosition({required this.order, required this.current});

  final List<Hadith> order;
  final Hadith current;

  @override
  Widget build(BuildContext context) {
    final index = order.indexWhere((h) => h.id == current.id);
    if (index < 0 || order.length < 2) return const SizedBox.shrink();
    final position = index + 1;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: LinearProgressIndicator(
                value: position / order.length,
                minHeight: 4,
                semanticsLabel: '${context.tr(AppText.readerPosition)}: $position / ${order.length}',
                semanticsValue: '${(position * 100 / order.length).round()}',
              ),
            ),
          ),
          AppSpacing.gapSm,
          ExcludeSemantics(child: Text('$position / ${order.length}', style: context.textStyles.labelSmall)),
        ],
      ),
    );
  }
}

/// Reading settings without leaving the hadith: translation visibility plus
/// the same Arabic/translation size and spacing controls as Dejinta.
Future<void> showReadingSettingsSheet(BuildContext context) {
  final settings = context.services.settings;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: settings,
      builder: (sheetContext, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(sheetContext.tr(AppText.readerSettings), style: sheetContext.textStyles.titleLarge),
            AppSpacing.gapSm,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(sheetContext.tr(AppText.readerShowTranslation)),
              value: settings.showTranslation,
              onChanged: settings.setShowTranslation,
            ),
            ReadingPreferencesCard(settings: settings),
          ],
        ),
      ),
    ),
  );
}

/// Previous / next record in the same book. Replaces the current page so the
/// back stack doesn't grow while paging. Directional icons follow the
/// interface direction, so they point the right way in Arabic (RTL) too.
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
                    label: context.tr(AppText.readerPrevious),
                    icon: Icons.chevron_left_rounded,
                    onPressed: previous == null ? null : () => open(previous!),
                  ),
                ),
                AppSpacing.gapXs,
                Expanded(
                  child: TextButton.icon(
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: Text(context.tr(AppText.readerNext), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onPressed: next == null ? null : () => open(next!),
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
