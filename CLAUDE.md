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

### Door scanner (first screens on the website's functions)

`lib/features/door/` is the door role's **Scan** and **Guests** tabs, built on the website's database functions instead of the
legacy tables: `door_events`, `door_scan_ticket`, `door_verify_ticket_code`, `door_guests` (defined in the website repo's
`supabase/migrations/20261009100000_door_scanner.sql`). They check in the database that the signed-in person holds a door
role for the event, so the app decides nothing about who may admit whom. Only the door role gets them
(`builtSectionFor` in `workspace_section_screen.dart`); a server's Scan tab is for table bookings and stays a placeholder, and Door
Sales is not built.

- `logic/door_rules.dart`: pure rules (what each answer means and its wording, when a camera read is acted on, reading rows).
  The wording is the website's, word for word; a test compares them when the website repo is checked out next to this one.
- `services/door_service.dart`: the calls. A scan never throws: a failure becomes an outcome ("access ended", "scan failed").
  Loading events or guests throws `DoorLoadException`, with "not set up on this server yet" when the migration is missing.
- Only "Admit" is green. The camera keeps running while an answer shows (the screen just stops acting on it); the same ticket
  held up again within five seconds is not counted twice; typing a code is always checked. After an admission the count of
  guests in is read again from the database.
- **Needs the website migrations applied to the Supabase project.** Until then the tabs say "not set up on this server yet".
  This was not run against a real database (there is no staging); behaviour is covered by tests with a fake backend and was
  looked at on a throwaway web build. **Try the camera on a real phone before relying on it at a door**: the test browser
  blocks it, so only the "camera unavailable, type the code" path has been exercised.
- The old scanner (`features/scanner`, `shared/services/check_in_service.dart`) still reads the legacy tables for the classic
  vendor dashboard and is untouched.

### Manager Floor (bookings on the website's functions)

`lib/features/floor/` is the manager's **Floor** tab: the reservations of the manager's own club, night by night, read only, from
the website's `list_venue_bookings(p_venue, p_from, p_to)` (website repo, `20261011100000_venue_bookings.sql`). The database
checks the person owns or manages THAT venue, decides which business night each booking belongs to (a slot before 06:00 is the
night before), and answers for at most 93 nights and 1000 rows; the app only shows it.

- `logic/bookings_rules.dart` ports the website's `bookingsView.ts`: what each stored status means (an unknown status is never
  "confirmed"), grouping by night, the counts, the ready-made ranges (Tonight, Next 7, Next 30, Last 7) in business nights, range
  validation. Night arithmetic uses calendar dates, not "minus 24 hours", so clock-change days are right. Tests compare the
  cutoff, limits, status wording and messages with the website repo when it is checked out beside this one.
- Amounts are **what was booked, not what was collected** (the deposit and total on the booking). Money received, cancellation
  detail and bottle orders live in production-only columns that no committed migration defines, so they are not shown until
  `supabase db pull` brings them into the website repo. The screen says so.
