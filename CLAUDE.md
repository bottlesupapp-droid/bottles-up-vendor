# CLAUDE.md

Guidance for working in this repository (Bottles Up **Vendor** app).

## What this app is

Flutter app for venue owners, managers, organizers, door/server staff and similar roles. It shares one
Supabase project with the Bottles Up website and the customer app, so the **website's `site_*` schema and
edge functions are the source of truth**. Do not add a second source of truth for bookings or payments here.

- Bundle / application ID: `com.bottlesup.vendor` (iOS and Android must stay identical).
- Backend: **Supabase** (Auth, Postgres with RLS, Edge Functions). There is no Firebase in this app.
- Shared code lives in `../../packages/shared` (Supabase config, shared models).

## Commands

- `flutter pub get` after changing `pubspec.yaml`
- `flutter run` (debug, hot reload)
- `flutter test`: unit and widget tests (should be all green)
- `flutter analyze`: should report no errors; known warnings are unused imports
- `dart format .`
- `flutter build ios --simulator --debug` / `flutter build apk --release`

### Pointing a build at another Supabase project (e.g. staging)

```
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

With no defines the production project is used. Only ever put the **anon** key in the app, never `service_role`.

## Architecture

- **State:** `flutter_riverpod` with plain hand-written providers. `riverpod_annotation`, `riverpod_generator`
  and `freezed` are listed in `pubspec.yaml` but **nothing uses them**; do not assume generated code exists.
- **Models:** plain Dart classes with hand-written `fromJson` / `toJson` in `lib/shared/models/`.
- **Navigation:** `go_router` in `lib/core/router/app_router.dart`. Redirect order: auth, then the workspace
  layer (`features/workspace/logic/workspace_routing.dart`), then the legacy vendor rules.
- **Start-up:** `lib/main.dart` initialises Supabase; if that fails the user sees `StartupErrorApp`
  (retry screen), never a blank screen.
- **Theme:** dark only, orange primary, `flex_color_scheme` + Google Fonts (`lib/core/theme`).

```
lib/
├── core/        config, router, startup, theme, ui kit, utils
├── features/    analytics, auth, clubs, dashboard, events, profile, scanner, venues, workspace
└── shared/      models, services, widgets
```

### Workspaces (multi-role foundation)

`lib/features/workspace/` implements organizations, memberships and per-role navigation on top of the
tenancy tables in the website repo (`supabase/migrations/20261006120000_tenancy_foundation.sql`). A user can
belong to several workspaces and chooses one after sign-in (`/workspaces`); invitations are accepted at
`/accept-invite`. Role to navigation mapping is in `models/role_navigation.dart`.

### Archived code

Code removed to keep the app focused is in `_archive/` with a manifest and a restore script:
`_archive/restore.sh <path-prefix> [--dry-run]`. Read `_archive/README.md` first.

## Release checklist

- **Android signing:** release builds require `android/key.properties` (copy `android/key.properties.example`).
  Without it the build fails on purpose. For a throwaway local build set `ORG_GRADLE_PROJECT_allowUnsignedRelease=true`.
- **iOS signing:** the App ID `com.bottlesup.vendor` must be registered in the Apple Developer account.
- **Android permissions:** `INTERNET` is declared in the main manifest. Flutter only adds it to debug/profile
  builds on its own, so removing it breaks release builds completely.
- **Crash reporting:** not wired up yet (`_logError` in `main.dart` only prints). Add Sentry or similar before launch.
- **Privacy policy:** the in-app screen (`features/profile/screens/privacy_policy_screen.dart`) is generic
  boilerplate with placeholder company details; it needs real legal text before store submission.

## Stale files

The repo root holds many old status notes (`*_SUMMARY.md`, `*_FIX*.md`, `PRODUCTION_READY*.md`) and unused
Firebase config (`firebase.json`, `firestore.rules`, `.firebaserc`). They describe earlier work, not the current
state. Trust the code and this file.
