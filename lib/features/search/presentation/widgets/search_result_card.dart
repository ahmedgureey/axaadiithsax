import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_services.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/arabic_normalizer.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';
import '../../../favorites/presentation/widgets/hadith_bookmark_button.dart';
import '../../../hadith/hadith_actions.dart';

/// Splits [text] into spans, colouring every match of the search [tokens]
/// (Arabic or Somali). Matching uses the same normalisation as search
/// (diacritics and letter variants ignored), but the ORIGINAL text is shown.
List<TextSpan> highlightSpans(String text, List<String> tokens, TextStyle highlight) {
  final ranges = ArabicNormalizer.matchRanges(text, tokens);
  if (ranges.isEmpty) return [TextSpan(text: text)];
  final spans = <TextSpan>[];
  var i = 0;
  for (final (start, end) in ranges) {
    if (start > i) spans.add(TextSpan(text: text.substring(i, start)));
    spans.add(TextSpan(text: text.substring(start, end), style: highlight));
    i = end;
  }
  if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
  return spans;
}

/// When the first match is far into [text], starts the excerpt shortly
/// before it (at a word boundary, prefixed with "… ") so the matched word is
/// visible in the few lines a result card shows.
String excerptAroundMatch(String text, List<String> tokens, {int lead = 40}) {
  final ranges = ArabicNormalizer.matchRanges(text, tokens);
  if (ranges.isEmpty || ranges.first.$1 <= lead) return text;
  var start = ranges.first.$1 - lead;
  final space = text.indexOf(' ', start);
  if (space >= 0 && space < ranges.first.$1) start = space + 1;
  return '… ${text.substring(start)}';
}

/// Short grade label for a result card, from documented gradings only:
/// null when there is none, the grade when all scholars agree, otherwise
/// "Darajooyin kala duwan" (details on the Hadith screen). Never inferred
/// from the collection.
String? gradeLabel(Hadith h) {
  if (h.gradings.isEmpty) return null;
  final kinds = {for (final g in h.gradings) g.grade};
  if (kinds.length > 1) return 'Darajooyin kala duwan';
  final g = h.gradings.first;
  return h.gradings.length == 1 ? '${g.displayName} · ${g.scholar}' : g.displayName;
}

/// Search / category result. Opens the shared Hadith Detail screen.
class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.hadith, this.tokens = const [], this.onOpen});

  final Hadith hadith;
  final List<String> tokens;

  /// Called before navigating (e.g. to save the search term).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    final c = context.appColors;
    final book = repo.bookById(hadith.bookId);
    final topics = [for (final id in hadith.categoryIds) ?repo.categoryById(id)];
    final highlight = TextStyle(
      backgroundColor: c.gold.withValues(alpha: 0.35),
      fontWeight: FontWeight.w700,
      color: context.colors.onSurface,
    );

    return AppCard(
      onTap: () {
        onOpen?.call();
        context.push(AppRoutes.hadith(hadith.id));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              MetaChip(label: book?.nameSomali ?? '—', icon: Icons.menu_book_rounded),
              MetaChip(label: repo.referenceLabel(hadith), color: c.goldText),
              if (hadith.isDemo) const DemoContentBadge(label: 'Tusaale'),
              if (gradeLabel(hadith) case final grade?) MetaChip(label: grade, icon: Icons.verified_outlined),
            ],
          ),
          if (hadith.narrator case final narrator?) ...[
            AppSpacing.gapXs,
            ArabicText(narrator, maxLines: 1, fontSize: 15),
          ],
          AppSpacing.gapSm,
          if (tokens.isEmpty)
            ArabicText(hadith.arabicText, maxLines: 2, fontSize: 20)
          else
            // Matches are coloured here only; the Hadith screen shows plain text.
            Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                width: double.infinity,
                child: Text.rich(
                  TextSpan(children: highlightSpans(excerptAroundMatch(hadith.arabicText, tokens), tokens, highlight)),
                  style: ArabicTextStyles.hadith(context, fontSize: 20),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  locale: const Locale('ar'),
                ),
              ),
            ),
          AppSpacing.gapXs,
          Text.rich(
            TextSpan(
              children: hadith.hasTranslation
                  ? highlightSpans(excerptAroundMatch(hadith.somaliText!, tokens, lead: 60), tokens, highlight)
                  : [
                      TextSpan(
                        text: missingTranslationText,
                        style: TextStyle(fontStyle: FontStyle.italic, color: c.textSecondary),
                      ),
                    ],
            ),
            style: context.textStyles.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapXs,
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xxs,
                  runSpacing: AppSpacing.xxs,
                  children: [for (final t in topics) MetaChip(label: t.nameSomali, icon: Icons.label_outline_rounded)],
                ),
              ),
              HadithBookmarkButton(hadithId: hadith.id),
            ],
          ),
        ],
      ),
    );
  }
}
