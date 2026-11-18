# Xadiis App — Axaadiista Nabiga ﷺ
## Warbixinta Audit-ka iyo Qorshaha Frontend-ka (Phase 1)

Taariikh: 2026-11-18 · Flutter 3.47.7 (stable) · Dart 3.13.5

---

## 1. Soo koobidda architecture-ka hadda jira

Mashruucu (`D:\Xadiithapp\xadiithapp`) waa **template cusub oo `flutter create` ah** oo aan wax laga beddelin.

| Qayb | Xaaladda hadda |
|---|---|
| `lib/` | Hal fayl oo keliya: `lib/main.dart` — counter demo (`MyApp`, `MyHomePage`) |
| `pubspec.yaml` | `cupertino_icons` keliya; dev: `flutter_test`, `flutter_lints ^6.0.0` |
| Navigation | Ma jiro — `home:` toos ah, router ma jiro |
| State management | `setState` keliya (counter) |
| Theme | `ColorScheme.fromSeed(Colors.deepPurple)`, light mode keliya |
| Assets / fonts | Ma jiraan (`assets:` iyo `fonts:` waa comment) |
| RTL / Arabic | Ma jiro; `flutter_localizations` lama darin |
| Tests | `test/widget_test.dart` — counter smoke test (wuu gudbaa) |
| `analysis_options.yaml` | `flutter_lints` + exclude platform folders |
| Platforms | android, ios, web, windows |
| Android | `com.example.xadiithapp`, AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1, Java 17, release = debug signing |
| iOS | Bundle `com.example.xadiithapp`, deployment target 15.0, SceneDelegate, Swift Package Manager |

Natiijada hubinta:
- `flutter analyze` → **No issues found**
- `flutter test` → **All tests passed (1/1)**

---

## 2. Features — kuwa jira iyo kuwa maqan

| # | Feature | Xaaladda |
|---|---|---|
| — | Flutter project skeleton (Android/iOS build-able) | **Complete** |
| — | Lint + analyzer config | **Complete** |
| 1 | Splash screen (native + Flutter) | Missing (native launch = default cad) |
| 2 | Onboarding | Missing |
| 3 | Welcome screen | Missing |
| 4–6 | Login / Register / Forgot password UI (demo) | Missing |
| 7 | Home screen | Missing |
| 8 | Hadith collections & books | Missing |
| 9 | Chapters & hadith lists | Missing |
| 10 | Hadith detail | Missing |
| 11 | Somali translation + references | Missing |
| 12 | Arabic + Somali search | Missing |
| 13 | Categories / topic filters | Missing |
| 14 | Favorites / bookmarks | Missing |
| 15 | Reading settings, Arabic font size | Missing |
| 16 | Copy & share | Missing |
| 17 | Audio player UI | Missing |
| 18 | Memorization plans & progress | Missing |
| 19 | Multiple-choice quiz | Missing |
| 20 | Quiz results & progress charts | Missing |
| 21 | User profile | Missing |
| 22 | Language settings | Missing |
| 23 | Light/Dark theme | Partially complete (Material 3 theme jira, dark ma jiro) |
| 24 | Notification preferences UI | Missing |
| 25 | Privacy & About | Missing |
| — | RTL / Arabic rendering | Missing |
| — | Somali locale support in Flutter | **Needs investigation** (eeg Risks) |

**Code la ilaalinayo:** dhammaan platform config (`android/`, `ios/`), `analysis_options.yaml`, `pubspec.yaml` qaabkiisa. `lib/main.dart` iyo `test/widget_test.dart` waa demo — waa la beddeli doonaa (sabab: waa counter template, ma laha wax app logic ah), laakiin tijaabada cusub ayaa la geli doonaa.

---

## 3. Errors iyo Risks

Ma jiraan compile errors, broken imports ama dependency conflicts. Risks-ka:

