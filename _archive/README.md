# `_archive/` — code removed from the live app

Nothing here was deleted. The app is being moved onto the **website's backend** (the `site_*` tables, RPCs and edge functions) and trimmed to what v1 needs, so everything else was moved out of `lib/` into this folder, **keeping its original relative path**. Restoring a file is moving it back.

`flutter analyze` ignores this folder (see `analysis_options.yaml`), so it never affects builds or CI.

## What was moved

### Tier 1 — unreachable code (no behaviour change) — 12 files

Files that **nothing imports**, traced from `lib/main.dart` through every `import`, `export` and `part`. They were never part of the running app. Generated `*.g.dart` / `*.freezed.dart` files travel with their parent.

| Original location | Files | Lines |
|---|---:|---:|
| `lib/shared` | 6 | 1621 |
| `lib/features/events` | 5 | 1377 |
| `lib/core` | 1 | 189 |

### Tier 2 — features cut from the product — 13 files

**Dev / database-setup tooling** (the `/debug` and `/database-setup` screens and `database_debugger.dart`; these sat on the no-login allow-list), **Earnings** (Stripe payout screen), **Subscription** (plan and billing screen), **Venue boost** and **Venue-owner requests** screens. Files that became unreachable once those routes were removed were moved with them.

| Original location | Files | Lines |
|---|---:|---:|
| `lib/shared` | 6 | 1407 |
| `lib/features/venues` | 2 | 1013 |
| `lib/features/auth` | 2 | 842 |
| `lib/features/profile` | 1 | 742 |
| `lib/features/earnings` | 1 | 648 |
| `lib/core` | 1 | 318 |

## What else changed outside this folder

These are the only code edits (everything else was a pure file move). `restore/tier2_edits.patch` reverses all of them.

- `lib/core/router/app_router.dart`: removed 6 imports, 2 allow-list entries and the routes for debug, database-setup, earnings, subscription, venue boost and venue requests
- `lib/features/auth/screens/role_selection_screen.dart`: the "database setup required" case now shows a snackbar instead of navigating to `/database-setup`
- `lib/features/dashboard/screens/dashboard_screen.dart`: the Sales and Payouts tiles no longer link to `/earnings`
- `lib/features/profile/screens/profile_screen.dart`: removed the "Subscription" tile and a stale import

Also: `analysis_options.yaml` now excludes `_archive/**`.

## How to restore

```bash
cd apps/bottles-up-vendor

# preview, then restore one feature
_archive/restore.sh lib/features/earnings --dry-run
_archive/restore.sh lib/features/earnings

# restore everything that came from lib/
_archive/restore.sh lib

# put back the routes / tabs / tiles that pointed at Tier 2 files
git apply -R _archive/restore/tier2_edits.patch
```

- **Tier 1** files need nothing else: nothing referenced them.
- **Tier 2** files also need their wiring back. The patch is the exact record of what was removed, so you can re-add a single route or tile by hand from it.
- A scratch round trip (restore everything + reverse the patch) reproduces the original pinned commit exactly.

## Verification

`flutter analyze` (no pub) at the commit this was cut from, versus now:

| | Before | After |
|---|---|---|
| Analyzer errors | 10 errors (all in `test/model_serialization_test.dart`) | 10 errors (same ones) |

No new errors or warnings were introduced. **This is static analysis only**: the app was not built or run.

## Not moved on purpose

- `lib/shared/models/booking_model.dart`: unused by the app but imported by `test/model_serialization_test.dart`, so it stays until that test is fixed.
- The **venue directory / detail / proposal** screens and `venue_request_service.dart`: the Venues bottom-nav tab and the club screens depend on them. Needs a product decision, see below.
- **Organizer and promoter onboarding** and `stripe_service.dart` (Stripe Connect set-up): still wired into onboarding.
- Event authoring, analytics, club management, scanner and auth: kept. The scanner is the one part a staff app needs, and its `check_in_service.dart` must be rewritten to call the website's `checkin_ticket` RPC.
- `supabase/functions/*` (Stripe Connect and portal functions): still referenced by `stripe_service.dart`.
- The `database/` and root `*.sql` schema scripts, and the many `.md` status docs. Not touched. The vendor `CLAUDE.md` still describes Firebase and should be rewritten.

## Known issues that were already there

- `test/model_serialization_test.dart` has 10 pre-existing errors and `test/router_smoke_test.dart` fails (0 passed, 2 failed) with or without this change.
- The app is **not** verified to run. Only `flutter analyze` was used.
