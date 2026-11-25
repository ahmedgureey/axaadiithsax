# Xadiith App — Axaadiista Nabiga ﷺ

A Flutter app (Android / iOS, also runs on the web for development) for reading,
searching and memorising hadith with Somali translations.

> **Status: frontend only, demo data.** There is no backend, no real
> authentication and no verified hadith dataset yet. Every hadith record in
> `lib/data/mock_data/mock_library.dart` is placeholder text clearly labelled
> in the UI as *"Tusaale — lama xaqiijin"* (example, not verified). Replace it
> with a verified dataset before any public release.

## Features

| Area | What works | Demo / limited |
|---|---|---|
| Onboarding & auth | Splash, onboarding, welcome, login, register, forgot/reset password, e-mail verification screens with full validation | Auth is a **local demo**: credentials `demo@xadiis.app` / `Demo1234`; no server, no password stored |
| Home | Daily hadith (deterministic), Continue Reading (last opened hadith + position in its book), quick actions, today's memorisation progress, reading-reminder card, featured books, topics, recent reading | Reminder card reflects a saved preference; nothing is delivered |
| Library | Books → chapters → hadith list → hadith reader: Arabic RTL, Somali translation (show/hide), narrator/grade only when verified, Arabic + translation size and line spacing (in-reader sheet), position in book, previous/next (RTL-aware), bookmark, copy, share | Audio player shows "Cod lama hayo" (no audio available) |
| Search | Diacritic-insensitive Arabic + Somali search, clear button, filters (book, topic, saved / not saved) with reset, 4 sort orders, highlighted Somali matches, recent searches, categories | Arabic matches are not highlighted (matching ignores diacritics) |
| Favourites | Bookmark/unbookmark everywhere, synced across screens, persisted | — |
| Memorisation | Daily plan, "Waan Xifdiyey", spaced review (1/3/7/14/30 days), weekly chart, streak | — |
| Quiz | Generated questions from local data, one answer per question, score + history | — |
| Profile & settings | Demo profile (name edit), stats, theme (system/light/dark), language, Arabic/translation size and line height, help, privacy, about (version from pubspec), separate reset actions with confirmation | Language: Somali complete; Arabic/English translate the essential labels (navigation, screen titles, Home sections, reader controls, settings) + system strings, Arabic switches to RTL; longer explanatory text stays Somali. Notifications are **preferences only** — nothing is scheduled or delivered |

All user data (settings, favourites, memorisation, quiz history, recent
searches, reading history (ids only), demo session) is stored **only on the device** with
`shared_preferences`. There is no sync and no backup.

## Tech stack

- Flutter 3.47 / Dart 3.13, Material 3
- `go_router` (StatefulShellRoute with 5 tabs: Guriga, Kutubta, Raadinta, Xifdinta, Aniga)
- State: `ChangeNotifier` controllers exposed through `AppServices` (InheritedWidget)
- `shared_preferences` (local storage), `share_plus` (system share sheet), `flutter_localizations`
- Amiri font (SIL OFL 1.1) bundled in `assets/fonts/`

## Folder structure

```
lib/
  app/            App widget and AppServices (dependency container)
  core/           routing, theme, settings, l10n, shared widgets, utils, services
  data/           models, mock_data (demo dataset), repositories
  features/       one folder per feature (auth, home, books, hadith, search,
                  favorites, memorization, quiz, profile, settings, about, …)
test/             unit + widget tests mirroring lib/, plus test/qa/ release checks
docs/             original audit and plan (Somali)
```

## Getting started

```bash
flutter pub get
flutter run                     # connected device / emulator
flutter run -d chrome           # web, for quick UI work
```

## Supabase (optional, being connected)

The Supabase client (`lib/core/backend/supabase_backend.dart`) supplies the
**hadith catalogue** (books, chapters, hadith, topics) through
`lib/data/remote/remote_catalog.dart`: at start-up the app downloads it (6 s
timeout), caches it for offline reading, and falls back to the last download
or to the catalogue bundled with the app. Favourites, memorisation and
settings stay on the device.

**Accounts:** with Supabase configured, login / registration / password reset
use Supabase Auth (`lib/features/auth/supabase_auth_gateway.dart`); the demo
account is hidden. E-mail links return to the app via
`com.xadiithapp.app://login-callback` — add it under Authentication → URL
Configuration → Redirect URLs. Without `supabase.json` the local demo flow runs
(and the tests use it). Import tool for verified, licensed datasets: `tool/hadith_import/README.md`.

