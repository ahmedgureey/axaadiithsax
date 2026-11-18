import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

/// Placeholder content for the gallery.
///
/// IMPORTANT: these strings are NOT hadith. They are layout placeholders that
/// describe where real, verified content will appear.
abstract final class _Demo {
  static const arabic =
      'هنا يظهر نص الحديث الشريف باللغة العربية مع التشكيل الكامل '
      'بعد التحقق منه من المصادر الموثوقة';
  static const narrator = 'اسم الراوي';
  static const somali =
      'Halkan waxaa ka muuqan doona tarjumaadda Af-Soomaaliga ee '
      'xadiiska, kadib marka laga xaqiijiyo ilo la isku halleyn karo.';
  static const source = 'Kitaab tusaale ah';
}

/// Living style guide for the design system. Temporary home screen until
/// Phase 3 wires real navigation; keep it afterwards as a dev-only route.
class DesignSystemScreen extends StatefulWidget {
  const DesignSystemScreen({super.key});

  @override
  State<DesignSystemScreen> createState() => _DesignSystemScreenState();
}

class _DesignSystemScreenState extends State<DesignSystemScreen> {
  final _formKey = GlobalKey<FormState>();
  int _navIndex = 0;
  bool _isFavorite = false;
  bool _buttonLoading = false;
  bool _searchLoading = false;
  Set<String> _filters = {'all'};

