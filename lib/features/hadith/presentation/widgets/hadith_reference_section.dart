import 'package:flutter/material.dart';

import '../../../../app/app_services.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';

/// "Tixraaca" — book, chapter, number and reference (narrator when known).
class HadithReferenceSection extends StatelessWidget {
  const HadithReferenceSection({super.key, required this.hadith});

  final Hadith hadith;

  static const unavailable = 'Lama hayo';

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    final h = hadith;
    final chapter = repo.chapterById(h.chapterId);
    final narrator = h.narrators.isNotEmpty ? h.narrators.join('، ') : h.narrator;
    final rows = <(String, String)>[
      ('Kitaabka', repo.bookById(h.bookId)?.nameSomali ?? unavailable),
      ('Cutubka', chapter == null ? unavailable : 'Cutubka ${chapter.number} — ${chapter.titleSomali}'),
      ('Lambarka xadiiska', h.isDemo ? '#${h.displayNumber} (booska xogta tusaalaha)' : h.displayNumber),
      ('Tixraac', repo.referenceLabel(h)),
      if (narrator != null) ('Weriyaha', narrator),
      // Only real, published gradings (each with scholar and reference);
      // nothing is shown when there are none.
      if (h.isVerified && h.gradings.isNotEmpty)
        (
          'Darajada',
          [
            for (final g in h.gradings)
              '${g.displayName}${g.label != null && g.grade != 'other' ? ' (${g.label})' : ''} — '
                  '${g.scholar} · ${g.sourceReference}${g.notes != null ? '\n${g.notes}' : ''}',
          ].join('\n\n'),
        ),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (label, value)) in rows.indexed) ...[
            if (i > 0) const Divider(height: AppSpacing.lg),
            // Label above value: never overflows on narrow screens.
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.textStyles.labelSmall),
                  AppSpacing.gapXxs,
                  Text(
                    value,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: value == unavailable ? context.appColors.textSecondary : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
