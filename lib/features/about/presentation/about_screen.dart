import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_info.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../splash/presentation/splash_screen.dart';

/// About: purpose, version (from pubspec via AppInfo) and what the app offers.
/// No invented developer, organisation, website or date.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const title = 'Ku saabsan';
  static String get versionLabel => 'Nooca ${AppInfo.version} (build ${AppInfo.buildNumber})';

  static const features = [
    (Icons.menu_book_rounded, 'Al-Arbaciin an-Nawawiyya', '42 xadiis oo Carabi ah iyo tarjumaaddooda Af-Soomaaliga'),
    (Icons.search_rounded, 'Raadin', 'Ku raadi eray Carabi ama Soomaali ah'),
    (Icons.psychology_outlined, 'Xifdin iyo imtixaan', 'Qorshe xifdin maalinle ah iyo su\'aalo'),
    (Icons.bookmarks_outlined, 'Kaydin', 'Xadiisyada aad jeceshahay ku keydso'),
    (Icons.cloud_off_outlined, 'Internet la\'aan', 'Wuu shaqeeyaa internet la\'aan, akoonna looma baahna'),
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
              '${AppInfo.name}: akhri, baro oo xifdi axaadiista Nabiga ﷺ — Carabi iyo tarjumaad Af-Soomaali ah.',
              style: context.textStyles.bodyLarge,
            ),
          ),
          AppSpacing.gapLg,
          AppPageBody(
            child: SettingsSection(
              title: 'Waxa app-ka ku jira',
              children: [
                for (final (icon, name, detail) in features)
                  ListTile(
                    dense: true,
                    leading: Icon(icon, color: context.appColors.goldText),
                    title: Text(name),
                    subtitle: Text(detail),
                  ),
              ],
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
