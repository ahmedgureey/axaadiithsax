import 'package:flutter/material.dart';

import '../../../../app/app_services.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';

/// "Tixraaca" — every metadata field the dataset has, and an explicit
/// "lama hayo" / "lama xaqiijin" for what it doesn't. Nothing is inferred.
class HadithReferenceSection extends StatelessWidget {
  const HadithReferenceSection({super.key, required this.hadith});

  final Hadith hadith;

  static const unavailable = 'Lama hayo';

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    final h = hadith;
    final chapter = repo.chapterById(h.chapterId);
    // Gradings: each scholar's classification with its reference, as stored.
    // Several may differ; they are listed, never merged or inferred.
    final String grading;
    if (h.isDemo) {
      grading = 'Lama xaqiijin — xogtani waa tusaale';
    } else if (h.isVerified && h.gradings.isNotEmpty) {
      grading = [
        for (final g in h.gradings)
          '${g.displayName}${g.label != null && g.grade != 'other' ? ' (${g.label})' : ''} — '
              '${g.scholar} · ${g.sourceReference}${g.notes != null ? '\n${g.notes}' : ''}',
      ].join('\n\n');
    } else {
      grading = (h.isVerified ? h.grade : null) ?? 'Darajo lama diiwaangelin';
    }
    final rows = <(String, String)>[
      ('Kitaabka', repo.bookById(h.bookId)?.nameSomali ?? unavailable),
      ('Cutubka', chapter == null ? unavailable : 'Cutubka ${chapter.number} — ${chapter.titleSomali}'),
      ('Lambarka xadiiska', h.isDemo ? '#${h.displayNumber} (booska xogta tusaalaha)' : h.displayNumber),
      ('Tixraac', repo.referenceLabel(h)),
      ('Weriyaha', h.narrators.isNotEmpty ? h.narrators.join('، ') : (h.narrator ?? unavailable)),
      ('Darajada', grading),
      if (h.translator != null)
        ('Tarjumaadda', '${h.translator}${h.translationSource != null ? ' · ${h.translationSource}' : ''}'),
      (
        'Xaaladda xogta',
        switch (h.sourceStatus) {
          SourceStatus.verified => 'La xaqiijiyay oo la daabacay',
          SourceStatus.sourced => 'Laga soo qaatay isha hoos ku qoran',
          SourceStatus.demo => 'Tusaale (lama xaqiijin)',
        },
      ),
      ('Isha', h.source ?? unavailable),
      if (h.sourceUrl != null) ('Link-ga isha', h.sourceUrl!),
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
