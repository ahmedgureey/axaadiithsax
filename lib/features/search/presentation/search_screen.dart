import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/widgets/widgets.dart';
import '../../hadith/presentation/hadith_preview_card.dart';

/// Tab 3 — Raadinta. Search state lives in this screen; the tab's
/// IndexedStack keeps it alive when switching tabs.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialCategoryId});

  /// From `/search?category=<id>`; ignored if the ID is unknown.
  final String? initialCategoryId;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _all = '';
  final _controller = TextEditingController();
  String _query = '';
  String _bookId = _all;
  String _categoryId = _all;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _applyCategory(widget.initialCategoryId);
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategoryId != oldWidget.initialCategoryId) {
      _applyCategory(widget.initialCategoryId);
    }
  }

  void _applyCategory(String? id) {
    final valid = context.services.repository.categoryById(id) != null;
    _categoryId = valid ? id! : _all;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasCriteria => _query.trim().isNotEmpty || _bookId != _all || _categoryId != _all;

  void _reset() {
    _controller.clear();
    setState(() {
      _query = '';
      _bookId = _all;
      _categoryId = _all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.services.repository;
    final results = _hasCriteria
        ? repo.search(
            _query,
            bookId: _bookId == _all ? null : _bookId,
            categoryId: _categoryId == _all ? null : _categoryId,
          )
        : const [];

    Widget body;
    if (!_hasCriteria) {
      body = const EmptyStateWidget(
        icon: Icons.manage_search_rounded,
        title: 'Raadi xadiis',
        message: 'Ku qor eray Carabi ama Soomaali ah, ama dooro kitaab ama mawduuc.',
      );
    } else if (results.isEmpty) {
      body = SearchEmptyState(query: _query.isEmpty ? '—' : _query, onClear: _reset);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        itemCount: results.length + 1,
        separatorBuilder: (_, _) => AppSpacing.gapMd,
        itemBuilder: (context, i) {
          if (i == 0) {
            return AppPageBody(
              child: Text('${results.length} natiijo', style: context.textStyles.labelMedium),
            );
          }
          return AppPageBody(child: HadithPreviewCard(hadith: results[i - 1]));
        },
      );
    }

    return Scaffold(
      appBar: const AppTopBar(title: 'Raadinta', showOrnament: true),
      body: Column(
        children: [
          AppPageBody(
            child: AppSearchField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v),
              onCleared: () => setState(() => _query = ''),
            ),
          ),
          AppSpacing.gapSm,
          SearchFilterChips<String>(
            options: [
              const SearchFilterOption(value: _all, label: 'Kutubta oo dhan'),
              for (final b in repo.books) SearchFilterOption(value: b.id, label: b.nameSomali),
            ],
            selected: {_bookId},
            onSelectionChanged: (s) => setState(() => _bookId = s.first),
          ),
          SearchFilterChips<String>(
            options: [
              const SearchFilterOption(value: _all, label: 'Mawduuc kasta'),
              for (final c in repo.categories)
                SearchFilterOption(value: c.id, label: c.nameSomali, icon: categoryIcon(c.iconKey)),
            ],
            selected: {_categoryId},
            onSelectionChanged: (s) => setState(() => _categoryId = s.first),
          ),
          AppSpacing.gapSm,
          Expanded(child: body),
        ],
      ),
    );
  }
}