  Future<void> _fakeLoad() async {
    setState(() => _buttonLoading = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _buttonLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppTopBar(
        title: 'Xadiith App',
        subtitle: 'Design system',
        showOrnament: true,
        actions: [
          IconActionButton(
            icon: Icons.dark_mode_outlined,
            tooltip: 'Beddel muuqaalka',
            onPressed: () {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              settings.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          _section('Muuqaalka (Theme)', [
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Iftiin'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Mugdi'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
            AppSpacing.gapMd,
            Text(
              'Cabbirka qoraalka Carabiga: ${settings.arabicFontSize.round()}',
              style: context.textStyles.titleSmall,
            ),
            Slider(
              value: settings.arabicFontSize,
              min: ArabicFontSize.min,
              max: ArabicFontSize.max,
              divisions: (ArabicFontSize.max - ArabicFontSize.min).round() ~/ 2,
              label: settings.arabicFontSize.round().toString(),
              onChanged: settings.setArabicFontSize,
            ),
          ]),
          _section('Midabada', [const _ColorSwatches()]),
          _section('Qoraalka (Typography)', [
            Text('Display heading', style: context.textStyles.displaySmall),
            Text('Screen title', style: context.textStyles.headlineMedium),
            Text('Section heading', style: context.textStyles.titleLarge),
            Text('Card title', style: context.textStyles.titleMedium),
            Text('Qoraalka jirka ee Af-Soomaaliga — akhris raaxo leh.', style: context.textStyles.bodyLarge),
            Text('Qoraal labaad / sharraxaad', style: context.textStyles.bodySmall),
            Text('METADATA · TIXRAAC', style: context.textStyles.labelSmall),
            AppSpacing.gapMd,
            const ArabicText('عنوان الباب', variant: ArabicTextVariant.chapterHeading),
            const ArabicText(_Demo.narrator, variant: ArabicTextVariant.narrator),
            const ArabicText(_Demo.arabic),
            const OrnamentDivider(),
            Text(_Demo.somali, style: ArabicTextStyles.somaliTranslation(context)),
          ]),
          _section('Badhamada', [
            PrimaryButton(
              label: 'Gal',
              icon: Icons.login_rounded,
              onPressed: _fakeLoad,
              isLoading: _buttonLoading,
            ),
            AppSpacing.gapSm,
            SecondaryButton(label: 'Is diiwaangeli', onPressed: () {}),
            AppSpacing.gapSm,
            const PrimaryButton(label: 'Disabled', onPressed: null),
            AppSpacing.gapSm,
            // Wrap (not Row) so large text scales never overflow.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppTextButton(label: 'Ilowday furaha?', onPressed: () {}),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconActionButton(icon: Icons.copy_rounded, tooltip: 'Koobiyee', onPressed: () {}),
                    IconActionButton(
                      icon: Icons.play_arrow_rounded,
                      tooltip: 'Dhageyso',
                      filled: true,
                      onPressed: () {},
                    ),
                    IconActionButton(
                      icon: Icons.bookmark_border_rounded,
                      selectedIcon: Icons.bookmark_rounded,
                      isSelected: _isFavorite,
                      tooltip: 'Keydi',
                      onPressed: () => setState(() => _isFavorite = !_isFavorite),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          _section('Raadinta', [
            AppSearchField(
              isLoading: _searchLoading,
              onSubmitted: (_) async {
                setState(() => _searchLoading = true);
                await Future<void>.delayed(const Duration(seconds: 1));
                if (mounted) setState(() => _searchLoading = false);
              },
            ),
          ]),
          SearchFilterChips<String>(
            options: const [
              SearchFilterOption(value: 'all', label: 'Dhammaan'),
              SearchFilterOption(value: 'arabic', label: 'Carabi', icon: Icons.translate_rounded),
              SearchFilterOption(value: 'somali', label: 'Soomaali'),
              SearchFilterOption(value: 'books', label: 'Kutubta', icon: Icons.menu_book_rounded),
              SearchFilterOption(value: 'topics', label: 'Mawduucyada'),
            ],
            selected: _filters,
            onSelectionChanged: (s) => setState(() => _filters = s),
          ),
          _section('Kaararka', [
            DailyHadithCard(
              arabicText: _Demo.arabic,
              somaliText: _Demo.somali,
              source: _Demo.source,
              onTap: () {},
              onShare: () => AppSnackbar.show(context, 'Wadaagista waa tusaale'),
            ),
            AppSpacing.gapMd,
            HadithCard(
              arabicText: _Demo.arabic,
              somaliText: _Demo.somali,
              source: _Demo.source,
              narrator: _Demo.narrator,
              reference: 'Tixraac: —',
              isFavorite: _isFavorite,
              onTap: () {},
              onCopy: () => AppSnackbar.show(context, 'Waa la koobiyeeyay', type: AppSnackType.success),
              onShare: () {},
              onFavoriteToggle: () => setState(() => _isFavorite = !_isFavorite),
            ),
            AppSpacing.gapMd,
            const BookCard(
              titleSomali: 'Saxiix al-Bukhaari',
              titleArabic: 'صحيح البخاري',
              author: 'Imaam al-Bukhaari',
            ),
            AppSpacing.gapMd,
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                // Cell height grows with the user's text size.
                mainAxisExtent: MediaQuery.textScalerOf(context).scale(96) + 40,
              ),
              children: const [
                CategoryCard(title: 'Salaadda', icon: Icons.mosque_outlined, subtitle: 'Mawduuc'),
                CategoryCard(title: 'Akhlaaqda', icon: Icons.favorite_outline_rounded, isSelected: true),
              ],
            ),
            AppSpacing.gapMd,
            FavoriteHadithCard(
              arabicText: _Demo.arabic,
              somaliText: _Demo.somali,
              source: _Demo.source,
              savedLabel: 'Shalay',
              onRemove: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Ka saar?',
                  message: 'Xadiiskan waa laga saarayaa kuwa la jecel yahay.',
                  confirmLabel: 'Ka saar',
                  isDestructive: true,
                );
                if (ok && context.mounted) AppSnackbar.show(context, 'Waa laga saaray');
              },
            ),
            AppSpacing.gapMd,
            MemorizationProgressCard(
              title: 'Qorshaha xifdinta (tusaale)',
              subtitle: '2 xadiis maalintii',
              memorized: 12,
              total: 40,
              streakDays: 5,
              onContinue: () {},
            ),
          ]),
          _section('Foomamka', [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  const AppTextField(
                    label: 'Email',
                    hintText: 'tusaale@email.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: [AutofillHints.email],
                    validator: AppValidators.email,
                  ),
                  AppSpacing.gapMd,
                  const PasswordTextField(
                    helperText: 'Ugu yaraan 8 xaraf',
                    validator: AppValidators.password,
                  ),
                  AppSpacing.gapMd,
                  PrimaryButton(label: 'Hubi foomka', onPressed: () => _formKey.currentState?.validate()),
                ],
              ),
            ),
            AppSpacing.gapMd,
            const FormValidationMessage(message: 'Email-ka ama furaha sirta ah waa khalad.'),
            AppSpacing.gapXs,
            const FormValidationMessage(message: 'Waa la diray (tusaale).', type: FormMessageType.success),
          ]),
          _section('Xaaladaha (States)', [
            const SizedBox(height: 120, child: LoadingIndicator(message: 'Waa la soo rarayaa…')),
            const SizedBox(
              height: 320,
              child: EmptyStateWidget(
                icon: Icons.bookmark_border_rounded,
                title: 'Weli wax ma keydsan',
                message: 'Xadiisyada aad jeceshahay halkan ayay ka muuqan doonaan.',
              ),
            ),
            SizedBox(
              height: 320,
              child: SearchEmptyState(query: 'tusaale', onClear: () {}),
            ),
            SizedBox(height: 320, child: ErrorStateWidget(onRetry: () {})),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return AppPageBody(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: title),
            AppSpacing.gapMd,
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches();

  @override
  Widget build(BuildContext context) {
    final s = context.colors;
    final c = context.appColors;
    final swatches = <(String, Color, Color)>[
      ('Primary', s.primary, s.onPrimary),
      ('Primary container', s.primaryContainer, s.onPrimaryContainer),
      ('Surface', s.surface, s.onSurface),
      ('Card', s.surfaceContainerLowest, s.onSurface),
      ('Gold', c.gold, s.onSecondary),
      ('Success', c.success, s.surface),
      ('Warning', c.warning, s.surface),
      ('Error', s.error, s.onError),
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (name, bg, fg) in swatches)
          Container(
            width: 100,
            height: 56,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: c.divider),
            ),
            alignment: Alignment.bottomLeft,
            child: Text(name, style: context.textStyles.labelSmall?.copyWith(color: fg)),
          ),
      ],
    );
  }
}
