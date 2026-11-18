import 'package:flutter/material.dart';

import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sections = [
      (
        'Xogta qalabkaaga',
        'Dejintaada, kuwa aad jeceshahay iyo horumarkaaga waxay ku kaydsan yihiin qalabkaaga oo keliya.',
      ),
      ('Server ma jiro', 'Noocan app-ka kuma xirna server. Xog shakhsi ah lagama diro meel kale.'),
      ('Akoonka', 'Galitaanka iyo is-diiwaangelinta waa tijaabo (demo). Furaha sirta ah lama kaydiyo.'),
      ('Tirtirista', 'Haddii aad app-ka tirtirto, xogta ku kaydsan qalabka waa la tirtiraa.'),
    ];
    return Scaffold(
      appBar: AppTopBar(title: 'Arrimaha gaarka ah', leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          for (final (title, body) in sections)
            AppPageBody(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.titleMedium),
                  AppSpacing.gapXxs,
                  Text(body, style: context.textStyles.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
