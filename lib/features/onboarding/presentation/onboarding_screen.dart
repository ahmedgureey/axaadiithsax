import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

class OnboardingPage {
  const OnboardingPage({required this.icon, required this.tag, required this.title, required this.body});
  final IconData icon;
  final String tag;
  final String title;
  final String body;
}

/// The three onboarding pages (texts as specified for the product).
const onboardingPages = [
  OnboardingPage(
    icon: Icons.auto_stories_rounded,
    tag: 'Baro Xadiiska',
    title: 'Baro Axaadiista Nabiga ﷺ',
    body:
        'Hel axaadiis aad ku baran karto sunnada Nabiga ﷺ, adigoo akhrinaya qoraalka Carabiga '
        'iyo tarjumaadda Af Soomaaliga.',
  ),
  OnboardingPage(
    icon: Icons.menu_book_rounded,
    tag: 'Akhri oo Faham',
    title: 'Akhri oo Faham',
    body:
        'Akhri axaadiista, faham macnahooda, oo eeg tixraacyada kutubta si aad aqoontaada '
        'u kobciso.',
  ),
  OnboardingPage(
    icon: Icons.psychology_rounded,
    tag: 'Xifdi oo Dib-u-eeg',
    title: 'Xifdi oo Dib-u-eeg',
    body: 'Samee qorshe xifdin, la soco horumarkaaga, kuna tijaabi aqoontaada su\'aalo gaagaaban.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  bool get _isLast => _index == onboardingPages.length - 1;

  /// Persists completion locally, then opens Welcome.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await context.services.auth.completeOnboarding();
    if (mounted) context.go(AppRoutes.welcome);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(duration: AppDurations.medium, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: AppTextButton(label: 'Ka gudub', onPressed: _finish),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: onboardingPages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _PageContent(page: onboardingPages[i]),
              ),
            ),
            Semantics(
              label: 'Bogga ${_index + 1} ee ${onboardingPages.length}',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < onboardingPages.length; i++)
                    AnimatedContainer(
                      duration: AppDurations.fast,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? context.colors.primary : context.appColors.divider,
                        borderRadius: AppRadius.pillAll,
                      ),
                    ),
                ],
              ),
            ),
            AppPageBody(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PrimaryButton(
                label: _isLast ? 'Bilow' : 'Xiga',
                icon: _isLast ? null : Icons.arrow_forward_rounded,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AppPageBody(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Widget-based illustration: no image assets required.
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.appColors.gold.withValues(alpha: 0.5)),
                ),
                child: ClipOval(
                  child: IslamicPatternBackground(
                    tile: 28,
                    child: Center(child: Icon(page.icon, size: 64, color: scheme.onPrimaryContainer)),
                  ),
                ),
              ),
              AppSpacing.gapXl,
              Text(
                page.tag.toUpperCase(),
                style: context.textStyles.labelMedium?.copyWith(
                  color: context.appColors.goldText,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapXs,
              Semantics(
                header: true,
                child: HonorificText(page.title, style: context.textStyles.headlineMedium, textAlign: TextAlign.center),
              ),
              AppSpacing.gapSm,
              HonorificText(page.body, style: context.textStyles.bodyLarge, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
