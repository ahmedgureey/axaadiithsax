import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../core/services/share_service.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';

/// Shown wherever a hadith has no Somali translation yet.
const missingTranslationText = 'Tarjumaadda Af Soomaaliga weli lama hayo.';

/// Plain-text version of a hadith for copying / sharing (pure, testable).
///
/// Only data that exists is included: narrator when present, grade only for
/// verified records. Demo records always end with a disclaimer so the text is
/// never mistaken for an authentic hadith.
String formatHadithText(Hadith h, HadithRepository repo) {
  final book = repo.bookById(h.bookId)?.nameSomali;
  final lines = <String>[
    if (h.narrator != null) h.narrator!,
    h.arabicText,
    '',
    h.hasTranslation ? h.somaliText! : missingTranslationText,
    '',
    [?book, repo.referenceLabel(h)].join(' · '),
    if (h.isVerified && h.grade != null) 'Darajada: ${h.grade}',
    if (h.isDemo) '(Xog tusaale ah — ma aha xadiis la xaqiijiyay.)',
    'Xadiith App',
  ];
  return lines.join('\n');
}

/// Context convenience for [formatHadithText].
String hadithShareText(BuildContext context, Hadith h) => formatHadithText(h, context.services.repository);

/// Copies [text] and confirms; shows an error message if the clipboard fails.
Future<bool> copyText(BuildContext context, String text, String confirmation) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } catch (_) {
    if (context.mounted) {
      AppSnackbar.show(context, 'Lama koobiyeyn karo hadda. Isku day mar kale.', type: AppSnackType.error);
    }
    return false;
  }
  if (context.mounted) AppSnackbar.show(context, confirmation, type: AppSnackType.success);
  return true;
}

/// Opens the system share sheet. Nothing claims success; if sharing is not
/// available the text is copied instead and the user is told so.
Future<ShareOutcome> shareHadith(BuildContext context, Hadith h) async {
  final text = hadithShareText(context, h);
  final outcome = await context.services.share.shareText(text, subject: 'Xadiis — Xadiith App');
  if (context.mounted && outcome == ShareOutcome.unavailable) {
    await copyText(context, text, 'Wadaagistu halkan lama heli karo — qoraalka waa la koobiyeeyay.');
  }
  return outcome;
}