| Risk | Darnaanta | Talo |
|---|---|---|
| **Xog xadiis oo aan la xaqiijin** — app-ku waa diini; xadiis la abuuray ama grading khaldan waa khatar weyn | Sare | Demo data waa in lagu calaamadeeyo `isVerified: false` + banner "Xog tijaabo ah". Xogta dhabta ah waa in laga keenaa ilo la isku halleyn karo (tusaale sunnah.com dataset) oo tarjumaadda Soomaaliga ay xaqiijiyaan culimo. |
| **Somali (`so`) locale** — Flutter `GlobalMaterialLocalizations` ma taageerto `so` (Needs investigation) | Dhexe | Ku dar fallback `LocalizationsDelegate` (Material strings English/fallback) + strings-ka app-ka ee Soomaaliga ah via `gen_l10n` (ARB). |
| Arabic fonts lama bundle-garayn | Dhexe | Ku dar Amiri / Noto Naskh Arabic gudaha `assets/fonts/` (offline, OFL license) — ha isticmaalin network fonts. |
| `applicationId` / bundle ID = `com.example.*` | Dhexe (store-ka ayuu diidayaa) | Beddel ka hor release (tusaale `so.xadiis.app`). |
| Release build wuxuu isticmaalaa debug signing | Dhexe | Phase 12 — keystore dhab ah (ha galin repo). |
| App label = `xadiithapp` | Hoose | → "Xadiis App". |
| Ma jiro git repo | Dhexe | `git init` ka hor inta aan code la bilaabin si isbeddel kasta loo raaco. |
| `android/local.properties` waxay ku jirtaa folder-ka | Hoose | Waa `.gitignore` gudihiisa — hubi marka git la bilaabo. |
| Windows/Web platforms — loo baahan maaha | Hoose | Waa la dhaafi karaa; ha tirtirin hadda. |

---

## 4. Folder structure la soo jeediyay (feature-first)

```
lib/
  main.dart
  app/
    app.dart                 # MaterialApp.router, themes, locales
    router.dart              # GoRouter config + ShellRoute (bottom nav)
  core/
    theme/  app_colors.dart, app_typography.dart, app_theme.dart, app_spacing.dart
    widgets/ app_button.dart, app_search_field.dart, hadith_card.dart, book_card.dart,
             category_card.dart, loading_view.dart, empty_view.dart, error_view.dart,
             confirm_dialog.dart, app_scaffold.dart, arabic_text.dart, demo_badge.dart
    l10n/   app_so.arb, app_en.arb
    utils/  arabic_normalizer.dart, validators.dart
  data/
    models/  hadith.dart, hadith_book.dart, chapter.dart, category.dart, favorite.dart,
             memorization_plan.dart, quiz_question.dart, quiz_result.dart,
             user_profile.dart, app_settings.dart
    mock/    mock_books.dart, mock_hadiths.dart (ama assets/data/*.json)
    repositories/ hadith_repository.dart, favorites_repository.dart,
                  settings_repository.dart, auth_repository.dart (demo)
  features/
    splash/ onboarding/ auth/ home/ books/ hadith/ search/ categories/
    favorites/ memorization/ quiz/ profile/ settings/ about/
      (feature kasta: presentation/ screens + widgets, providers/)
assets/
  fonts/ (Amiri, NotoNaskhArabic)
  images/ (logo, onboarding)
  data/   (mock JSON)
test/
  unit/ widget/ golden/ (optional)
```

---

## 5. Design system

**Colors**

| Token | Light | Dark |
|---|---|---|
| primary (Islamic green) | `#0F5132` | `#4CAF7F` |
| onPrimary | `#FFFFFF` | `#00210F` |
| secondary / accent (soft gold) | `#C9A227` | `#E0C068` |
| background (warm cream) | `#FBF7EE` | `#101412` |
| surface / card | `#FFFFFF` | `#1A201C` |
| surfaceVariant | `#F2EBD9` | `#242B26` |
| text primary | `#1C1B18` | `#ECE7DB` |
| text secondary | `#5F5A4F` | `#B5AE9F` |
| error | `#B3261E` | `#F2B8B5` |
| success | `#2E7D32` | `#81C784` |

Dhammaan iskudarka text/background waa in ay gaaraan WCAG AA (4.5:1).

**Typography**
- Arabic: **Amiri** (matn-ka xadiiska), **Noto Naskh Arabic** (UI/cinwaanno). Size default 24–26sp, `height: 1.9`, `textDirection: TextDirection.rtl`, `textAlign: TextAlign.right`.
- Somali/Latin: system font ama **Noto Sans** — body 16sp, `height: 1.5`.
- Arabic font size waa la beddeli karaa (18–40sp) oo lagu kaydiyaa settings.
- Widget gaar ah `ArabicText` si RTL iyo font loo xakameeyo meel keliya. App-ka guud wuxuu ahaanayaa LTR (Somali), qaybaha Carabiga ayaa RTL ah.

**Spacing / shape:** 4-pt grid (4/8/12/16/24/32), radius 12 (cards), 24 (buttons/search), elevation hoose + border gold khafiif ah.

