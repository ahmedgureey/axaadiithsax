import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_info.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../splash/presentation/splash_screen.dart';

/// About: purpose, version (from pubspec via AppInfo), honest disclaimer and
/// credits only for components actually used. No invented developer,
/// organisation, website or date.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const title = 'Ku saabsan';
  static String get versionLabel => 'Nooca ${AppInfo.version} (build ${AppInfo.buildNumber})';

  static const credits = [
    ('Flutter', 'Qalabka lagu dhisay app-ka'),
    ('go_router', 'Navigation'),
    ('shared_preferences', 'Kaydinta maxalliga ah'),
    ('share_plus', 'Wadaagista'),
    ('flutter_localizations', 'Qoraallada nidaamka ee luqadaha'),
    ('Amiri font', 'Font-ka Carabiga — The Amiri Project Authors (SIL OFL 1.1)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleAbout), leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        children: [
          const AppLogo(),
          AppSpacing.gapXs,
          Center(child: Text(versionLabel, style: context.textStyles.bodySmall)),
          AppSpacing.gapXl,
          AppPageBody(
            child: HonorificText(
              '${AppInfo.name} waxay kaa caawinaysaa inaad akhrido, barato oo xifdiso axaadiista Nabiga ﷺ, '
              'adigoo helaya qoraalka Carabiga iyo tarjumaad Af-Soomaali ah.',
              style: context.textStyles.bodyLarge,
            ),
          ),
          AppSpacing.gapLg,
          const AppPageBody(
            child: FormValidationMessage(
              type: FormMessageType.info,
              message:
                  'Xogta xadiiska ee noocan waa tusaale aan la xaqiijin. Mar walba ka hubi waxyaabaha diinta '
                  'ilo la isku halleyn karo iyo culimo.',
            ),
          ),
          AppSpacing.gapXl,
          AppPageBody(
            child: SettingsSection(
              title: 'Waxyaabaha la isticmaalay',
              children: [
                for (final (name, role) in credits) ListTile(dense: true, title: Text(name), subtitle: Text(role)),
              ],
            ),
          ),
          AppSpacing.gapLg,
          AppPageBody(
            child: SecondaryButton(
              label: 'Shatiyada (licenses)',
              icon: Icons.description_outlined,
              onPressed: () =>
                  showLicensePage(context: context, applicationName: AppInfo.name, applicationVersion: versionLabel),
            ),
          ),
          if (kDebugMode) ...[
            AppSpacing.gapSm,
            AppPageBody(
              child: AppTextButton(
                label: 'Design system (dev)',
                icon: Icons.palette_outlined,
                onPressed: () => context.push(AppRoutes.designSystem),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
