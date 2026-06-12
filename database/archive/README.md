# Archived Migration Files

**Date Archived:** 2026-06-12
**Reason:** Migration consolidation - these files contained ad-hoc fixes that have been merged into the consolidated migration set.

---

## Files in This Archive

### Ad-Hoc Fix Scripts (Obsolete)

| File | Original Purpose | Why Archived |
|------|------------------|--------------|
| `00_diagnostic.sql` | Diagnostic queries to inspect schema | Read-only queries - no schema changes, not needed in migrations |
| `00_quick_fix.sql` | Quick fix for analytics errors (April 2026) | Functionality merged into consolidated migrations 008-009 |
| `01_actual_fix.sql` | Corrected version of 00_quick_fix using events_bookings | Duplicate of 00_quick_fix with table name fix - merged |
| `02_final_fix.sql` | Third iteration of same fix | Duplicate - merged |
| `fix_event_performance_view.sql` | Fixed v_event_performance view | Merged into migration 009 (analytics views) |
| `FINAL_FIX_ALL_ISSUES.sql` | Fixed events.status constraint + subscription plans | Merged into migrations 003 (subscriptions) and 014 (event fixes) |

---

## What These Files Fixed

### Original Problems (Now Resolved)

1. **Missing `clubs.status` column**
   - Fix: Added `status TEXT DEFAULT 'active'` to clubs table
   - Consolidated into: Migration 008

2. **QR Scanning Fields Missing from Bookings**
   - Fix: Added ticket_code, qr_code, checked_in, checked_in_at, checked_in_by, booking_type, customer_phone
   - Consolidated into: Migration 008

3. **Feature Tables Missing**
   - Fix: Created inquiries, guest_list, scheduled_releases, venue_boosts
   - Consolidated into: Migration 008

4. **Analytics Views Errors**
   - Fix: Created v_organizer_analytics, v_revenue_by_event, v_event_performance
   - Consolidated into: Migration 009

5. **Events Status Constraint Issues**
   - Fix: Removed bad CHECK constraint, set proper defaults
   - Consolidated into: Migration 014

6. **Missing Subscription Plans**
   - Fix: Ensured 4 subscription plans exist with proper data
   - Consolidated into: Migration 003

---

## Why Multiple Versions Existed

The fix files went through iterations:

1. **00_quick_fix.sql** - Initial fix referencing `bookings` table
2. **01_actual_fix.sql** - Corrected to use `events_bookings` table
3. **02_final_fix.sql** - Removed venue.user_id dependency that didn't exist
4. **FINAL_FIX_ALL_ISSUES.sql** - Focused only on events.status and subscriptions

All attempted to solve the same issues but with different table name assumptions. The consolidated migrations use the correct table names based on actual schema analysis.

---

## Migration Consolidation Summary

### Old Structure (Fragmented)
```
supabase/migrations/
├── 003_events_rls_policies.sql
├── 004_onboarding_tables_and_storage.sql
├── 005_storage_buckets_and_policies.sql
├── 006_delete_account_function.sql
├── 00_diagnostic.sql ❌
├── 00_quick_fix.sql ❌
├── 01_actual_fix.sql ❌
├── 02_final_fix.sql ❌
└── fix_event_performance_view.sql ❌

database/migrations/
├── 001_add_event_fields.sql
├── 002_create_subscription_tables.sql
├── 003_create_stripe_accounts_table.sql
├── 004_update_ticket_types_table.sql
├── 005_update_event_team_members_table.sql
├── 006_create_storage_buckets.sql (duplicate)
├── 007_fix_event_status.sql ❌
└── 008_fix_event_constraint.sql ❌

Root:
├── database_setup.sql (base schema)
├── FINAL_FIX_ALL_ISSUES.sql ❌
└── supabase_schema.sql (reference dump)
```

### New Structure (Consolidated)
```
supabase/migrations/
├── 001_base_schema.sql
├── 002_add_event_fields.sql
├── 003_subscription_system.sql
├── 004_stripe_connect.sql
├── 005_multi_tier_ticketing.sql
├── 006_event_team_management.sql
├── 007_onboarding_profiles.sql
├── 008_feature_tables.sql ✅ (merged ad-hoc fixes)
├── 009_analytics_views.sql ✅ (merged view fixes)
├── 010_events_rls_policies.sql
├── 011_profile_tables_rls.sql
├── 012_storage_buckets.sql
├── 013_account_management.sql
└── 014_fix_event_status.sql ✅ (merged constraint fixes)
```

---

## If You Need These Files

**DO NOT** run these files directly. They:
- May have been partially applied already
- May conflict with consolidated migrations
- May reference incorrect table names
- May have duplicate CREATE statements

Instead:
1. Review the consolidated migration files
2. Run only the numbered migrations in order (001-014)
3. Use [verify_rls.sql](../verify_rls.sql) to check database state

---

## Data Preservation

Archiving these files does NOT affect your database data. These are migration scripts, not data. All functionality has been preserved in the consolidated migrations.

---

## Questions?

See:
- [../MIGRATION_CONSOLIDATION_REPORT.md](../MIGRATION_CONSOLIDATION_REPORT.md) - Full consolidation analysis
- [../SECURITY_ISSUES.md](../SECURITY_ISSUES.md) - Security vulnerabilities found during audit
- [../verify_rls.sql](../verify_rls.sql) - RLS verification script

**Archived By:** Database Migration Consolidation Project
**Can Be Safely Deleted:** Yes (after confirming consolidated migrations work)
