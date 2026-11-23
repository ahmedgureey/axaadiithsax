import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../features/about/presentation/about_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/books/presentation/book_detail_screen.dart';
import '../../features/books/presentation/books_screen.dart';
import '../../features/books/presentation/chapter_screen.dart';
import '../../features/design_system/design_system_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/hadith/presentation/hadith_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/memorization/presentation/daily_plan_screen.dart';
import '../../features/memorization/presentation/memorization_screen.dart';
import '../../features/memorization/presentation/memorize_hadith_screen.dart';
import '../../features/memorization/presentation/review_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/quiz/domain/quiz_models.dart';
import '../../features/quiz/presentation/quiz_play_screen.dart';
import '../../features/quiz/presentation/quiz_results_screen.dart';
import '../../features/quiz/presentation/quiz_screen.dart';
import '../../features/search/presentation/categories_screen.dart';
import '../../features/search/presentation/category_results_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/appearance_settings_screen.dart';
import '../../features/settings/presentation/help_screen.dart';
import '../../features/settings/presentation/language_settings_screen.dart';
import '../../features/settings/presentation/notification_settings_screen.dart';
import '../../features/settings/presentation/privacy_screen.dart';
import '../../features/settings/presentation/reading_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import 'app_routes.dart';
import 'main_shell.dart';
import 'not_found_screen.dart';

/// Route guard. Pure function so it can be unit-tested.
///
/// * `/splash` decides where to go itself.
/// * Onboarding is shown until completed.
/// * Privacy / About are readable by everyone (linked from registration).
/// * `/verify-email` only exists for a simulated, not-yet-verified session.
/// * Signed-out users may only see the auth flow.
/// * Signed-in users skip the auth flow. Guests may still open it (to log in).
String? appRedirect(AuthController auth, String location) {
  if (location == AppRoutes.splash) return null;

  if (!auth.onboardingSeen) {
    return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
  }
  if (location == AppRoutes.onboarding) {
    return auth.canUseApp ? AppRoutes.home : AppRoutes.welcome;
  }
  if (AppRoutes.publicRoutes.contains(location)) return null;

  // A password-recovery e-mail link was opened: choose a new password first.
  if (auth.isRecoveringPassword) {
    return location == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
  }

  if (location == AppRoutes.verifyEmail) {
    if (auth.isSignedIn && !auth.emailVerified) return null;
    if (auth.pendingVerificationEmail != null) return null; // "check your e-mail" after real sign-up
    return auth.canUseApp ? AppRoutes.home : AppRoutes.welcome;
  }

  final isAuthRoute = AppRoutes.authFlow.contains(location);
  if (!auth.canUseApp) return isAuthRoute ? null : AppRoutes.welcome;
  if (auth.isSignedIn && isAuthRoute) return AppRoutes.home;
  return null;
}

/// Where splash should go once it has finished.
String splashDestination(AuthController auth) {
  if (!auth.onboardingSeen) return AppRoutes.onboarding;
  return auth.canUseApp ? AppRoutes.home : AppRoutes.welcome;
}

