import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Brand screen shown at start-up, then routes to onboarding / welcome /
/// home. Services are already loaded in `main()` (with a safe fallback), so
/// no backend call or long animation happens here.
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
      context.go(splashDestination(context.services.onboarding));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = scheme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? scheme.primaryContainer : scheme.tertiary,
      body: IslamicPatternBackground(
        color: context.appColors.gold.withValues(alpha: 0.08),
        child: const SafeArea(child: Center(child: AppLogo(large: true, onDark: true))),
      ),
    );
  }
}

/// App mark: gold eight-pointed star, name and Somali subtitle.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.large = false, this.onDark = false});

  final bool large;

  /// Use light text for placement on the deep-green brand background.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final gold = context.appColors.gold;
    final titleColor = onDark
        ? (scheme.brightness == Brightness.dark ? scheme.onPrimaryContainer : scheme.onTertiary)
        : scheme.onSurface;
    final titleStyle = (large ? context.textStyles.displaySmall : context.textStyles.headlineMedium)?.copyWith(
      color: titleColor,
    );
    return Semantics(
      label: 'Xadiith App, Axaadiista Nabiga',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: onDark ? Colors.transparent : scheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: gold.withValues(alpha: onDark ? 0.8 : 0.6), width: 1.5),
            ),
            child: IslamicStar(size: large ? 48 : 36, color: gold),
          ),
          AppSpacing.gapMd,
          Text('Xadiith App', style: titleStyle, textAlign: TextAlign.center),
          AppSpacing.gapXxs,
          HonorificText(
            'Axaadiista Nabiga ﷺ',
            textAlign: TextAlign.center,
            style: context.textStyles.titleMedium?.copyWith(
              color: onDark ? gold : context.appColors.goldText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
