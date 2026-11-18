import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';
import 'app_feedback.dart';

/// Search input with clear action and inline loading state.
/// Works for both Somali and Arabic queries (text direction follows the
/// typed characters automatically).
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hintText = 'Raadi xadiis, kitaab ama mawduuc…',
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    this.isLoading = false,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCleared;
  final bool isLoading;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _ownController;
  TextEditingController get _controller => widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _ownController = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onTextChanged);
      if (widget.controller == null) {
        _ownController ??= TextEditingController();
      }
      _controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _ownController?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget? suffix;
    if (widget.isLoading) {
      suffix = const Padding(
        padding: EdgeInsets.all(AppSpacing.sm + 2),
        child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_controller.text.isNotEmpty) {
      suffix = IconButton(
        tooltip: 'Tirtir raadinta',
        icon: const Icon(Icons.close_rounded),
        onPressed: _clear,
      );
    }

    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: context.textStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: suffix,
        border: const OutlineInputBorder(borderRadius: AppRadius.pillAll),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: context.colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: context.colors.primary, width: 1.6),
        ),
      ),
    );
  }
}

class SearchFilterOption<T> {
  const SearchFilterOption({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Horizontally scrolling filter chips (Dhammaan · Bukhaari · Muslim ...).
class SearchFilterChips<T> extends StatelessWidget {
  const SearchFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelectionChanged,
    this.multiSelect = false,
  });

  final List<SearchFilterOption<T>> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final bool multiSelect;

  void _toggle(T value) {
    final next = {...selected};
    if (multiSelect) {
      next.contains(value) ? next.remove(value) : next.add(value);
    } else {
      next
        ..clear()
        ..add(value);
    }
    onSelectionChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return SizedBox(
      height: AppSizes.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenPadding,
        itemCount: options.length,
        separatorBuilder: (_, _) => AppSpacing.gapXs,
        itemBuilder: (context, i) {
          final option = options[i];
          final isSelected = selected.contains(option.value);
          return Center(
            child: FilterChip(
              label: Text(option.label),
              avatar: option.icon == null
                  ? null
                  : Icon(
                      option.icon,
                      size: 16,
                      color: isSelected ? scheme.onPrimaryContainer : context.appColors.textSecondary,
                    ),
              selected: isSelected,
              onSelected: (_) => _toggle(option.value),
              side: BorderSide(color: isSelected ? scheme.primary : scheme.outlineVariant),
              labelStyle: context.textStyles.labelMedium?.copyWith(
                color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Empty result state for search.
class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({super.key, required this.query, this.onClear});

  final String query;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.search_off_rounded,
      title: 'Natiijo lama helin',
      message: 'Wax xadiis ah lagama helin "$query". Isku day eray kale ama ka saar shaandhaynta.',
      actionLabel: onClear == null ? null : 'Tirtir raadinta',
      onAction: onClear,
    );
  }
}

/// Loading placeholder for search results.
class SearchLoadingState extends StatelessWidget {
  const SearchLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const LoadingIndicator(message: 'Waa la raadinayaa…');
}
