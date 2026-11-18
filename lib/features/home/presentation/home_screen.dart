import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../home_feed.dart';
import 'widgets/daily_hadith_section.dart';
import 'widgets/featured_books_section.dart';
import 'widgets/hadith_categories_section.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/home_progress_section.dart';
import 'widgets/home_search_shortcut.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/recent_hadiths_section.dart';

/// Tab 1 — Guriga. The bottom navigation comes from the main shell.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeFeed? _feed;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_feed == null && !_failed) _load();
  }

  /// Local data is synchronous; a failure (e.g. a corrupt dataset) shows a
  /// friendly error with retry instead of a raw exception.
  void _load() {
    try {
      _feed = HomeFeed.build(context.services.repository, DateTime.now());
      _failed = false;
    } catch (error) {
      debugPrint('Home feed failed to load: $error');
      _feed = null;
      _failed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    return Scaffold(
      appBar: const HomeAppBar(),
      body: feed == null
          ? ErrorStateWidget(
              title: 'Xogta lama soo rari karin',
              message: 'Fadlan isku day mar kale.',
              onRetry: () => setState(_load),
            )
          : ListView(
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxl),
              children: [
                const AppPageBody(child: HomeSearchShortcut()),
                AppSpacing.gapLg,
                AppPageBody(child: DailyHadithSection(hadith: feed.daily)),
                AppSpacing.gapXl,
                const AppPageBody(child: ContinueReadingCard()),
                const AppPageBody(child: QuickActionsSection()),
                AppSpacing.gapXl,
                const AppPageBody(child: HomeMemorizationSummary()),
                AppSpacing.gapMd,
                const AppPageBody(child: ReadingReminderCard()),
                AppSpacing.gapXl,
                FeaturedBooksSection(books: feed.books),
                AppSpacing.gapXl,
                AppPageBody(child: HadithCategoriesSection(categories: feed.categories)),
                AppSpacing.gapXl,
                AppPageBody(child: RecentHadithsSection(featured: feed.featuredHadiths)),
              ],
            ),
    );
  }
}
