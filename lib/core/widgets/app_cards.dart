import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';
import 'app_buttons.dart';
import 'arabic_text.dart';
import 'islamic_ornament.dart';

/// Labels content that has NOT been verified against reliable hadith sources.
/// Must be shown wherever demo/mock hadith content appears.
class DemoContentBadge extends StatelessWidget {
  const DemoContentBadge({super.key, this.label = 'Tusaale — lama xaqiijin'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      label: 'Digniin: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
        decoration: BoxDecoration(
          color: c.warning.withValues(alpha: 0.12),
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: c.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: c.warning),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                label,
                style: context.textStyles.labelSmall?.copyWith(color: c.warning),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small metadata pill (reference number, grade, count...).
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.10), borderRadius: AppRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: AppSpacing.xxs)],
          Flexible(
            child: Text(
              label,
              style: context.textStyles.labelSmall?.copyWith(color: fg),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Base card: themed surface, border, ink ripple, consistent padding.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.cardPadding,
    this.color,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: borderColor == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: AppRadius.cardAll,
              side: BorderSide(color: borderColor!),
            ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (semanticLabel == null) return card;
    return Semantics(button: onTap != null, label: semanticLabel, child: card);
  }
}

/// Hadith preview / full card.
///
/// [grade] is only displayed when [isVerified] is true. Unverified content
/// always shows a [DemoContentBadge].
class HadithCard extends StatelessWidget {
  const HadithCard({
    super.key,
    required this.arabicText,
    required this.somaliText,
    required this.source,
    this.narrator,
    this.reference,
    this.grade,
    this.isVerified = false,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
    this.onCopy,
    this.onShare,
    this.previewLines,
  });

  final String arabicText;
  final String somaliText;

