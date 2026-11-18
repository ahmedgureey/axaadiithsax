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
  static const memorizationPlan = '/memorization/plan';
  static const memorizationReview = '/memorization/review';
  static String memorizeHadith(String hadithId) => '/memorization/hadith/${Uri.encodeComponent(hadithId)}';
  static const profile = '/profile';

  // ── Full-screen feature routes (no bottom navigation) ───────────────────
  static const favorites = '/favorites';
  static const notifications = '/notifications';
  static const quiz = '/quiz';
  static const quizResults = '/quiz/results';
  static const quizPlay = '/quiz/play';
  static const settings = '/settings';
  static const settingsLanguage = '/settings/language';
  static const settingsAppearance = '/settings/appearance';
  static const settingsNotifications = '/settings/notifications';
  static const settingsPrivacy = '/settings/privacy';
  static const settingsReading = '/settings/reading';
  static const help = '/settings/help';
  static const about = '/about';

  /// Debug-only living style guide (Phase 2).
  static const designSystem = '/dev/design-system';

  // ── Path parameter / query names ─────────────────────────────────────────
  static const bookIdParam = 'bookId';
  static const chapterIdParam = 'chapterId';
  static const hadithIdParam = 'hadithId';
  static const categoryQuery = 'category';
  static const queryParam = 'q';
  static const bookQuery = 'book';

  // ── Builders for parameterised routes ────────────────────────────────────
  static String book(String bookId) => '$books/${Uri.encodeComponent(bookId)}';

  static String chapter(String bookId, String chapterId) =>
      '${book(bookId)}/chapters/${Uri.encodeComponent(chapterId)}';

  static String hadith(String hadithId) => '/hadith/${Uri.encodeComponent(hadithId)}';

  static String searchCategory(String categoryId) => searchWith(categoryId: categoryId);

  /// Search tab with optional prefilled query and filters.
  static String searchWith({String? query, String? categoryId, String? bookId}) {
    final params = {
      if (query != null && query.trim().isNotEmpty) queryParam: query.trim(),
      categoryQuery: ?categoryId,
      bookQuery: ?bookId,
    };
    return Uri(path: search, queryParameters: params.isEmpty ? null : params).toString();
  }

  /// "Mowduucyada Xadiiska" (inside the Raadinta tab).
  static const categories = '$search/categories';
  static const categoryIdParam = 'categoryId';
  static String categoryResults(String categoryId) => '$categories/${Uri.encodeComponent(categoryId)}';

  /// Screens reachable while signed out.
  static const authFlow = {welcome, login, register, forgotPassword, resetPassword, verifyEmail};

  /// Informational pages readable before signing in (linked from registration).
  static const publicRoutes = {settingsPrivacy, about};

  /// Branch index for each main tab path (used by tests and the shell).
  static const tabs = [home, books, search, memorization, profile];
}
