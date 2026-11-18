import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Describes what the app ACTUALLY does with data (checked against the
/// current code and dependencies: go_router, shared_preferences, share_plus,
/// flutter_localizations — none of them send analytics).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const title = 'Arrimaha gaarka ah';

  static const sections = <(IconData, String, String)>[
    (
      Icons.phone_android_rounded,
      'Waxa qalabkan lagu kaydiyo',
      'Dejinta (theme, luqadda, cabbirrada qoraalka), doorbidyada ogeysiisyada, xadiisyada aad keydisay '
          '(lambarrada id-ga oo keliya), horumarka xifdinta iyo dib-u-eegista, natiijooyinka imtixaannada, '
          'raadintii dhowayd, iyo session-ka demo-ga (magaca iyo email-ka aad gelisay). '
          'Furaha sirta ah marnaba lama kaydiyo.',
    ),
    (
      Icons.cloud_off_rounded,
      'Server iyo akoon',
      'Noocan kuma xirna server ama adeeg akoon. Galitaanka iyo is-diiwaangelintu waa tijaabo (demo); '
          'xogtaada qalabka lagama diro meel kale.',
    ),
    (Icons.analytics_outlined, 'Raadraac iyo analytics', 'App-ka kuma jiro wax analytics, xayeysiis ama raadraac ah.'),
    (
      Icons.share_outlined,
      'Wadaagista',
      'Marka aad riixdo "La wadaag", qoraalka xadiiska waxaa loo gudbiyaa app-ka aad adigu dooratid. '
          'Wax kale lama diro.',
    ),
    (
      Icons.language_rounded,
      'Nooca web-ka (browser)',
      'Marka app-ka lagu furo browser, Flutter wuxuu internet ka soo dejin karaa qaybo matoor ah (CanvasKit) '
          'iyo font-yo dheeraad ah oo ka yimaada adeegyada Google. Nooca Android iyo iOS koodka app-ku '
          'ma sameeyo codsiyo internet.',
    ),
    (
      Icons.delete_outline_rounded,
      'Sida xogta loo tirtiro',
      'Dejinta → Dib-u-dejin → "Tirtir dhammaan xogta qalabka", ama ka saar app-ka telefoonka.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: title, leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          for (final (icon, heading, body) in sections)
            AppPageBody(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: _PrivacyInformationCard(icon: icon, title: heading, body: body),
            ),
          AppPageBody(
            child: Text(
              'Qoraalkani wuxuu sharxayaa nooca hadda ee app-ka. Ma aha siyaasad sharci ah oo la xaqiijiyay.',
              style: context.textStyles.bodySmall,
            ),
          ),
          AppSpacing.gapSm,
          AppPageBody(
            child: AppTextButton(
              label: 'Ku noqo Dejinta',
              icon: Icons.settings_outlined,
              onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.settings),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyInformationCard extends StatelessWidget {
  const _PrivacyInformationCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.appColors.goldText),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: context.textStyles.titleSmall)),
              AppSpacing.gapXxs,
              Text(body, style: context.textStyles.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}
