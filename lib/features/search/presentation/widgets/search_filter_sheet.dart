import 'package:flutter/material.dart';

import '../../../../app/app_services.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/search_options.dart';

/// Opens the filter sheet. Returns the new filters on "Codso", or null if
/// dismissed (the current query and filters are untouched either way).
Future<SearchFilters?> showSearchFilterSheet(BuildContext context, SearchFilters current) {
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SearchFilterSheet(initial: current),
  );
}

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({required this.initial});

  final SearchFilters initial;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late SearchFilters _draft = widget.initial;

  Set<String> _toggle(Set<String> set, String id) => set.contains(id) ? ({...set}..remove(id)) : {...set, id};

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final search = services.search;
    final hasBackend = services.catalog != null;
    // Chapters are offered only within the selected collections.
    final chapters = [for (final id in _draft.bookIds) ...services.repository.chaptersOf(id)];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Text('Shaandhaynta', style: context.textStyles.titleLarge),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Label('Kitaabka'),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final b in search.filterableBooks)
                        FilterChip(
                          label: Text(b.nameSomali),
                          selected: _draft.bookIds.contains(b.id),
                          onSelected: (_) => setState(() {
                            final books = _toggle(_draft.bookIds, b.id);
                            // Drop chapters of collections that are no longer selected.
                            final repo = services.repository;
                            _draft = _draft.copyWith(
                              bookIds: books,
                              chapterIds: {
                                for (final id in _draft.chapterIds)
                                  if (books.contains(repo.chapterById(id)?.bookId)) id,
                              },
                            );
                          }),
                        ),
                    ],
                  ),
                  if (chapters.isNotEmpty) ...[
                    AppSpacing.gapLg,
                    const _Label('Cutubka'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final ch in chapters)
                          FilterChip(
                            label: Text(ch.titleSomali, maxLines: 1, overflow: TextOverflow.ellipsis),
                            selected: _draft.chapterIds.contains(ch.id),
                            onSelected: (_) =>
                                setState(() => _draft = _draft.copyWith(chapterIds: _toggle(_draft.chapterIds, ch.id))),
                          ),
                      ],
                    ),
                  ],
                  AppSpacing.gapLg,
                  const _Label('Mowduuca'),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final c in search.categories)
                        FilterChip(
                          label: Text('${c.nameSomali} (${search.countForCategory(c.id)})'),
                          selected: _draft.categoryIds.contains(c.id),
                          onSelected: (_) =>
                              setState(() => _draft = _draft.copyWith(categoryIds: _toggle(_draft.categoryIds, c.id))),
                        ),
                    ],
                  ),
                  if (hasBackend) ...[
                    AppSpacing.gapLg,
                    const _Label('Darajada (culimada la diiwaangeliyay)'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final g in searchableGrades.entries)
                          FilterChip(
                            label: Text(g.value),
                            selected: _draft.grades.contains(g.key),
                            onSelected: (_) =>
                                setState(() => _draft = _draft.copyWith(grades: _toggle(_draft.grades, g.key))),
                          ),
                      ],
                    ),
                    AppSpacing.gapXxs,
                    Text('Kaliya darajooyin culimo iyo tixraac leh.', style: context.textStyles.bodySmall),
                  ],
                  AppSpacing.gapMd,
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tarjumaad Soomaali leh oo keliya'),
                    value: _draft.translatedOnly,
                    onChanged: (v) => setState(() => _draft = _draft.copyWith(translatedOnly: v)),
                  ),
                  AppSpacing.gapMd,
                  const _Label('Kuwa la keydiyay'),
                  SegmentedButton<BookmarkFilter>(
                    showSelectedIcon: false,
                    segments: [
                      for (final f in BookmarkFilter.values)
                        ButtonSegment(
                          value: f,
                          label: Text(f.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    selected: {_draft.bookmark},
                    onSelectionChanged: (s) => setState(() => _draft = _draft.copyWith(bookmark: s.first)),
                  ),
                  AppSpacing.gapMd,
                  Text(
                    hasBackend
                        ? 'Shaandhaynta weriyaha weli ma jirto.'
                        : 'Weriyaha iyo darajada weli lama shaandheyn karo.',
                    style: context.textStyles.bodySmall,
                  ),
                  AppSpacing.gapMd,
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Dib u deji',
                      onPressed: () => setState(() => _draft = SearchFilters.none),
                    ),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: PrimaryButton(label: 'Codso', onPressed: () => Navigator.of(context).pop(_draft)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Semantics(header: true, child: Text(text, style: context.textStyles.titleSmall)),
  );
}
