import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../home_feed.dart';

/// "Kutubta Xadiithka" — horizontally scrolling collection cards.
class FeaturedBooksSection extends StatelessWidget {
  const FeaturedBooksSection({super.key, required this.books});

  final List<FeaturedBook> books;

  static const cardWidth = 236.0;

  @override
  Widget build(BuildContext context) {
    // Row height grows with the user's text size so cards never overflow.
    final height = 84 + MediaQuery.textScalerOf(context).scale(148);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageBody(
          child: SectionHeader(
            title: 'Kutubta Xadiithka',
            actionLabel: 'Eeg dhammaan',
            onAction: () => context.go(AppRoutes.books),
          ),
        ),
        AppSpacing.gapSm,
        if (books.isEmpty)
          AppPageBody(child: Text('Kutub lama helin.', style: context.textStyles.bodySmall))
        else
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: books.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) => SizedBox(
                width: cardWidth,
                child: _BookTile(item: books[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.item});

  final FeaturedBook item;

  @override
  Widget build(BuildContext context) {
    final book = item.book;
    final c = context.appColors;
    return AppCard(
      onTap: () => context.go(AppRoutes.book(book.id)),
      semanticLabel:
          '${book.nameSomali}, ${item.hasContent ? '${item.hadithCount} xadiis${book.isDemo ? ' tusaale ah' : ''}' : 'weli lama darin'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: c.gold.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.auto_stories_rounded, color: context.colors.onPrimaryContainer, size: AppSizes.icon),
          ),
          AppSpacing.gapSm,
          Text(book.nameSomali, style: context.textStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ArabicText(book.nameArabic, variant: ArabicTextVariant.label, maxLines: 1),
          AppSpacing.gapXxs,
          Flexible(
            child: Text(
              book.description,
              style: context.textStyles.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          MetaChip(
            label: item.hasContent ? '${item.hadithCount} xadiis${book.isDemo ? ' (tusaale)' : ''}' : 'Weli lama darin',
            icon: item.hasContent ? Icons.menu_book_outlined : Icons.hourglass_empty_rounded,
            color: item.hasContent ? context.colors.primary : c.warning,
          ),
        ],
      ),
    );
  }
}
