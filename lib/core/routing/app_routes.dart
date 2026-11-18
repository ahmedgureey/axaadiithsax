/// Central route definitions. Never hard-code route strings in widgets —
/// use these constants and builders.
abstract final class AppRoutes {
  // ── Initial flow ────────────────────────────────────────────────────────
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';

  // ── Demo authentication ─────────────────────────────────────────────────
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const verifyEmail = '/verify-email';

  // ── Main tabs (bottom navigation, in branch order) ───────────────────────
  static const home = '/home';
  static const books = '/books';
  static const search = '/search';
  static const memorization = '/memorization';
  static const profile = '/profile';

  // ── Full-screen feature routes (no bottom navigation) ───────────────────
  static const favorites = '/favorites';
  static const quiz = '/quiz';
  static const quizResults = '/quiz/results';
  static const settings = '/settings';
  static const settingsLanguage = '/settings/language';
  static const settingsAppearance = '/settings/appearance';
  static const settingsNotifications = '/settings/notifications';
  static const settingsPrivacy = '/settings/privacy';
  static const about = '/about';

  /// Debug-only living style guide (Phase 2).
  static const designSystem = '/dev/design-system';

  // ── Path parameter / query names ─────────────────────────────────────────
  static const bookIdParam = 'bookId';
  static const chapterIdParam = 'chapterId';
  static const hadithIdParam = 'hadithId';
  static const categoryQuery = 'category';

  // ── Builders for parameterised routes ────────────────────────────────────
  static String book(String bookId) => '$books/${Uri.encodeComponent(bookId)}';

  static String chapter(String bookId, String chapterId) =>
      '${book(bookId)}/chapters/${Uri.encodeComponent(chapterId)}';

  static String hadith(String hadithId) => '/hadith/${Uri.encodeComponent(hadithId)}';

  static String searchCategory(String categoryId) =>
      Uri(path: search, queryParameters: {categoryQuery: categoryId}).toString();

  /// Screens reachable while signed out.
  static const authFlow = {welcome, login, register, forgotPassword, resetPassword, verifyEmail};

  /// Branch index for each main tab path (used by tests and the shell).
  static const tabs = [home, books, search, memorization, profile];
}
