import 'package:flutter/material.dart';

import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Notification preferences — UI only in this phase (nothing is scheduled
/// or persisted yet).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _daily = true;
  bool _memorization = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Ogeysiisyada', leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          const AppPageBody(
            child: FormValidationMessage(
              type: FormMessageType.info,
              message: 'UI tusaale ah: ogeysiis dhab ah lama diro, doorashadana lama keydiyo weli.',
            ),
          ),
          AppSpacing.gapMd,
          AppPageBody(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Xadiiska maanta'),
              subtitle: const Text('Xasuusin maalinle ah'),
              value: _daily,
              onChanged: (v) => setState(() => _daily = v),
            ),
          ),
          AppPageBody(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Xasuusinta xifdinta'),
              subtitle: const Text('Dib-u-eegista qorshahaaga'),
              value: _memorization,
              onChanged: (v) => setState(() => _memorization = v),
            ),
          ),
        ],
      ),
    );
  }
}