**Reusable components:** `AppPrimaryButton`, `AppSecondaryButton`, `AppSearchField`, `HadithCard`, `BookCard`, `CategoryCard`, `LoadingView`, `EmptyView`, `ErrorView`, `ConfirmDialog`, `AppBottomNav` (NavigationBar), `AppScaffold`, `ArabicText`, `DemoContentBadge`.

---

## 6. Navigation plan

**GoRouter** + `StatefulShellRoute.indexedStack` (tab kasta wuxuu hayaa stack-giisa iyo scroll position-kiisa).

```
/splash → (first launch) /onboarding → /welcome → /login | /register | /forgot-password
        → (demo session jira) /home

StatefulShellRoute (bottom nav):
  /home
  /books                    → /books/:bookId → /books/:bookId/chapters/:chapterId
  /search                   → /categories/:categoryId
  /memorize                 → /memorize/plan/:planId → /quiz/:quizId → /quiz/:quizId/result
  /profile                  → /settings, /settings/reading, /settings/language,
                              /settings/notifications, /favorites, /privacy, /about

Full-screen (shell ka baxsan): /hadith/:hadithId (laga furi karo tab kasta)
```

- Redirect: `redirect` callback wuxuu hubiyaa `onboardingSeen` iyo demo `isLoggedIn` (shared_preferences).
- Tabs: Home · Kutubta · Raadinta · Xifdinta · Profile.
- Deep links diyaar ayay noqonayaan mustaqbalka.

---

## 7. Data models (mock)

```dart
Hadith { id, bookId, chapterId, number, arabicText, somaliText, narrator?, grade?,
         categoryIds, reference, isVerified (bool), source? }
HadithBook { id, nameSomali, nameArabic, author, hadithCount, description, isVerified }
Chapter { id, bookId, number, titleSomali, titleArabic, hadithCount }
Category { id, nameSomali, nameArabic, icon }
Favorite { hadithId, addedAt, note? }
MemorizationPlan { id, title, hadithIds, dailyTarget, startDate, completedIds }
QuizQuestion { id, hadithId, question, options, correctIndex, explanation }
QuizResult { quizId, score, total, takenAt, answers }
UserProfile { id, name, email, joinedAt }   // demo
AppSettings { themeMode, locale, arabicFontSize, showTranslation, notificationsEnabled, reminderTime }
```

**Xeerka xogta:** wax xadiis ah, tixraac ama grading lama abuurayo. Demo-gu wuxuu isticmaali doonaa
placeholder qoraal ah oo si cad u leh "[Tusaale — lama xaqiijin]" (`isVerified: false`), UI-guna wuxuu tusi doonaa `DemoContentBadge`. Grading waxaa la tusayaa oo keliya marka `isVerified == true`.
Haddii aad rabto xog dhab ah, waa in aad keentaa dataset la xaqiijiyay + tarjumaad Soomaali ah oo culimo hubiyeen.

---

## 8. Roadmap (la waafajiyay xaaladda dhabta ah — project-ku waa madhan)