Database design (v2): `docs/BACKEND_DESIGN.md`. Migrations in
`supabase/migrations/2026112*_*.sql` (7 files: catalogue, users/roles, review
workflow, RLS, read API, import tracking, app read views) — **not applied yet**; apply on a dev branch first and
run `supabase/tests/v2_security_test.sql`. Records become public only after a
reviewer verifies and publishes them via `review_record()`. The app's data layer
reads v2 through `lib/data/remote/` (CatalogService + SupabaseCatalogApi): metadata at start, chapters page by page, details/favourites by id, server search, offline cache of published records, bookmark sync for signed-in accounts.

1. Copy `supabase.example.json` to `supabase.json` (git-ignored) and fill in the
   project URL and the **publishable** key (Project Settings → API Keys).
   Never use a `sb_secret_…` / `service_role` key in the app; it is refused at startup.
2. Run or build with the file:
   ```bash
   flutter run --dart-define-from-file=supabase.json
   flutter build apk --release --dart-define-from-file=supabase.json
   ```
   Without it the backend stays `notConfigured` and nothing changes.
3. Every table must have **Row Level Security** enabled before the app reads or
   writes it.

## Development commands

```bash
dart format lib test            # page width 120 (analysis_options.yaml)
flutter analyze
flutter test
flutter test test/qa            # release-readiness checks only
```

The test suite covers startup, navigation and redirects, form validation,
search, favourites, theme/language/font settings, memorisation, quiz scoring,
resets, empty states, overflow at 320×568 with 1.5× text, keyboard overlap and
Flutter's accessibility guidelines (tap targets, labels, contrast) in light
and dark mode.

## Android build

```bash
flutter build apk --debug
flutter build apk --release                  # universal APK (all CPUs, ~55 MB)
flutter build apk --release --split-per-abi  # one smaller APK per CPU (~17–21 MB)
```

Outputs are in `build/app/outputs/flutter-apk/`. For sharing, most phones need
`app-arm64-v8a-release.apk`; older 32-bit phones need `app-armeabi-v7a-release.apk`;
the universal `app-release.apk` works everywhere.

Notes:

- **Application ID:** `com.xadiithapp.app` (Kotlin namespace too). Do not change
  it after sharing: phones would treat it as a different app.
- **Release signing:** `android/app/build.gradle.kts` reads
  `android/key.properties` and signs with `android/app/upload-keystore.jks`.
  Both files are git-ignored and exist only on the developer's machine —
  **back them up**; without them no update can be installed over an existing
  copy. If `key.properties` is missing the release build falls back to the
  debug key and logs a warning; such an APK must not be shared.
  `key.properties` format:
  ```properties
  storePassword=…
  keyPassword=…
  keyAlias=upload
  storeFile=upload-keystore.jks
  ```
- Split APKs get per-CPU version codes (e.g. arm64 `2001`) while the universal
  APK uses `1`; stick to one kind when sharing, or Android may refuse an
  "older" version code as a downgrade.
- Icon: adaptive icon (`mipmap-anydpi-v26`, vector star on brand green, also
  monochrome for themed icons) plus PNGs for Android 7. The native launch
  screen uses the same green and star.
- `android/gradle.properties` sets `kotlin.incremental=false` because the pub
  cache (C:) and the project (D:) are on different drives, which breaks Kotlin's
  incremental cache on Windows. Remove it if both are on the same drive.

## iOS build

Requires macOS with Xcode and CocoaPods:

```bash
flutter build ios --release
```

Deployment target is iOS 15.0; display name is "Xadiith App". The bundle ID is
still `com.example.xadiithapp` and must be changed, and signing configured in
Xcode. iOS has not been built in this project's Windows environment.

## Current limitations / known issues

- Hadith content is demo placeholder text, not real hadith (see top note).
- No backend, no real accounts, no cloud sync or backup.
- Notifications are not delivered; no notification permission is requested.
- No hadith audio.
- Arabic and English UI translations cover essential labels only; explanatory copy is Somali.
- On the web build Flutter may download CanvasKit and fallback fonts from
  Google's CDN; Android/iOS builds make no network requests from app code.
- iOS bundle ID (`com.example.xadiithapp`) and iOS signing are not configured yet.

## Forced / optional updates

The Android app reads `update.json` from this repository at start-up
(`https://raw.githubusercontent.com/ahmedgureey/axaadiithsax/main/update.json`).

1. Build the new APK (bump `version:` in `pubspec.yaml`, e.g. `1.0.9+10`).
2. Upload the APK to a GitHub Release (or any https download link).
3. Edit `update.json` and push to `main`:
   - `latest_build`: the new build number (`+10`) → older apps see an optional "Cusboonaysii".
   - `min_build`: raise it to force: apps below it show a dialog that cannot be closed.
   - `apk_url`: the download link (https).

Offline phones are never blocked; the check is skipped.
