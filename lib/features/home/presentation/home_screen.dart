import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/hadith.dart';
import '../home_feed.dart';
import 'widgets/daily_hadith_section.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/home_progress_section.dart';
import 'widgets/home_search_shortcut.dart';
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
  Hadith? _serverDaily;
  bool _dailyRequested = false;

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Refresh button: rebuilds the feed from the current data (and asks the
  /// server again for the hadith of the day when a backend is used), then
  /// returns to the top.
  Future<void> _refresh() async {
    setState(() => _failed = false);
    await _loadServerDaily();
    if (!mounted) return;
    if (_scroll.hasClients) {
      await _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    if (mounted) AppSnackbar.show(context, 'Waa la cusboonaysiiyay', type: AppSnackType.success);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dailyRequested) {
      _dailyRequested = true;
      _loadServerDaily();
    }
  }

  /// Backend: the hadith of the day is chosen by the server, so it is the
  /// same for everyone and exists in the published data.
  Future<void> _loadServerDaily() async {
    final catalog = context.services.catalog;
    if (catalog == null) return;
    final h = await catalog.daily(DateTime.now());
    if (mounted && h != null) setState(() => _serverDaily = h);
  }

  /// Rebuilt whenever records arrive. A failure (e.g. a corrupt dataset)
  /// shows a friendly error with retry instead of a raw exception.
  void _load() {
    try {
      _feed = HomeFeed.build(context.services.repository, DateTime.now(), daily: _serverDaily);
      _failed = false;
    } catch (error) {
      debugPrint('Home feed failed to load: $error');
      _feed = null;
      _failed = true;
    }
  }

  @override
  Widget build(BuildContext context) => CatalogBuilder(builder: _build);

  Widget _build(BuildContext context) {
    if (!_failed) _load();
    final feed = _feed;
    return Scaffold(
      appBar: HomeAppBar(onRefresh: _refresh),
      body: feed == null
          ? ErrorStateWidget(
              title: 'Xogta lama soo rari karin',
              message: 'Fadlan isku day mar kale.',
              onRetry: () => setState(() => _failed = false),
            )
          : ListView(
              controller: _scroll,
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxl),
              children: [
                const AppPageBody(child: HomeSearchShortcut()),
                AppSpacing.gapLg,
                AppPageBody(child: DailyHadithSection(hadith: feed.daily)),
                AppSpacing.gapXl,
                const AppPageBody(child: HomeMemorizationSummary()),
                AppSpacing.gapXl,
                AppPageBody(child: RecentHadithsSection(featured: feed.featuredHadiths)),
              ],
            ),
    );
  }
}
