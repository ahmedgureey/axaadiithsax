import 'package:flutter/material.dart';

import '../settings/app_settings_controller.dart';
import '../theme/app_typography.dart';

enum ArabicTextVariant { hadith, chapterHeading, narrator, label }

/// Renders Arabic content in an explicit right-to-left region, regardless of
/// the surrounding (Somali, LTR) layout.
///
/// The [ArabicTextVariant.hadith] variant follows the user's reading size from
/// [AppSettingsScope] unless [fontSize] is given.
class ArabicText extends StatelessWidget {
  const ArabicText(
    this.text, {
    super.key,
    this.variant = ArabicTextVariant.hadith,
    this.fontSize,
    this.maxLines,
    this.textAlign = TextAlign.start,
    this.color,
    this.selectable = false,
  });

  final String text;
  final ArabicTextVariant variant;
  final double? fontSize;
  final int? maxLines;

  /// `start` in an RTL region = right-aligned.
  final TextAlign textAlign;
  final Color? color;

  /// Allows long-press text selection (useful on hadith detail).
  final bool selectable;

  TextStyle _style(BuildContext context) {
    final style = switch (variant) {
      ArabicTextVariant.hadith => ArabicTextStyles.hadith(
        context,
        fontSize: fontSize ?? AppSettingsScope.maybeOf(context)?.arabicFontSize ?? ArabicFontSize.defaultSize,
      ),
      ArabicTextVariant.chapterHeading => ArabicTextStyles.chapterHeading(context),
      ArabicTextVariant.narrator => ArabicTextStyles.narrator(context),
      ArabicTextVariant.label => ArabicTextStyles.label(context),
    };
    var result = style;
    if (fontSize != null && variant != ArabicTextVariant.hadith) {
      result = result.copyWith(fontSize: fontSize);
    }
    if (color != null) result = result.copyWith(color: color);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: double.infinity,
        child: selectable
            ? SelectableText(
                text,
                style: style,
                textAlign: textAlign,
                maxLines: maxLines,
                textDirection: TextDirection.rtl,
              )
            : Text(
                text,
                style: style,
                textAlign: textAlign,
                maxLines: maxLines,
                overflow: overflow,
                textDirection: TextDirection.rtl,
                locale: const Locale('ar'),
              ),
      ),
    );
  }
}
