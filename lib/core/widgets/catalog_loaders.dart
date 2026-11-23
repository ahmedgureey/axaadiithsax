import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/remote/catalog_api.dart';
import '../../data/remote/catalog_service.dart';
import 'app_feedback.dart';
import 'app_form_fields.dart';

/// Rebuilds [builder] whenever the repository or the catalogue loader
/// changes (records arriving from the backend). Without a backend it just
/// listens to the repository.
class CatalogBuilder extends StatelessWidget {
  const CatalogBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([services.repository, ?services.catalog]),
      builder: (context, _) => builder(context),
    );
  }
}

/// Downloads the given records once when shown (favourites, history,
/// memorisation lists), then rebuilds. Shows nothing extra while loading;
/// reports a failure through [onFailure] state for the child to render.
class EnsureHadiths extends StatefulWidget {
  const EnsureHadiths({super.key, required this.ids, required this.builder});

  final List<String> ids;

  /// `failure` is non-null when the download failed (show it, with retry).
  final Widget Function(BuildContext context, bool loading, CatalogFailure? failure, VoidCallback retry) builder;

  @override
  State<EnsureHadiths> createState() => _EnsureHadithsState();
}

class _EnsureHadithsState extends State<EnsureHadiths> {
  bool _loading = false;
  CatalogFailure? _failure;
  String _requested = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(EnsureHadiths old) {
    super.didUpdateWidget(old);
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final catalog = context.services.catalog;
    final key = widget.ids.join(',');
    if (catalog == null || (!force && key == _requested)) return;
    _requested = key;
    setState(() {
      _loading = true;
      _failure = null;
    });
    final failure = await catalog.ensureHadiths(widget.ids);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) =>
      CatalogBuilder(builder: (context) => widget.builder(context, _loading, _failure, () => _load(force: true)));
}

/// Banner for list screens when the catalogue could not be refreshed.
class CatalogStatusBanner extends StatelessWidget {
  const CatalogStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.services.catalog;
    if (catalog == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) => switch (catalog.origin) {
        CatalogOrigin.cache => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FormValidationMessage(
            type: FormMessageType.info,
            message:
                'Offline: waxaa la muujinayaa xogtii ugu dambeysay ee la soo dejiyey. '
                '${catalog.startupFailure?.message ?? ''}',
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// Full-screen state when the backend is configured but nothing could be
/// loaded and nothing is cached.
class CatalogUnavailableState extends StatefulWidget {
  const CatalogUnavailableState({super.key});

  @override
  State<CatalogUnavailableState> createState() => _CatalogUnavailableStateState();
}

class _CatalogUnavailableStateState extends State<CatalogUnavailableState> {
  bool _retrying = false;

  @override
  Widget build(BuildContext context) {
    final catalog = context.services.catalog!;
    return ErrorStateWidget(
      title: 'Xogta lama soo dejin karo',
      message: catalog.startupFailure?.message ?? 'Fadlan isku day mar kale.',
      onRetry: _retrying
          ? null
          : () async {
              setState(() => _retrying = true);
              await catalog.start();
              if (mounted) setState(() => _retrying = false);
            },
    );
  }
}