  /// Book (and optionally chapter) name, e.g. "Saxiix al-Bukhaari".
  final String source;
  final String? narrator;
  final String? reference;
  final String? grade;
  final bool isVerified;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  /// Limit text lines for list previews; null = full text.
  final int? previewLines;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final hasActions = onFavoriteToggle != null || onCopy != null || onShare != null;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MetaChip(label: source, icon: Icons.menu_book_rounded),
              if (reference != null) MetaChip(label: reference!, color: c.goldText),
              if (isVerified && grade != null)
                MetaChip(label: grade!, icon: Icons.verified_rounded, color: c.success),
              if (!isVerified) const DemoContentBadge(),
            ],
          ),
          if (narrator != null) ...[
            AppSpacing.gapSm,
            ArabicText(narrator!, variant: ArabicTextVariant.narrator),
          ],
          AppSpacing.gapXs,
          ArabicText(arabicText, maxLines: previewLines),
          const OrnamentDivider(),
          Text(
            somaliText,
            style: context.textStyles.bodyLarge,
            maxLines: previewLines,
            overflow: previewLines == null ? null : TextOverflow.ellipsis,
          ),
          if (hasActions) ...[
            AppSpacing.gapXs,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCopy != null)
                  IconActionButton(icon: Icons.copy_rounded, tooltip: 'Koobiyee', onPressed: onCopy),
                if (onShare != null)
                  IconActionButton(icon: Icons.share_rounded, tooltip: 'La wadaag', onPressed: onShare),
                if (onFavoriteToggle != null)
                  IconActionButton(
                    icon: Icons.bookmark_border_rounded,
                    selectedIcon: Icons.bookmark_rounded,
                    isSelected: isFavorite,
                    tooltip: isFavorite ? 'Ka saar kuwa la jecel yahay' : 'Ku dar kuwa la jecel yahay',
                    onPressed: onFavoriteToggle,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Hero card for "Xadiiska Maalinta" on the home screen.
class DailyHadithCard extends StatelessWidget {
  const DailyHadithCard({
    super.key,
    required this.arabicText,
    required this.somaliText,
    required this.source,
    this.isVerified = false,
    this.title = 'Xadiiska Maalinta',
    this.narrator,
    this.reference,
    this.grade,
    this.isFavorite = false,
    this.readLabel = 'Akhri Xadiiska',
    this.onTap,
    this.onRead,
    this.onShare,
    this.onBookmark,
  });

  final String arabicText;
  final String somaliText;
  final String source;
  final bool isVerified;
  final String title;

  /// Arabic narrator line, when available.
  final String? narrator;

  /// Reference label (book position or verified reference).
  final String? reference;

  /// Shown only when [isVerified] is true.
  final String? grade;
  final bool isFavorite;
  final String readLabel;
  final VoidCallback? onTap;
  final VoidCallback? onRead;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final c = context.appColors;
    final isDark = scheme.brightness == Brightness.dark;
    final onHero = isDark ? scheme.onSurface : scheme.onPrimary;
    final heroColor = isDark ? scheme.primaryContainer : scheme.tertiary;
    final muted = onHero.withValues(alpha: 0.78);
    final hasActions = onRead != null || onBookmark != null || onShare != null;

    return Card(
      color: heroColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeAll,
        side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        child: IslamicPatternBackground(
          color: c.gold.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IslamicStar(size: 16, color: c.gold),
                    AppSpacing.gapXs,
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title.toUpperCase(),
                          style: context.textStyles.labelMedium?.copyWith(
                            color: c.gold,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (narrator != null) ...[
                  AppSpacing.gapSm,
                  ArabicText(narrator!, variant: ArabicTextVariant.narrator, color: c.gold),
                ],
                AppSpacing.gapXs,
                ArabicText(arabicText, color: onHero, maxLines: 5),
                AppSpacing.gapMd,
                Text(
                  'Tarjumaadda Af Soomaaliga:',
                  style: context.textStyles.labelMedium?.copyWith(color: muted),
                ),
                AppSpacing.gapXxs,
                Text(
                  somaliText,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodyMedium?.copyWith(color: onHero.withValues(alpha: 0.92)),
                ),
                AppSpacing.gapMd,
                Text(
                  reference == null ? 'Tixraac: $source' : 'Tixraac: $source · $reference',
                  style: context.textStyles.labelMedium?.copyWith(color: c.gold),
                ),
                if (isVerified && grade != null) ...[
                  AppSpacing.gapXs,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: MetaChip(label: grade!, icon: Icons.verified_rounded, color: onHero),
                  ),
                ],
                if (!isVerified) ...[
                  AppSpacing.gapXs,
                  Align(
                    alignment: Alignment.centerLeft,
                    // High-contrast badge variant on the dark green hero.
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: scheme.surface, borderRadius: AppRadius.pillAll),
                      child: const DemoContentBadge(),
                    ),
                  ),
                ],
                if (hasActions) ...[
                  AppSpacing.gapLg,
                  Row(
                    children: [
                      if (onRead != null)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onRead,
                            icon: const Icon(Icons.menu_book_rounded, size: AppSizes.iconSm),
                            label: Text(readLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                            style: FilledButton.styleFrom(
                              backgroundColor: c.gold,
                              foregroundColor: isDark ? scheme.onSecondary : scheme.tertiary,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (onBookmark != null)
                        IconButton(
                          onPressed: onBookmark,
                          tooltip: isFavorite ? 'Ka saar kuwa la jecel yahay' : 'Ku dar kuwa la jecel yahay',
                          isSelected: isFavorite,
                          color: isFavorite ? c.gold : onHero,
                          icon: Icon(isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                        ),
                      if (onShare != null)
                        IconButton(
                          onPressed: onShare,
                          tooltip: 'La wadaag',
                          color: onHero,
                          icon: const Icon(Icons.share_rounded),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Saved hadith in the favourites list.
class FavoriteHadithCard extends StatelessWidget {
  const FavoriteHadithCard({
    super.key,
    required this.arabicText,
    required this.somaliText,
    required this.source,
    this.savedLabel,
    this.isVerified = false,
    this.onTap,
    this.onRemove,
  });

  final String arabicText;
  final String somaliText;
  final String source;

  /// e.g. "La keydiyay 3 maalmood ka hor".
  final String? savedLabel;
  final bool isVerified;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(color: c.gold, borderRadius: AppRadius.pillAll),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ArabicText(arabicText, maxLines: 2, fontSize: 20),
                AppSpacing.gapXxs,
                Text(
                  somaliText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodyMedium,
                ),
                AppSpacing.gapXs,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(source, style: context.textStyles.labelSmall),
                    if (savedLabel != null) Text('· $savedLabel', style: context.textStyles.labelSmall),
                    if (!isVerified) const DemoContentBadge(),
                  ],
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconActionButton(
              icon: Icons.bookmark_rounded,
              isSelected: true,
              tooltip: 'Ka saar',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Hadith collection card (Kutubta tab).
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.titleSomali,
    this.titleArabic,
    this.author,
    this.countLabel,
    this.onTap,
  });

  final String titleSomali;
  final String? titleArabic;
  final String? author;

  /// e.g. "97 kutub" — pass only verified counts.
  final String? countLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final c = context.appColors;
    return AppCard(
      onTap: onTap,
      semanticLabel: titleSomali,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: c.gold.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_stories_rounded, color: scheme.onPrimaryContainer),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleSomali, style: context.textStyles.titleMedium),
                if (titleArabic != null)
                  ArabicText(titleArabic!, variant: ArabicTextVariant.label, maxLines: 1),
                if (author != null) Text(author!, style: context.textStyles.bodySmall),
                if (countLabel != null) ...[AppSpacing.gapXxs, MetaChip(label: countLabel!)],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textSecondary),
        ],
      ),
    );
  }
}

/// Topic card (Salaad, Akhlaaq, ...). Works in a grid.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.isSelected = false,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AppCard(
      onTap: onTap,
      semanticLabel: title,
      color: isSelected ? scheme.primaryContainer : null,
      borderColor: isSelected ? scheme.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(color: context.appColors.goldSubtle, borderRadius: AppRadius.smAll),
            child: Icon(icon, color: context.appColors.goldText, size: AppSizes.icon),
          ),
          AppSpacing.gapSm,
          // Flexible so the card degrades (ellipsis) instead of overflowing
          // when placed in a fixed-height grid cell with large text.
          Flexible(
            child: Text(
              title,
              style: context.textStyles.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subtitle != null)
            Flexible(
              child: Text(
                subtitle!,
                style: context.textStyles.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// Memorisation plan progress (Xifdinta tab).
class MemorizationProgressCard extends StatelessWidget {
  const MemorizationProgressCard({
    super.key,
    required this.title,
    required this.memorized,
    required this.total,
    this.subtitle,
    this.streakDays,
    this.onTap,
    this.onContinue,
  });

  final String title;
  final int memorized;
  final int total;
  final String? subtitle;
  final int? streakDays;
  final VoidCallback? onTap;
  final VoidCallback? onContinue;

  double get progress => total <= 0 ? 0 : (memorized / total).clamp(0, 1).toDouble();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final percent = (progress * 100).round();
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textStyles.titleMedium),
                    if (subtitle != null) Text(subtitle!, style: context.textStyles.bodySmall),
                  ],
                ),
              ),
              Semantics(
                label: 'Horumar $percent boqolkiiba',
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(child: CircularProgressIndicator(value: progress, strokeWidth: 5)),
                      Text(
                        '$percent%',
                        style: context.textStyles.labelMedium?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(value: progress, minHeight: 8),
          ),
          AppSpacing.gapXs,
          Row(
            children: [
              Expanded(
                child: Text('$memorized / $total xadiis la xifdiyay', style: context.textStyles.bodySmall),
              ),
              if (streakDays != null) ...[
                Icon(Icons.local_fire_department_rounded, size: 16, color: c.warning),
                const SizedBox(width: AppSpacing.xxs),
                Text('$streakDays maalmood', style: context.textStyles.labelSmall),
              ],
            ],
          ),
          if (onContinue != null) ...[
            AppSpacing.gapMd,
            PrimaryButton(label: 'Sii wad xifdinta', icon: Icons.play_arrow_rounded, onPressed: onContinue),
          ],
        ],
      ),
    );
  }
}
