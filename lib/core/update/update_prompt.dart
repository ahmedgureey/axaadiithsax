import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_services.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';
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
    await showDialog<void>(
      context: context,
      barrierDismissible: info.kind != UpdateKind.required,
      builder: (_) => _UpdateDialog(info: info),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  Future<void> _open(BuildContext context) async {
    final ok = await launchUrl(info.downloadUrl, mode: LaunchMode.externalApplication).catchError((Object _) => false);
    if (!ok && context.mounted) {
      AppSnackbar.show(context, 'Link-ga lama furi karo: ${info.downloadUrl}', type: AppSnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final required = info.kind == UpdateKind.required;
    return PopScope(
      canPop: !required,
      child: AlertDialog(
        icon: Icon(Icons.system_update_rounded, color: context.colors.primary, size: 40),
        title: Text(required ? UpdatePrompt.requiredTitle : UpdatePrompt.optionalTitle, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.message, textAlign: TextAlign.center),
            if (info.version.isNotEmpty) ...[
              AppSpacing.gapSm,
              MetaChip(label: 'Nooca ${info.version}', icon: Icons.new_releases_outlined),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!required)
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(UpdatePrompt.laterLabel)),
          FilledButton.icon(
            onPressed: () => _open(context),
            icon: const Icon(Icons.download_rounded),
            label: const Text(UpdatePrompt.updateLabel),
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
            onPressed: () =>
                launchUrl(info.downloadUrl, mode: LaunchMode.externalApplication).catchError((Object _) => false),
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
