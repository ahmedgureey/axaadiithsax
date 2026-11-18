import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../core/services/share_service.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/hadith.dart';

/// Shown wherever a hadith has no Somali translation yet.
const missingTranslationText = 'Tarjumaadda Af Soomaaliga weli lama hayo.';

/// Builds the plain text used for sharing / copying a whole hadith. Demo
/// records always carry a disclaimer so shared text is never mistaken for an
/// authentic hadith.
String hadithShareText(BuildContext context, Hadith h) {
  final repo = context.services.repository;
  final book = repo.bookById(h.bookId)?.nameSomali ?? '';
  final buffer = StringBuffer()
    ..writeln(h.arabicText)
    ..writeln()
    ..writeln(h.hasTranslation ? h.somaliText : missingTranslationText)
    ..writeln()
    ..write('— $book · ${repo.referenceLabel(h)}');
  if (!h.isVerified) {
    buffer
      ..writeln()
      ..write('(Xog tusaale ah — ma aha xadiis la xaqiijiyay.)');
  }
  buffer
    ..writeln()
    ..write('Xadiith App');
  return buffer.toString();
}

/// Copies [text] and confirms with a snack bar.
Future<void> copyText(BuildContext context, String text, String confirmation) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) AppSnackbar.show(context, confirmation, type: AppSnackType.success);
}

/// Opens the system share sheet; falls back to copying when unavailable.
Future<void> shareHadith(BuildContext context, Hadith h) async {
  final text = hadithShareText(context, h);
  final outcome = await context.services.share.shareText(text, subject: 'Xadiis — Xadiith App');
  if (!context.mounted) return;
  if (outcome == ShareOutcome.unavailable) {
    await copyText(context, text, 'Wadaagistu halkan lama heli karo — qoraalka waa la koobiyeeyay.');
  }
}
