import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_services.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';
import 'apk_installer.dart';
import 'update_checker.dart';

/// Checks for a new version once per app start and shows:
/// * required update → a dialog that cannot be closed (back button and
///   outside taps do nothing) with only "Cusboonaysii";
/// * optional update → a dialog with "Marka dambe" and "Cusboonaysii".
/// Nothing is shown when offline or when no check is configured.
class UpdatePrompt extends StatefulWidget {
  const UpdatePrompt({super.key, required this.child});

  final Widget child;

  static const requiredTitle = 'Cusboonaysiin waa qasab';
  static const optionalTitle = 'Nooc cusub ayaa diyaar ah';
  static const updateLabel = 'Cusboonaysii';
  static const laterLabel = 'Marka dambe';
  static const retryLabel = 'Isku day mar kale';
  static const browserLabel = 'Ka fur browser-ka';
  static const downloadingLabel = 'Waa la soo dejinayaa…';
  static const installingLabel = 'Rakibaadda ayaa furmaysa…';
  static const downloadFailedMessage = 'Soo dejintu way guuldareysatay. Hubi internetka kadibna isku day mar kale.';
  static const permissionMessage =
      'Oggolow "Ku rakib apps-ka" (Install unknown apps) ee Xadiith App, '
      'kadib dib u soo noqo oo riix "Cusboonaysii" mar kale.';

  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<UpdatePrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final services = context.services;
    final checker = services.updateChecker;
    if (checker == null || services.updateCheckDone) return;
    services.updateCheckDone = true;
    final info = await checker.check();
    if (info == null || !mounted) return;
    await showUpdateDialog(context, info);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows the update dialog for [info] (also used by "Hubi cusboonaysiin").
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) => showDialog<void>(
  context: context,
  barrierDismissible: info.kind != UpdateKind.required,
  builder: (_) => _UpdateDialog(info: info),
);

enum _Phase { idle, downloading, installing, needsPermission, failed }

/// On Android the APK is downloaded inside the app (with progress) and
/// Android's installer opens directly — no browser. Elsewhere, or when the
/// in-app download fails, the link opens in the browser.
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Phase _phase = _Phase.idle;
  double? _progress;
  String? _error;

  /// Downloaded file, reused after the user allowed installs in Settings.
  String? _file;

  UpdateInfo get info => widget.info;

  Future<void> _openInBrowser() async {
    final ok = await launchUrl(info.downloadUrl, mode: LaunchMode.externalApplication).catchError((Object _) => false);
    if (!ok && mounted) {
      AppSnackbar.show(context, 'Link-ga lama furi karo: ${info.downloadUrl}', type: AppSnackType.error);
    }
  }

  Future<void> _update() async {
    final installer = context.services.apkInstaller;
    if (installer == null) return _openInBrowser();
    try {
      var file = _file;
      if (file == null) {
        setState(() {
          _phase = _Phase.downloading;
          _progress = 0;
          _error = null;
        });
        file = await installer.download(info.downloadUrl, (p) {
          if (mounted) setState(() => _progress = p);
        });
        _file = file;
      }
      if (!mounted) return;
      setState(() => _phase = _Phase.installing);
      final result = await installer.install(file);
      if (!mounted) return;
      setState(() => _phase = result == ApkInstallResult.needsPermission ? _Phase.needsPermission : _Phase.idle);
    } on ApkInstallException catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.failed;
          _error = e.message;
        });
      }
    } catch (e) {
      debugPrint('In-app update failed: $e');
      if (mounted) {
        setState(() {
          _phase = _Phase.failed;
          _error = UpdatePrompt.downloadFailedMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final required = info.kind == UpdateKind.required;
    final busy = _phase == _Phase.downloading || _phase == _Phase.installing;
    final percent = _progress == null ? null : (_progress! * 100).round();
    return PopScope(
      canPop: !required && !busy,
      child: AlertDialog(
        icon: Icon(Icons.system_update_rounded, color: context.colors.primary, size: 40),
        title: Text(required ? UpdatePrompt.requiredTitle : UpdatePrompt.optionalTitle, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(info.message, textAlign: TextAlign.center),
            if (info.version.isNotEmpty) ...[
              AppSpacing.gapSm,
              Center(
                child: MetaChip(label: 'Nooca ${info.version}', icon: Icons.new_releases_outlined),
              ),
            ],
            if (_phase == _Phase.downloading) ...[
              AppSpacing.gapMd,
              ClipRRect(
                borderRadius: AppRadius.pillAll,
                child: LinearProgressIndicator(value: _progress, minHeight: 8),
              ),
              AppSpacing.gapXs,
              Text(
                percent == null ? UpdatePrompt.downloadingLabel : '${UpdatePrompt.downloadingLabel} $percent%',
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall,
              ),
            ],
            if (_phase == _Phase.installing) ...[
              AppSpacing.gapMd,
              Text(UpdatePrompt.installingLabel, textAlign: TextAlign.center, style: context.textStyles.bodySmall),
            ],
            if (_phase == _Phase.needsPermission) ...[
              AppSpacing.gapMd,
              const FormValidationMessage(type: FormMessageType.info, message: UpdatePrompt.permissionMessage),
            ],
            if (_phase == _Phase.failed && _error != null) ...[
              AppSpacing.gapMd,
              FormValidationMessage(type: FormMessageType.error, message: _error!),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!required && !busy)
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(UpdatePrompt.laterLabel)),
          if (_phase == _Phase.failed)
            TextButton(onPressed: _openInBrowser, child: const Text(UpdatePrompt.browserLabel)),
          FilledButton.icon(
            onPressed: busy ? null : _update,
            icon: busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_phase == _Phase.failed ? Icons.refresh_rounded : Icons.download_rounded),
            label: Text(_phase == _Phase.failed ? UpdatePrompt.retryLabel : UpdatePrompt.updateLabel),
          ),
        ],
      ),
    );
  }
}

/// "Hubi cusboonaysiin": checks now and shows what was found — the
/// installed build, the values in update.json, and the result or the exact
/// problem — so a missing update prompt can be explained.
Future<void> showUpdateCheck(BuildContext context) async {
  final checker = context.services.updateChecker ?? UpdateChecker();
  AppSnackbar.show(context, 'Waa la hubinayaa…');
  final report = await checker.report();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  final info = report.info;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        report.problem != null
            ? Icons.wifi_off_rounded
            : info == null
            ? Icons.verified_rounded
            : Icons.system_update_rounded,
        color: dialogContext.colors.primary,
        size: 40,
      ),
      title: const Text('Hubi cusboonaysiin', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(report.summary, textAlign: TextAlign.center, style: dialogContext.textStyles.titleSmall),
          AppSpacing.gapMd,
          _ReportRow('App-kaaga (build)', '${report.currentBuild}'),
          _ReportRow('GitHub: nooca ugu dambeeyay', report.latestBuild?.toString() ?? '—'),
          _ReportRow('GitHub: ugu yaraan (qasab)', report.minBuild?.toString() ?? '—'),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Xir')),
        if (info != null)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showUpdateDialog(context, info);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text(UpdatePrompt.updateLabel),
          ),
      ],
    ),
  );
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: context.textStyles.bodySmall)),
        Text(value, style: context.textStyles.titleSmall),
      ],
    ),
  );
}
