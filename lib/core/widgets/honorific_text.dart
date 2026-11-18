import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Somali/Latin text that may contain the honorific ﷺ (U+FDFA).
///
/// Latin UI fonts usually lack this glyph (it shows as a box on web until a
/// fallback font downloads). This widget renders only the ﷺ characters with
/// the bundled Amiri font and leaves the rest in the normal UI font — so it
/// works offline on every platform without changing Latin typography.
class HonorificText extends StatelessWidget {
  const HonorificText(this.text, {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  static const honorific = 'ﷺ';

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    if (!text.contains(honorific)) {
      return Text(text, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
    }
    final parts = text.split(honorific);
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(
          const TextSpan(
            text: honorific,
            style: TextStyle(fontFamily: AppFonts.arabicFamily, fontFamilyFallback: AppFonts.arabicFallback),
          ),
        );
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
