# CLAUDE.md

Guidance for working in this repository (Bottles Up **Vendor** app).

## What this app is

Flutter app for venue owners, managers, organizers, door/server staff and similar roles. It shares one
Supabase project with the Bottles Up website and the customer app, so the **website's `site_*` schema and
edge functions are the source of truth**. Do not add a second source of truth for bookings or payments here.

- Bundle / application ID: Android `com.bottlesup.vendor`; iOS `com..bottlesUp.ORG` (the vendor app's original iOS ID, already registered under team `4T453RG45S`; the double dot is deliberate. They differ on purpose: `com.bottlesup.vendor` is taken on Apple's side by a free personal team's App ID).
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

**Accounts are created on the website, not here** (`logic/business_signup.dart`, `screens/no_workspace_screen.dart`). This app has no
sign-up: `/register` is a page that explains and opens the website's `/signup/business`, and the old role-selection screen, `register()`
and the `vendors`-row creation are gone. Someone signed in with **no workspace and no finished classic onboarding** is sent to
`/no-workspace` ("Set up your business": open the website, or paste an invitation link, or check again). A person who finished the classic
dashboard's own onboarding (`vendors.onboarding_completed`) keeps the classic dashboard unchanged. The rule is the pure
`decideWorkspaceRedirect` (with `ClassicVendorStatus`: `loading` = not looked up yet or the lookup failed, so nothing is decided; `classic`; `none`).
`SupabaseAuthService.findVendorUser` throws when it cannot ask; it never creates a row. (It used to create a `vendors` row for **every**
account that signed in, which is how website and customer accounts became "vendors": production had 59 `vendors` rows for 82 accounts on 16 Oct 2026.)
The website address comes from `siteUrlProvider` (`--dart-define=SITE_URL`, default the real site).

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
- **VIP lookup at the club door:** a door whose workspace has a venue (a club door) gets a "VIP lookup" button on Guests, which opens the same
  `VipLookupScreen` the server uses. The database shows the door **entry perks only** (no preferences, contact, notes, service or discount
  perks) and lets it redeem them; an event-only door has no venue, the database would refuse it, so it gets no button (`DoorGuestsScreen.venueId`
  is null). `test/door/door_vip_lookup_test.dart`. A VIP credential does not admit anyone to an event by itself (the client's brief).
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
- Amounts on the list are **what was booked, not what was collected** (the deposit and total on the booking). What was collected, what is still due,
  the payments and the bottle orders are on each confirmed booking's "Orders and payments" page (Table service, below).
- Not here yet: walk-ins, guest allowances, table check-in. Orders, collected money and payments are on each confirmed booking's "Orders and payments" page (see Table service).
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

### Server desk (My Tables, Requests, and giving a booking to a server)

`lib/features/server_desk/` is a server's **My Tables** and **Requests** tabs, plus the manager's and owner's "Server" line on each confirmed
booking of the Floor / venue Bookings list. It calls the website's `my_assigned_tables`, `list_service_requests`, `create_service_request`,
`update_service_request`, `list_venue_booking_servers`, `assign_booking_server`, `unassign_booking_server` (website repo,
`20261014100000_table_servers.sql` and `20261014110000_service_requests.sql`, on branch `feat/server-desk-foundation`). The database decides who may
do what; the buttons only offer moves it would accept (a test runs every offered button against a model of the SQL).

- A booking has one server. Individual tables do not exist yet, so what is given out is the booking (the client brief says "tables": to confirm).
- First to acknowledge owns a request; a colleague is told so. Asking twice for the same thing is one request. Escalating and cancelling need a reason.
- A server's table list carries no guest email or phone. Where each table stands (what is due, what is left to deliver) and each table's
  orders and payments come from the table service below; the Scan tab (seat a guest from a booking QR) is still a placeholder.
- The old staff functions (`list_my_tables` etc.) authorize through the global `door_staff` table, which an invited server is not in; this does not use them.
- Not here: requests made by the guest, a manager's requests tab (Tonight links to the same list), handing a request on (the database supports it), shifts.
- **Needs both website migrations applied.** Not run against a real database. Mutation-checked: rules, service, screens and the Floor row (the last 20 Floor/picker mutants were not run). The table service below needs two more migrations.

### Table service (orders, payments, checking them, Tonight)

`lib/features/table_service/` is the money side of table service (brief sections 6, 13, 14 and 15): a server's and a manager's **Orders**, the
page of one table (its money, bottle orders and payments, with **Record a payment**), the verifier's **Review** queue, and the manager's
**Tonight**. It calls the website's `desk_orders`, `desk_booking_orders`, `desk_set_service_status`, `desk_booking_money`,
`desk_record_payment`, `desk_pending_verifications`, `desk_verify_payment`, `desk_table_status` and `desk_tonight` (website repo,
`20261014120000_desk_orders.sql` and `20261014130000_desk_payments.sql`, branch `feat/server-desk-foundation`). The database decides who may do what;
the buttons only offer what it would accept. Those functions replace, for the membership roles, production's own staff functions, which
authorize through the global `door_staff` table (an invited server or verifier is not in it).

- **Orders** (`screens/orders_screen.dart`, server and manager): a night's bottle lines, longest wait first, delivered last, with filters New / Needs
  payment / Preparing / On the way / Delivered and the move to make next. A server sees only their tables; the manager the whole club. The five states are
  the database's (`awaiting_prep`, `preparing`, `ready`, `picked_up`, `served`; the app says New / Preparing / Ready / On the way / Delivered). A server
  cannot take a delivered item back (only a manager); an item to be paid at the venue says why it cannot be delivered while its table owes money.
  Repeated taps change nothing and say so. The brief's "needs attention" filter means orders left waiting too long: the client has not said how long,
  so every order shows how long it has waited instead. Lists build only the rows near the screen (a night can have a thousand orders).
- **A table's page** (`screens/table_detail_screen.dart`): opened from a server's card ("Orders and payments") or the manager's Floor row. Shows total /
  collected / still due, the bottle orders (cancelled ones with their reason) and every payment with where it stands: "Recorded - verification pending",
  Verified, Confirmed by the guest, Disputed. A guest's email is never sent to the app. Receipts open through a short-lived address (private bucket).
- **Record a payment** (`screens/record_payment_screen.dart`): bill, amount collected, method (a split's parts must add up), the till's receipt number,
  optional bill details, and the receipt photo. A **server must attach a photo** and confirm the total and date can be read; a **manager may instead
  say why there is no receipt**. The photo is uploaded to `club-payment-receipts/<booking id>/<file>` with its SHA-256; it stays uploaded across a
  retry, so a lost answer sent again is a repeat ("already recorded"), not a second payment. Recording does not verify anything.
- **Review** (`screens/payment_review_screen.dart`, verifier; also from Tonight): payments nobody has checked and ones a guest disputed (those first).
  Nobody checks their own entry or a disputed one (the screen says why instead of offering the button); a photo alone verifies nothing.
- **Tonight** (`screens/tonight_screen.dart`, manager): what needs a person (payments to check, new orders, open requests, tables without a server,
  closings asked for) and the night at a glance. Payments to check, closings and open requests are club-wide, not tied to a night.
- `logic/table_service_rules.dart` is the rules (words, parsing that drops rows it cannot trust, filters, which moves to offer, the payment form's
  checks and payload); `services/table_service_service.dart` and `services/receipt_service.dart` are the calls. A test reads the website's SQL (when the
  repo is checked out beside this app) and fails if the states, methods, argument names, returned columns, limits or sentences differ.
- **Needs both website migrations applied**, and the production-only tables they build on. Not run against a real database (there is no staging).
  **Try the camera and a real receipt on a real phone before relying on it at a table**: the picker and the private-bucket upload were only exercised
  with fakes. Not built: flagging a payment, settling a disputed payment, cash handover from server to cashier, corrections and refunds, partial delivery of a
  line, a service estimate and "mark seated", the manager's checklist for preparing and closing a night, and alerts for slow orders or low stock.
- `tool/mutate_dart.py` mutation-checks this code on throwaway copies of the app (see its header). Last result: rules/service 126 of 129 killed, screens/widgets
  101 of 107; what survived is equivalent (an initial value nothing can observe, a comparison that can never be equal, an invisible empty row) or is killed by
  `test/table_service/long_lists_test.dart`, which is left out of the runs because it is slow. Run it with at most 3 workers (more makes the machine unusable) and
  keep the Mac awake: idle sleep pauses a run and makes it look hung.

### Developer brief of 15 Oct 2026 (tranche 1)

The client's newer brief (35 sections; gap analysis in the monorepo, `docs/BRIEF_15OCT_GAP_ANALYSIS.md`) changed these things in the app:

- **Name:** the app is **BottlesUp Business** (phone label, About, Terms, Help, titles); the customer app stays BottlesUp. `test/branding/business_name_test.dart`
  stops "Bottles Up Vendor" / "BottlesUp Vendor" coming back in anything a person reads. The legal wording of the Terms and Privacy still uses "Vendor" as a
  defined term; that is for the client's lawyer.
- **A failed workspace request is not a new account** (`/workspace-error`, `WorkspaceLoadFailedScreen`): "We could not load your workspace" with Retry and Sign out. Only a
  successful empty answer reaches "Set up your business". A finished classic vendor is not moved by an error. Rule: `_withoutWorkspace` in `workspace_routing.dart`.
- **Navigation per brief section 6:** Owner Overview / Venues / **Tonight** / Reports / More (Tonight is the manager's Tonight for the venue picked; Payments and earnings moved
  into More), Organizer Overview, Door gets More (shift summary and promo codes, both "Not available yet", and Settings), Security's Incidents moved into More. Event Lead is in the
  brief but not built (no database role, program rules to agree first). Tab ids are unchanged (`home` is labelled Overview).
- **No technical text on screen:** `core/utils/plain_error.dart` (`couldNot`, `couldNotLoad`, `loadFailedMessage`) says what failed and what to do, and logs the reason.
  `test/branding/no_raw_errors_test.dart` fails if a `Text(...)` is given `$e`, `$error` or `e.toString()`. `ErrorHandler` no longer passes the database's own wording through.
- **Last workspace remembered** per person on the phone (`LastWorkspaceStore`, shared_preferences, already a locked transitive package): it only orders the selector list and
  says "Last used"; a workspace the person no longer has is ignored, and access is always the database's.
- Not done from the brief and why: see the gap analysis (tranche 2 needs small database additions; tranche 3 waits for the client's decisions).

### Archived code

Code removed to keep the app focused is in `_archive/` with a manifest and a restore script:
`_archive/restore.sh <path-prefix> [--dry-run]`. Read `_archive/README.md` first.

## Release checklist

- **Android signing:** release builds require `android/key.properties` (copy `android/key.properties.example`).
  Without it the build fails on purpose. For a throwaway local build set `ORG_GRADLE_PROJECT_allowUnsignedRelease=true`.
- **iOS signing:** the App ID `com..bottlesUp.ORG` is already registered under team `4T453RG45S` (it has development and store profiles); automatic signing with `-allowProvisioningUpdates` handles the rest.
- **Android permissions:** `INTERNET` is declared in the main manifest. Flutter only adds it to debug/profile
  builds on its own, so removing it breaks release builds completely.
- **Crash reporting:** not wired up yet (`_logError` in `main.dart` only prints). Add Sentry or similar before launch.
- **Privacy policy:** the in-app screen (`features/profile/screens/privacy_policy_screen.dart`) is generic
  boilerplate with placeholder company details; it needs real legal text before store submission.

## Stale files

The repo root holds many old status notes (`*_SUMMARY.md`, `*_FIX*.md`, `PRODUCTION_READY*.md`) and unused
Firebase config (`firebase.json`, `firestore.rules`, `.firebaserc`). They describe earlier work, not the current
state. Trust the code and this file.