- Not here yet: walk-ins, guest allowances, table assignment, table check-in, bottle orders (the manager's **Orders** tab).
- **Needs the website migrations applied** (tenancy for the manager's workspace, then the venue bookings one). Until then it says
  "not set up on this server yet". Not run against a real database: there is no staging.
- Run the tests under a timezone with daylight saving at least once (`TZ=America/Toronto flutter test test/floor`): a machine in a
  zone without it cannot show the clock-change mistakes the night arithmetic guards against.

### Owner Home and Venues (venues on the website's functions)

`lib/features/owner/` is the owner's **Home** and **Venues** tabs, plus a page for one venue. They read the website's
`my_venues()`, `venue_setup_status(p_venue)` and `create_org_venue(p_org, p_name)`, and the venue's name/slug/address from
`site_venues` (row level security limits that to venues the person can reach). Nothing here decides who may see or do what.

- **Home:** tonight across every venue of the business (confirmed bookings, guests expected, arrived, awaiting payment), by the
  business night, from the same `list_venue_bookings` read as the manager's Floor. A venue that cannot be read is said so and the totals
  are marked incomplete. Sales, collections, balances and events are not available and the screen says so.
- **Venues:** each venue with Live or Draft and how far it is set up (the database's checklist; only required steps count), and
  "Add a venue". Tapping one pushes `/w/{membership}/venues/{venueId}` (defined once in `workspace/workspace_routes.dart`, used by the
  app's router and by the tests): tabs **Bookings** (the Floor screen for that venue), **Setup** (the checklist) and **Link** (the
  booking address, Copy, Preview for a live venue, and a QR code).
- Rules are ports of the website's `venueSetup.ts` and `bookingLink.ts`; tests compare labels, order, the default site, the slug rule and
  the function and argument names with the website repo when it is checked out beside this app. `--dart-define=SITE_URL=https://...`
  points booking links elsewhere (only a plain https address is accepted; anything else is ignored).
- **Not here yet:** the venue gallery and where tables sit on a floor plan (done on the website for now), claiming an existing venue, taking a venue live, the owner's Money and Reports tabs. The QR code is drawn by `qr_flutter` and was looked
  at, not scanned.
- **Needs the website migrations applied** (tenancy, onboarding, venue bookings). Until then each screen says "not set up on this server
  yet". Not run against a real database: there is no staging.

#### Setup editors (tables, bottle menu, booking times)

On a venue's **Setup** tab, the `tables`, `bottles` and `booking_rules` steps open an editor (the others stay on the website). They call
the website's `list_/add_/save_/remove_venue_*` functions (`20261010100000_venue_setup.sql`), which check in the database that the
person owns or manages THAT venue and refuse any field they do not know.

- `logic/setup_forms.dart` ports `venueSetupForms.ts`: money typed in dollars and kept in whole cents by parsing digits (never floating
  point), the checks and wording of each form, and the payloads. Tests read the website's migration (when it is checked out beside this
  app) and fail if a form sends a field the database does not accept, or a limit differs.
- `services/venue_setup_service.dart` is the calls; a refusal comes back as `SetupEditException` carrying the database's own sentence
  (`raise exception`, code P0001), anything else as a generic one (`services/db_errors.dart`).
- **Table and bottle photos** are one field like any other (`image_url`): the form shows the photo (`PhotoField`, same upload as the venue
  cover, into `<organization id>/` of the `business-media` bucket), opening an item and saving it unchanged sends the same address back, a new
  photo sends the new address, and Remove sends none. The list cards show a thumbnail. `sort_order` is not sent (items keep their position).
- Quick switches on the bottle menu (On menu, Sold out) send only that one field. A table type or time with bookings cannot be removed
  (the screen says so; the database refuses regardless). After any change the checklist is read again, so a step turns Done at once.
- Several days can be added to one arrival time at once; each day is its own call and its outcome is reported (added, already there,
  failed) without one failure stopping the rest.
- Looked at on a throwaway web build and covered by tests with a fake database (`test/owner/fake_setup_backend.dart`); not run against
  a real database.

### Team (owner and manager)

`lib/features/team/` is the **Team** tab of the owner's and the manager's workspace: who works for the business, who has been invited and
in what state, and the actions to invite, send a new link, cancel an invitation and remove access. It calls the website's `list_team`,
`list_team_invitations`, `list_shifts`, `invitable_roles`, `invite_member`, `resend_invitation`, `revoke_invitation` and
`revoke_membership` (website repo, `20261006120000_tenancy_foundation.sql` and `20261008100000_team_invitations.sql`). The database decides
who sees whom (an owner sees everyone, a manager only the staff of their own club) and which roles may be appointed, so the screen never
offers a role the database would refuse; nothing here grants access.

- `logic/team_rules.dart` ports the website's `team.ts`: the states and their wording, the invite form's checks, the payload, the
  link, the `mailto:` fallback and the email-outcome messages. A test compares the labels, wording and rules with the website repo when it
  is checked out beside this app, and `invite_member`'s parameters with the SQL.
- An owner invites to any venue of the business (the club picker); a manager only to their own club (taken from the workspace).
- **The link exists only once.** The database keeps a hash of the token, so the link is shown right after an invitation or a new link
  is created (Copy, and "Open in your email app" when the server could not send the email) and cannot be shown again.
  The email itself is the website's `send-team-invitation` edge function, called as the signed-in person; it can only email the
  address stored on the invitation. If it is not deployed the invitation still exists and the link is shown.
- Owners and organizers cannot be removed from here (the database refuses it too). Invitations are for a club, never for an event; event
  staff are invited from an organizer's event (not built).
- Not here yet: creating a shift (the picker lists shifts that exist), changing an existing member's role or window, an organizer's team.
- **Needs the website migrations applied** (tenancy, team invitations). Until then the tab says "The team is not set up on this server
  yet". Not run against a real database: there is no staging.

### Organizer events (Home and Events)

`lib/features/organizer_events/` is the organizer's **Home** and **Events** tabs: the business's events, with a way to create one, change
or remove a draft, and a plain "Contact BottlesUp" on a published one. It calls the website's `list_org_events`, `save_org_event` and
`remove_org_event` (website repo, `20261013100000_organizer_events.sql`, website PR #3). The database checks the person is an organizer of
THAT business, looks the event up inside it, and writes only whitelisted fields; the screen decides nothing about who may do what.

- **An organizer cannot publish.** Events are created as drafts; the payload never carries `status`, `org_id` or `slug` (the database
  refuses them). A draft is private until the BottlesUp team publishes it in the CMS, which also sets up its ticket tiers. A published
  event cannot be changed or removed here; the card says to contact BottlesUp.
- `logic/organizer_events_rules.dart` ports the website's `organizerEvents.ts`: the limits, the form's checks and their wording, the
  payload, grouping (drafts, upcoming, past; an event with no end lasts 12 hours), and how a time reads. Tests compare the limits, wording
  and field list with the website repo (SQL and TypeScript) when it is checked out beside this app.
- **The cover photo** is one field like any other (`cover_image_url`), uploaded with the shared `PhotoField` into the organizer's own folder of
  the `business-media` bucket; opening a draft and saving it unchanged sends the same address back, and Remove sends none. The event card shows it.
- Times are picked on the device and sent as UTC instants (the database refuses a time without a zone); they are shown back in the
  device's zone, and the form says which. Opening a draft and saving it unchanged sends the same instants back.
- Not here yet: ticket tiers, linking an event to a venue and its agreement, publishing by the organizer, the other event states from the
  brief (these are client decisions or later parts of section 7), and an organizer's team and guests. Nothing deletes an old photo file when
  a photo is replaced.
- The classic vendor dashboard's own event wizard (`features/events`, legacy tables) is untouched and unrelated.
- **Needs the website migration applied** (organizer events, after tenancy and onboarding). Until then the tab says "Events are not set up on
  this server yet". Not run against a real database: there is no staging.

#### Venue profile and floor plans (with photo upload)

The Setup list's **Venue profile** and **Rooms and floor plan** steps open editors (`screens/setup/venue_profile_editor.dart`,
`floors_editor.dart`, `floor_form_screen.dart`). They call the website's `update_venue_profile` (onboarding migration) and
`list_/save_/remove_venue_floor` (venue setup migration); the database checks the person owns or manages THIS venue.

- **The profile** is the name, description, address and cover photo. The payload is those four fields and nothing else: never the
  venue's status or slug (the BottlesUp team takes a venue live), and not the gallery (not edited here, so left as it is).
  A blank description, address or cover photo is sent as "none", so it can be cleared.
- **A floor** is a name and a floor plan image (both required). New floors go to the end of the list; an edit keeps its position. Removing a
  floor leaves its tables, unplaced (the screen says how many). Where each table sits on a floor is arranged by the BottlesUp team.
- **Photos** (`widgets/photo_field.dart`, `services/media_service.dart`, `logic/media_rules.dart`): the phone's gallery picker (shrinks to
  2400 px and re-encodes, which also turns an iPhone HEIC into a JPEG), a check of the real file type from its first bytes, JPEG/PNG/WebP up to
  5 MB, then an upload into the business's own folder of the public `business-media` bucket (`<organization id>/<new uuid>.<ext>`), which is
  all the bucket's policy allows. The photo is uploaded as soon as it is chosen and saved to the venue only when the form is saved; Save is held
  while an upload is going. Replacing a photo leaves the old file in storage (nothing deletes it). Tests compare the limits, folder rule and wording
  with the website's SQL and TypeScript.
- **Not tried on a real phone**: the real picker and the real storage upload (no staging, and the picker needs a device). Everything around
  them is covered by tests with fakes. Try a real photo, including an iPhone one, before relying on it.
- Not here yet: the gallery, deleting old files, reordering floors. (Table, bottle and event photos use the same `PhotoField`.)

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