| Phase | Objectives | Files | Deps | Acceptance criteria | Tests |
|---|---|---|---|---|---|
| **1** Audit & planning | Warbixintan | `docs/AUDIT_AND_PLAN.md` | — | Approval-kaaga | — |
| **2** Design system & widgets | Colors, typography, theme light/dark, fonts, core widgets | `lib/core/theme/*`, `lib/core/widgets/*`, `assets/fonts/*`, `pubspec.yaml` | fonts (bundled) | Light+dark theme shaqeeya; Arabic RTL sax; widgets demo page | Widget tests: `ArabicText` RTL, buttons, empty/error views |
| **3** Navigation & architecture | GoRouter, shell 5 tabs, Riverpod, l10n (so/en/ar), settings persistence | `lib/app/*`, `lib/core/l10n/*`, `l10n.yaml` | go_router, flutter_riverpod, shared_preferences, flutter_localizations, intl | Tabs kala beddelmaan, stack la ilaaliyo, locale fallback Somali shaqeeya | Router tests, tab switching widget test |
| **4** Auth UI (demo) | Splash, onboarding, welcome, login, register, forgot password | `lib/features/{splash,onboarding,auth}/**`, `auth_repository.dart` | — | Form validation; demo login/logout; onboarding hal mar | Validator unit tests; form widget tests |
| **5** Home | Xadiis maalinle (demo), continue reading, quick links, categories | `lib/features/home/**` | — | Loading/empty/error states | Widget tests |
| **6** Books → Chapters → List → Detail | Models, mock data, repo, screens; copy/share | `lib/data/**`, `lib/features/{books,hadith}/**` | share_plus | Navigation buuxda; demo badge muuqda; copy/share | Repo unit tests, navigation widget tests |
| **7** Search & categories | Arabic normalization (tashkeel/alif), Somali search, filters | `lib/features/{search,categories}/**`, `arabic_normalizer.dart` | — | Raadin Carabi bilaa tashkeel ah ayaa natiijo keena | Normalizer unit tests, search widget test |
| **8** Favorites & reading | Favorites persist, reading settings, font size, audio player UI (mock) | `lib/features/{favorites,settings}/**` | (just_audio — dib u dhig ilaa audio dhab ah) | Favorites restart kadib way jiraan; font slider | Repo tests, widget tests |
| **9** Memorization & quiz | Plans, progress, MCQ quiz, results, charts | `lib/features/{memorization,quiz}/**` | fl_chart | Quiz score sax; progress chart | Quiz scoring unit tests |
| **10** Profile & settings | Profile, language, theme, notifications UI, privacy, about | `lib/features/{profile,settings,about}/**` | — | Theme/locale isla markiiba isbeddela oo la kaydiyo | Widget tests |
| **11** Testing & QA | Coverage, text scaling, RTL, dark mode, responsive | `test/**` | — | `flutter analyze` 0 issues; tests gudba | Full suite + manual device checks |
| **12** Cleanup & build-readiness | App name, bundle ID, icons, native splash, README, signing plan | `android/**`, `ios/**`, `README.md` | flutter_launcher_icons, flutter_native_splash (dev) | `flutter build apk` + `flutter build ios --no-codesign` way gudbaan | Build checks |

---

## 9. Testing & QA plan

- `flutter analyze` — 0 issues phase kasta kadib.
- **Unit:** models (fromJson/toJson), repositories, validators, Arabic normalizer, quiz scoring.
- **Widget:** core widgets, forms, navigation (tab switch, detail push/pop), states (loading/empty/error).
- **RTL:** `ArabicText` waa `TextDirection.rtl`; golden test ikhtiyaari ah.
- **Themes:** widget tests labada theme; contrast check.
- **Text scaling:** `MediaQuery(textScaler: TextScaler.linear(1.0 / 1.5 / 2.0))` — overflow ma jiro.
- **Responsive:** 320dp, 375dp, 412dp, tablet 768dp.
- **Accessibility:** `Semantics` labels on icon buttons, tap target ≥ 48dp.
- **Builds:** `flutter build apk --debug`; iOS waxay u baahan tahay macOS/Xcode (Windows kuma dhismi karo — Needs investigation: Mac ma heli kartaa?).

---

## 10. Dependencies la soo jeediyay

| Package | Sabab |
|---|---|
| `go_router` | Declarative routing, `StatefulShellRoute` bottom nav, redirect (auth/onboarding), deep links |
| `flutter_riverpod` | State management la tijaabin karo, ka fudud in la override-gareeyo tests-ka; kuma xirna `BuildContext` |
| `shared_preferences` | Kaydinta settings, favorites, onboarding flag, demo session (local keliya) |
| `flutter_localizations` (SDK) + `intl` | RTL, ARB strings Soomaali/English/Carabi |
| `share_plus` | Share action (copy = `Clipboard` SDK, dep looma baahna) |
| `fl_chart` | Progress charts (Phase 9) |
| Fonts bundled (Amiri, Noto Naskh Arabic) | Offline, ma u baahna `google_fonts` |
| dev: `flutter_launcher_icons`, `flutter_native_splash` | Phase 12 |
| Dib u dhig: `just_audio` | Kaliya marka audio dhab ah la helo; hadda UI mock ah |

La diiday: `google_fonts` (network), Firebase/auth packages (backend lama rabo), `get`/`bloc` (Riverpod ayaa ku filan).

---

## 11. Tallaabada xigta ee la soo jeediyay

1. `git init` + commit-ka koowaad ee template-ka (si isbeddel kasta loo raaco).
2. Go'aankaaga: (a) Riverpod vs Provider, (b) app ID-ga dhabta ah, (c) ilaha xogta xadiiska.
3. Bilow **Phase 2**: design system + fonts + core widgets, kadibna **Phase 3** navigation shell.