GoRouter buildAppRouter(AppServices services, {String initialLocation = AppRoutes.splash}) {
  final auth = services.auth;

  GoRoute simple(String path, Widget Function(GoRouterState s) build) =>
      GoRoute(path: path, builder: (_, state) => build(state));

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    redirect: (context, state) => appRedirect(auth, state.matchedLocation),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      // Initial flow
      simple(AppRoutes.splash, (_) => const SplashScreen()),
      simple(AppRoutes.onboarding, (_) => const OnboardingScreen()),
      simple(AppRoutes.welcome, (_) => const WelcomeScreen()),

      // Demo auth
      simple(AppRoutes.login, (_) => const LoginScreen()),
      simple(AppRoutes.register, (_) => const RegisterScreen()),
      simple(AppRoutes.forgotPassword, (_) => const ForgotPasswordScreen()),
      simple(AppRoutes.resetPassword, (_) => const ResetPasswordScreen()),
      simple(AppRoutes.verifyEmail, (_) => const VerifyEmailScreen()),

      // Main app: five tabs with independent stacks
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [simple(AppRoutes.home, (_) => const HomeScreen())]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.books,
                builder: (_, _) => const BooksScreen(),
                routes: [
                  GoRoute(
                    path: ':${AppRoutes.bookIdParam}',
                    builder: (_, state) => BookDetailScreen(bookId: state.pathParameters[AppRoutes.bookIdParam] ?? ''),
                    routes: [
                      GoRoute(
                        path: 'chapters/:${AppRoutes.chapterIdParam}',
                        builder: (_, state) => ChapterScreen(
                          bookId: state.pathParameters[AppRoutes.bookIdParam] ?? '',
                          chapterId: state.pathParameters[AppRoutes.chapterIdParam] ?? '',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (_, state) => SearchScreen(
                  initialQuery: state.uri.queryParameters[AppRoutes.queryParam],
                  initialCategoryId: state.uri.queryParameters[AppRoutes.categoryQuery],
                  initialBookId: state.uri.queryParameters[AppRoutes.bookQuery],
                ),
                routes: [
                  GoRoute(
                    path: 'categories',
                    builder: (_, _) => const CategoriesScreen(),
                    routes: [
                      GoRoute(
                        path: ':${AppRoutes.categoryIdParam}',
                        builder: (_, state) =>
                            CategoryResultsScreen(categoryId: state.pathParameters[AppRoutes.categoryIdParam] ?? ''),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.memorization,
                builder: (_, _) => const MemorizationScreen(),
                routes: [
                  GoRoute(path: 'plan', builder: (_, _) => const DailyPlanScreen()),
                  GoRoute(path: 'review', builder: (_, _) => const ReviewScreen()),
                  GoRoute(
                    path: 'hadith/:${AppRoutes.hadithIdParam}',
                    builder: (_, state) =>
                        MemorizeHadithScreen(hadithId: state.pathParameters[AppRoutes.hadithIdParam] ?? ''),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: [simple(AppRoutes.profile, (_) => const ProfileScreen())]),
        ],
      ),

      // Full-screen routes (cover the bottom navigation)
      GoRoute(
        path: '/hadith/:${AppRoutes.hadithIdParam}',
        builder: (_, state) => HadithDetailScreen(hadithId: state.pathParameters[AppRoutes.hadithIdParam] ?? ''),
      ),
      simple(AppRoutes.favorites, (_) => const FavoritesScreen()),
      simple(AppRoutes.notifications, (_) => const NotificationsScreen()),
      GoRoute(
        path: AppRoutes.quiz,
        builder: (_, _) => const QuizScreen(),
        routes: [
          // `extra` is only present for in-app navigation; a refresh / deep
          // link gives null and the screens show a safe fallback.
          GoRoute(
            path: 'play',
            builder: (_, state) =>
                QuizPlayScreen(config: state.extra is QuizConfig ? state.extra! as QuizConfig : null),
          ),
          GoRoute(
            path: 'results',
            builder: (_, state) =>
                QuizResultsScreen(result: state.extra is QuizResult ? state.extra! as QuizResult : null),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(path: 'language', builder: (_, _) => const LanguageSettingsScreen()),
          GoRoute(path: 'appearance', builder: (_, _) => const AppearanceSettingsScreen()),
          GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsScreen()),
          GoRoute(path: 'privacy', builder: (_, _) => const PrivacyScreen()),
          GoRoute(path: 'reading', builder: (_, _) => const ReadingSettingsScreen()),
          GoRoute(path: 'help', builder: (_, _) => const HelpScreen()),
        ],
      ),
      simple(AppRoutes.about, (_) => const AboutScreen()),
      if (kDebugMode) simple(AppRoutes.designSystem, (_) => const DesignSystemScreen()),
    ],
  );
}
