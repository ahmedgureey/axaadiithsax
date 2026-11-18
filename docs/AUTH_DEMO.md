# Demo Authentication — Xadiis App

> ⚠️ **Frontend-only demonstration. Not real authentication. Not production-ready.**
> No backend, no network calls, no e-mails, no real accounts.

## Demo account (shown on the login screen)

| Email | Password |
|---|---|
| `demo@xadiis.app` | `Demo1234` |

The login screen also offers **"Buuxi xogta demo-ga"** (fill the fields) and
**"Tijaabi Demo-ga"** (one-tap demo sign-in). Any other credentials are rejected
with a friendly error — the app never pretends an arbitrary account was verified.

## Session states (`AuthController`, `lib/features/auth/auth_controller.dart`)

| State | How it starts | Shown as |
|---|---|---|
| `signedOut` | first launch, sign-out, reset | auth screens only |
| `guest` | "Sii wad adigoon gelin" | "Marti — akoon ma jiro" (never "logged in") |
| `signedIn`, unverified | demo registration | "Akoon demo · email lama xaqiijin" + "Xaqiiji email-ka (demo)" |
| `signedIn`, verified | demo login, or "Tijaabi Xaqiijinta" | "Email la xaqiijiyay (demo)" |

"Verified" only means the user tapped the simulated verification button.

## Flow

```
Splash ─► Onboarding (3 pages, first launch) ─► Welcome
Welcome ─► Gal Akoonka ─► Login ─► Home
        ─► Samee Akoon ─► Register ─► Xaqiiji Email-ka ─► Home
        ─► Sii wad adigoon gelin ─► Home (guest)
Login ─► Ilowday furaha? ─► Forgot (generic confirmation) ─► Reset (demo) ─► Login
```

- Login ⇄ Register links use `pushReplacement`, so Back never loops between them.
- Reset → Login uses `go`, replacing the auth stack.
- Leaving verification with "Ku noqo Gelitaanka" ends the unverified session.
- Privacy / About can be opened before signing in (terms link on Register).

## Validation rules

| Field | Rule |
|---|---|
| Email | required; `x@y.z` format; surrounding whitespace trimmed; case-insensitive for the demo match |
| Password | required; at least **8** characters (`AuthController.minPasswordLength`); **never trimmed** |
| Confirm password | required; must match exactly |
| Full name | required (non-blank) |
| Terms | checkbox must be ticked |

## What is stored locally (`shared_preferences`)

- `auth.onboardingSeen`, `auth.status`, `auth.displayName`, `auth.email`, `auth.emailVerified`.
- With **"I xasuuso" off**, the session lives in memory only (status stored as signed out).
- **Passwords are never stored or logged.** Typed passwords exist only in text
  controllers and are compared in memory against the published demo password.

## Resetting

Debug builds: **Aniga → Ku saabsan app-ka → "Dib u deji demo-ga (dev)"** clears
session and onboarding. In code: `AuthController.resetDemo()`.

## Limitations

- Anyone can read the demo password — it is intentionally public.
- Registered demo users cannot log back in after signing out (no password is kept).
- Forgot / reset / verify send nothing and change no server state.
- Before release, replace `AuthController` with a real provider behind the same
  API (`signIn`, `register`, `verifyEmail`, `signOut`) — UI and router guard can stay.
