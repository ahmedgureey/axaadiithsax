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
flutter build apk --release
```

Notes:

- `android/gradle.properties` sets `kotlin.incremental=false` because the pub
  cache (C:) and the project (D:) are on different drives, which breaks Kotlin's
  incremental cache on Windows. Remove it if both are on the same drive.
- **Release signing:** `android/app/build.gradle.kts` still signs release builds
  with the debug key (Flutter template default). Before publishing, create an
  upload keystore and a `key.properties` (both are git-ignored).
- **Application ID** is still the template `com.example.xadiithapp`; choose the
  final ID before the first store upload (it cannot change afterwards).

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
- Release signing and application/bundle IDs are not configured (see above).
