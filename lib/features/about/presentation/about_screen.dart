import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_info.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/update/update_prompt.dart';
import '../../../core/widgets/widgets.dart';
import '../../splash/presentation/splash_screen.dart';

/// About: purpose, version (from pubspec via AppInfo) and what the app offers.
/// No invented developer, organisation, website or date.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const title = 'Ku saabsan';
  static String get versionLabel => 'Nooca ${AppInfo.version} (build ${AppInfo.buildNumber})';

  static const features = [
    (Icons.menu_book_rounded, '42 xadiis'),
    (Icons.translate_rounded, 'Carabi · Soomaali'),
    (Icons.search_rounded, 'Raadin'),
    (Icons.psychology_outlined, 'Xifdin'),
    (Icons.quiz_outlined, 'Imtixaan'),
    (Icons.cloud_off_outlined, 'Internet la\'aan'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleAbout), leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        children: [
          const AppLogo(),
          AppSpacing.gapSm,
          Center(
            child: MetaChip(label: versionLabel, icon: Icons.verified_outlined),
          ),
          AppSpacing.gapLg,
          AppPageBody(
            child: HonorificText(
              'Akhri, baro oo xifdi axaadiista Nabiga ﷺ.',
              style: context.textStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          AppSpacing.gapXl,
          AppPageBody(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.6,
              children: [
                for (final (icon, label) in features)
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(icon, color: context.appColors.goldText),
                        AppSpacing.gapSm,
                        Expanded(
                          child: Text(
                            label,
                            style: context.textStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          AppPageBody(
            child: SecondaryButton(
              label: 'Hubi cusboonaysiin',
              icon: Icons.system_update_rounded,
              onPressed: () => showUpdateCheck(context),
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
