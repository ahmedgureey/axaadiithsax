import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

class _Page {
  const _Page(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _pages = [
  _Page(
    Icons.auto_stories_rounded,
    'Akhri axaadiista',
    'Ka akhri axaadiista Nabiga ﷺ qoraalka Carabiga iyo tarjumaad Af-Soomaali ah.',
  ),
  _Page(Icons.search_rounded, 'Raadi si fudud', 'Ku raadi eray Carabi ama Soomaali ah, kitaab ama mawduuc.'),
  _Page(
    Icons.psychology_rounded,
    'Xifdi oo is tijaabi',
    'Samee qorshe xifdin, la soco horumarkaaga, oo ku celceli imtixaanno.',
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

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
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
              child: AppTextButton(label: 'Ka gudub', onPressed: _finish),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return AppPageBody(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              decoration: BoxDecoration(
                                color: context.colors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(page.icon, size: 56, color: context.colors.onPrimaryContainer),
                            ),
                            AppSpacing.gapXl,
                            Text(
                              page.title,
                              style: context.textStyles.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            AppSpacing.gapSm,
                            Text(page.body, style: context.textStyles.bodyLarge, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Semantics(
              label: 'Bogga ${_index + 1} ee ${_pages.length}',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
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
              child: PrimaryButton(label: _isLast ? 'Bilow' : 'Xiga', onPressed: _next),
            ),
          ],
        ),
      ),
    );
  }
}
