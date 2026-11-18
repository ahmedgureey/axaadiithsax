# Navigation & Architecture — Xadiis App

Phase 3 · go_router 18.1.4 · built-in state (`ChangeNotifier`) · local mock data only.

## Folder structure

```
lib/
  main.dart                     # loads AppServices, registers font license, runApp
  app/
    app.dart                    # XadiisApp: MaterialApp.router + themes
    app_services.dart           # AppServices (all controllers + repository) + AppServicesScope
  core/
    routing/
      app_routes.dart           # ALL route paths + builders (never hard-code paths)
      app_router.dart           # GoRouter config, appRedirect() guard, splashDestination()
      main_shell.dart           # 5-tab shell (StatefulShellRoute.indexedStack)
      not_found_screen.dart     # NotFoundView / NotFoundScreen
      route_leading.dart        # back-or-home app bar button for deep links
    settings/                   # AppSettingsController (theme, Arabic size) + SettingsStore
    theme/  widgets/            # design system (Phase 2)
    utils/                      # arabic_normalizer.dart, category_icons.dart
  data/
    models/                     # Hadith, HadithBook, Chapter, HadithCategory
    mock_data/mock_library.dart # DEMO data — no real hadith text
    repositories/hadith_repository.dart
  features/<feature>/
    <feature>_controller.dart   # only where the feature owns state
    presentation/*_screen.dart
```

`books/domain`, `hadith/data` etc. were intentionally **not** created: all data
flows through the shared `HadithRepository`, so empty layers would add nothing.

## Routes

| Path | Screen | Bottom nav | Notes |
|---|---|---|---|
| `/splash` | SplashScreen | – | 1.2 s, then onboarding / welcome / home |
| `/onboarding` | OnboardingScreen | – | shown until completed (persisted) |
| `/welcome` | WelcomeScreen | – | Gal · Is diiwaangeli · Marti |
| `/login` `/register` `/forgot-password` `/reset-password` `/verify-email` | Auth (demo) | – | frontend validation only |
| `/home` | HomeScreen | tab 0 Guriga | |
| `/books` | BooksScreen | tab 1 Kutubta | |
| `/books/:bookId` | BookDetailScreen | tab 1 | invalid ID → not-found |
| `/books/:bookId/chapters/:chapterId` | ChapterScreen | tab 1 | chapter must belong to book |
| `/search?category=<id>` | SearchScreen | tab 2 Raadinta | unknown category ignored |
| `/memorization` | MemorizationScreen | tab 3 Xifdinta | |
| `/profile` | ProfileScreen | tab 4 Aniga | |
| `/hadith/:hadithId` | HadithDetailScreen | hidden | focused reading; invalid ID → not-found |
| `/favorites` | FavoritesScreen | hidden | |
| `/quiz` → `/quiz/results` | Quiz / Results | hidden | result passed via `extra`; missing → friendly state |
| `/settings` + `/language` `/appearance` `/notifications` `/privacy` | Settings | hidden | |
| `/about` | AboutScreen | hidden | license page |
| `/dev/design-system` | DesignSystemScreen | hidden | **debug builds only** |
| anything else | NotFoundScreen | – | `errorBuilder` |

## Guard (`appRedirect`)

1. `/splash` is never redirected.
2. Onboarding not completed → `/onboarding`.
3. `/settings/privacy` and `/about` are public (linked from registration).
4. `/verify-email` only for a simulated, unverified session (else → home / welcome).
5. Signed out → only the auth flow is reachable (everything else → `/welcome`).
6. Signed in (demo) → auth flow redirects to `/home`.
7. Guest → may use the app **and** open login/register.

See [AUTH_DEMO.md](AUTH_DEMO.md) for the demo account, states and limitations.

`refreshListenable: auth` re-runs the guard on sign-in/out.

## Navigation rules

- **Inside a tab** (book → chapter): `context.go(AppRoutes.chapter(...))` — builds the stack under that tab.
- **Full-screen detail** (hadith, favorites, settings, quiz): `context.push(...)` — back returns to the exact origin.
- **Switching tabs**: `navigationShell.goBranch(i)`; re-tapping the active tab returns to its root (no duplicates).
- **Android back**: pops within the tab → at a tab root other than Home goes to Home → on Home exits.
- **Deep links** to a full-screen route show a Home button when there is nothing to go back to.

## State separation

| Concern | Owner |
|---|---|
| Selected tab, stacks | GoRouter only |
| Theme, Arabic size | `AppSettingsController` (persisted) |
| Demo session, onboarding | `AuthController` (persisted, never stores passwords) |
| Favorites | `FavoritesController` (persisted) |
| Memorization progress | `MemorizationController` (in-memory this phase) |
| Recently viewed | `ReadingHistoryController` (in-memory) |
| Search query/filters | `SearchScreen` state (kept alive by IndexedStack) |
| Books / hadith data | `HadithRepository` (read-only, mock) |

## Tests

- `test/core/routing/navigation_test.dart` — flows, 5 tabs, tab state, back button, invalid IDs, auth demo.
- `test/core/routing/app_redirect_test.dart` — guard matrix, route builders.
- `test/data/hadith_repository_test.dart` — lookups, links, search, demo flags.
