import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../splash/presentation/splash_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0 (demo)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Ku saabsan', leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        children: [
          const AppLogo(),
          AppSpacing.gapXs,
          Center(child: Text('Nooca $version', style: context.textStyles.bodySmall)),
          AppSpacing.gapXl,
          const AppPageBody(
            child: FormValidationMessage(
              type: FormMessageType.info,
              message:
                  'Xogta xadiiska ee noocan waa tusaale aan la xaqiijin. '
                  'Ha u isticmaalin tixraac diineed ilaa xog la xaqiijiyay lagu daro.',
            ),
          ),
          AppSpacing.gapLg,
          AppPageBody(
            child: Text(
              'Xadiis App waxay kaa caawinaysaa inaad akhrido, raadiso oo xifdiso axaadiista Nabiga ﷺ, '
              'adigoo helaya tarjumaad Af-Soomaali ah.',
              style: context.textStyles.bodyLarge,
            ),
          ),
          AppSpacing.gapXl,
          AppPageBody(
            child: SecondaryButton(
              label: 'Shatiyada (licenses)',
              icon: Icons.description_outlined,
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Xadiis App',
                applicationVersion: version,
              ),
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
