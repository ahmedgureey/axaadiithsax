import 'package:flutter/material.dart';

import '../../../core/routing/route_leading.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Short how-to guide. There is no support channel yet, so none is shown.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const title = 'Caawimaad';

  static const topics = <(IconData, String, String)>[
    (
      Icons.search_rounded,
      'Sidee xadiis u helaa?',
      'Fur tab-ka "Raadinta", ku qor eray Carabi ama Soomaali ah, ama dooro mowduuc. '
          'Badhanka shaandhaynta wuxuu kuu oggolaanayaa inaad doorato kitaab ama mowduuc.',
    ),
    (
      Icons.bookmark_add_outlined,
      'Sidee xadiis u keydiyaa?',
      'Riix calaamadda keydinta (🔖) ee xadiis kasta. Kuwa la keydiyay waxaad ka heli kartaa '
          '"Aniga → Xadiisyada aan Kaydiyey".',
    ),
    (
      Icons.text_increase_rounded,
      'Sidee u weyneeyaa qoraalka Carabiga?',
      'Bogga xadiiska ku isticmaal A− / A+, ama Dejinta → Doorbidyada akhriska.',
    ),
    (
      Icons.psychology_outlined,
      'Sidee u sameeyaa qorshe xifdin?',
      'Tab-ka "Xifdinta" dooro inta xadiis ee maalintii, kadibna riix "Bilow qorshaha maanta". '
          'Xadiiska aad xifdisay wuxuu ku soo noqonayaa dib-u-eegis 1, 3, 7… maalmood kadib.',
    ),
    (
      Icons.quiz_outlined,
      'Sidee imtixaan u galaa?',
      'Xifdinta → "Imtixaan". Dooro tirada su\'aalaha iyo mowduuca. Su\'aal kasta hal jawaab ayaa la bixin karaa.',
    ),
    (
      Icons.palette_outlined,
      'Sidee u beddelaa luqadda iyo muuqaalka?',
      'Aniga → Dejinta. Halkaas ka dooro iftiin, mugdi ama nidaamka, iyo luqadda.',
    ),
    (
      Icons.science_outlined,
      'Maxay ka dhigan tahay "tusaale" ama "demo"?',
      'Xadiisyada noocan waa xog tusaale ah oo aan la xaqiijin. Galitaanka waa tijaabo, ogeysiisyadu waa '
          'doorbid oo keliya, codkuna weli ma jiro. Dhammaan xogtaadu waxay ku jirtaa qalabkan.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: context.tr(AppText.titleHelp), leading: backOrHomeLeading(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          for (final (icon, question, answer) in topics)
            AppPageBody(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  leading: Icon(icon, color: context.appColors.goldText),
                  title: Text(question, style: context.textStyles.titleSmall),
                  shape: const Border(),
                  childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(answer, style: context.textStyles.bodyMedium)],
                ),
              ),
            ),
          AppPageBody(
            child: Text('Weli ma jiro kanaal taageero (email ama website).', style: context.textStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
