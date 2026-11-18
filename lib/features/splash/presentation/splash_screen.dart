import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Brief brand screen, then routes to onboarding / welcome / home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const duration = Duration(milliseconds: 1200);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.duration, () {
      if (!mounted) return;
      context.go(splashDestination(context.services.auth));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: AppLogo(large: true)));
  }
}

/// App mark: gold star + name + Arabic subtitle.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Xadiis App, Axaadiista Nabiga',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: context.appColors.gold.withValues(alpha: 0.6)),
            ),
            child: IslamicStar(size: large ? 48 : 36),
          ),
          AppSpacing.gapMd,
          Text(
            'Xadiis App',
            style: large ? context.textStyles.displaySmall : context.textStyles.headlineMedium,
          ),
          AppSpacing.gapXxs,
          const SizedBox(
            width: 260,
            child: ArabicText(
              'أحاديث النبي ﷺ',
              variant: ArabicTextVariant.chapterHeading,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
