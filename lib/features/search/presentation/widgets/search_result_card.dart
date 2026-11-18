import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_services.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';
import '../../../favorites/presentation/widgets/hadith_bookmark_button.dart';
import '../../../hadith/hadith_actions.dart';

/// Splits [text] into spans, emphasising case-insensitive matches of the
/// Latin [tokens]. Arabic is not highlighted: matching ignores diacritics, so
/// character offsets in the original text would not line up reliably.
List<TextSpan> highlightSpans(String text, List<String> tokens, TextStyle highlight) {
  final latin = tokens.where((t) => RegExp(r'^[\x00-\x7F]+$').hasMatch(t)).toList();
  if (latin.isEmpty) return [TextSpan(text: text)];
  final lower = text.toLowerCase();
  final spans = <TextSpan>[];
  var i = 0;
  while (i < text.length) {
    var bestStart = -1;
    var bestLength = 0;
    for (final t in latin) {
      final at = lower.indexOf(t, i);
      if (at >= 0 && (bestStart < 0 || at < bestStart || (at == bestStart && t.length > bestLength))) {
        bestStart = at;
        bestLength = t.length;
      }
    }
    if (bestStart < 0) {
      spans.add(TextSpan(text: text.substring(i)));
      break;
    }
    if (bestStart > i) spans.add(TextSpan(text: text.substring(i, bestStart)));
    spans.add(TextSpan(text: text.substring(bestStart, bestStart + bestLength), style: highlight));
    i = bestStart + bestLength;
  }
  return spans;
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
      backgroundColor: c.goldSubtle,
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
              if (!hadith.isVerified) const DemoContentBadge(label: 'Tusaale'),
            ],
          ),
          AppSpacing.gapSm,
          ArabicText(hadith.arabicText, maxLines: 2, fontSize: 20),
          AppSpacing.gapXs,
          Text.rich(
            TextSpan(
              children: hadith.hasTranslation
                  ? highlightSpans(hadith.somaliText!, tokens, highlight)
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
