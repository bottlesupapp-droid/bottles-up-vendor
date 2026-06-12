# Supabase Migration Consolidation Report
**Date:** 2026-06-12
**Status:** CRITICAL - Database schema is fragmented across multiple locations

---

## Executive Summary

The database schema is currently split across **THREE separate locations** with significant duplication and ad-hoc fixes:

1. **`supabase/migrations/`** - 11 files (6 numbered migrations + 5 ad-hoc fixes)
2. **`database/migrations/`** - 8 files (numbered 001-008)
3. **Root directory** - 3 SQL files (database_setup.sql, supabase_schema.sql, FINAL_FIX_ALL_ISSUES.sql)

This creates **production deployment risk**, **schema drift**, and **maintenance burden**.

---

## Migration File Inventory

### ✅ Valid Core Migrations (Keep & Consolidate)

| File | Location | Purpose | Status |
|------|----------|---------|--------|
| `database_setup.sql` | Root | Base schema (vendors, events, inventory, bookings) | **BASE** |
| `001_add_event_fields.sql` | database/ | Adds dress_code, min_age to events | Valid |
| `002_create_subscription_tables.sql` | database/ | Creates subscription_plans, vendor_subscriptions | Valid |
| `003_create_stripe_accounts_table.sql` | database/ | Creates stripe_accounts, payout_records | Valid |
| `004_onboarding_tables_and_storage.sql` | supabase/ | Creates staff_profiles, promoter_profiles, organizer_profiles, venue_details + related | Valid |
| `005_storage_buckets_and_policies.sql` | supabase/ | Creates storage buckets (venue-gallery, profile-photos, etc.) | Valid |
| `006_delete_account_function.sql` | supabase/ | Creates delete_account() RPC function | Valid |
| `003_events_rls_policies.sql` | supabase/ | RLS policies for events table | Valid |

### ⚠️ Ad-Hoc Fix Files (ARCHIVE - Functionality Merged)

| File | Purpose | Can Archive? |
|------|---------|--------------|
| `00_diagnostic.sql` | Diagnostic queries only - no schema changes | **YES** |
| `00_quick_fix.sql` | Adds status to clubs, QR fields to bookings, creates inquiries/guest_list/scheduled_releases/venue_boosts | **MERGE** |
| `01_actual_fix.sql` | Identical to 00_quick_fix but uses events_bookings instead of bookings | **MERGE** |
| `02_final_fix.sql` | Identical to 01_actual_fix | **DUPLICATE** |
| `fix_event_performance_view.sql` | Fixes v_event_performance view to use correct table | **MERGE** |
| `FINAL_FIX_ALL_ISSUES.sql` | Fixes events.status constraint + ensures subscription_plans exist | **MERGE** |

### 🔄 Additional Database Files

| File | Purpose | Action |
|------|---------|--------|
| `database/migrations/004_update_ticket_types_table.sql` | Creates ticket_types table | **MERGE** |
| `database/migrations/005_update_event_team_members_table.sql` | Creates event_team table | **MERGE** |
| `database/migrations/006_create_storage_buckets.sql` | Duplicate of supabase/005 | **SKIP** |
| `database/migrations/007_fix_event_status.sql` | Fixes events.status - redundant with FINAL_FIX | **SKIP** |
| `database/migrations/008_fix_event_constraint.sql` | Fixes events.status - redundant with FINAL_FIX | **SKIP** |
| `supabase_schema.sql` | Complete schema dump | **REFERENCE ONLY** |

---

## Consolidated Migration Plan

### Proposed Clean Structure

```
supabase/migrations/
├── 001_base_schema.sql                    # Base tables (vendors, events, inventory, bookings)
├── 002_add_event_fields.sql               # dress_code, min_age
├── 003_subscription_system.sql            # subscription_plans, vendor_subscriptions
├── 004_stripe_connect.sql                 # stripe_accounts, payout_records
├── 005_multi_tier_ticketing.sql           # ticket_types table
├── 006_event_team_management.sql          # event_team table
├── 007_onboarding_profiles.sql            # staff/promoter/organizer/venue tables
├── 008_feature_tables.sql                 # inquiries, guest_list, scheduled_releases, venue_boosts, clubs.status, bookings QR fields
├── 009_analytics_views.sql                # v_organizer_analytics, v_revenue_by_event, v_event_performance
├── 010_events_rls_policies.sql            # RLS policies for events
├── 011_profile_tables_rls.sql             # RLS for onboarding tables
├── 012_storage_buckets.sql                # Storage buckets and policies
├── 013_account_management.sql             # delete_account() function
└── 014_fix_event_status.sql               # Remove bad constraint, set defaults
```

### Archive Folder

```
database/archive/
├── 00_diagnostic.sql
├── 00_quick_fix.sql
├── 01_actual_fix.sql
├── 02_final_fix.sql
├── fix_event_performance_view.sql
├── FINAL_FIX_ALL_ISSUES.sql
├── 007_fix_event_status.sql
├── 008_fix_event_constraint.sql
└── README.md (explains why these are archived)
```

---

## Critical Issues Found

### 🔴 CRITICAL Security Issues

1. **Missing RLS Policies**: Multiple tables accessed by app have NO RLS policies:
   - ❌ `inquiries` - RLS enabled but policies reference non-existent events.user_id
   - ❌ `guest_list` - Same issue
   - ❌ `scheduled_releases` - Same issue
   - ❌ `venue_boosts` - **CRITICAL**: Policy uses `USING (auth.uid() IS NOT NULL)` - ANY authenticated user can read/write ALL records!
   - ❌ `ticket_types` - NO RLS at all
   - ❌ `event_team` - NO RLS at all
   - ❌ `staff_profiles`, `promoter_profiles`, `organizer_profiles`, `venue_details` - RLS enabled (004 migration) but NO policies
   - ❌ `stripe_accounts`, `payout_records` - NO RLS at all

2. **Table Naming Inconsistency**:
   - Code uses `events_bookings` (analytics, scanner, services)
   - Base schema creates `bookings`
   - Views reference both names randomly

3. **Foreign Key Issues**:
   - `events` table references `user_id` in RLS policies (003_events_rls_policies.sql:37)
   - But `events` table has `vendor_id`, not `user_id` (database_setup.sql:29)
   - References to `clubs.owner_id` but schema shows `clubs.user_id` may not exist
   - References to `promo_codes`, `shifts` tables that don't exist in migrations

### ⚠️ Warning Level Issues

1. **Duplicate Migrations**: Same fixes applied 3-4 times (00_quick_fix, 01_actual_fix, 02_final_fix)
2. **Schema Drift**: `database/` and `supabase/` folders have different migration numbers
3. **Missing Idempotency**: Some migrations will fail on re-run
4. **No Migration Order**: Files in `supabase/migrations/` use inconsistent numbering

---

## Tables Referenced by Application

Based on grep of `.from('` patterns in Dart code:

### ✅ Tables with Proper Schema + RLS
- `vendors` ✅ (RLS policies exist)
- `events` ✅ (RLS policies exist, but column mismatch issue)

### ⚠️ Tables Exist but NO/WEAK RLS
- `events_bookings` / `bookings` (table naming confusion)
- `clubs` (status column added by fix files)
- `ticket_types` ❌ NO RLS
- `event_team` ❌ NO RLS
- `vendor_details` ❌ NO RLS policies
- `subscription_plans` (public read OK)
- `vendor_subscriptions` ❌ NO RLS
- `stripe_accounts` ❌ NO RLS
- `payout_records` ❌ NO RLS
- `inquiries` ⚠️ WEAK (bad foreign key check)
- `guest_list` ⚠️ WEAK
- `scheduled_releases` ⚠️ WEAK
- `venue_boosts` 🔴 CRITICAL (anyone can access)
- `venue_requests` ❌ NO RLS
- `staff_profiles`, `promoter_profiles`, `organizer_profiles` ❌ NO RLS policies

### ❓ Tables Referenced But May Not Exist
- `vendor_inventory` (code uses this, schema shows `inventory`)
- `vendor_events` (unclear if view or table)
- `vendor_bookings` (unclear if view or table)
- `categories` (referenced but not in migrations)
- `zones` (referenced but not in migrations)
- `event_templates` (referenced but not in migrations)

### 📊 Views Referenced
- `v_organizer_analytics`
- `v_revenue_by_event`
- `v_event_performance`

### 🗄️ Storage Buckets
- `event-images`
- `club-images`
- `venue-gallery`
- `venue-documents`
- `profile-photos`
- `id-documents`

---

## Next Steps

### Immediate Actions (Critical)

1. ✅ **Create database/archive/ folder**
2. ⏳ **Write consolidated migrations** (001-014 as outlined above)
3. ⏳ **Create verify_rls.sql** - comprehensive RLS audit script
4. ⏳ **Document critical security holes** in separate SECURITY_ISSUES.md
5. ⏳ **Test consolidated migrations** on fresh Supabase project

### Follow-Up Actions

1. Add missing RLS policies for all tables
2. Resolve table naming (bookings vs events_bookings)
3. Fix foreign key references (user_id vs vendor_id in events)
4. Create missing tables (categories, zones, event_templates)
5. Run flutter analyze to verify code matches schema

---

## Risk Assessment

| Risk | Severity | Impact |
|------|----------|--------|
| Missing RLS on payout/subscription tables | **🔴 CRITICAL** | Financial data exposed |
| venue_boosts accessible by all users | **🔴 CRITICAL** | Data breach |
| Duplicate migrations causing schema drift | **🔴 HIGH** | Deployment failures |
| Table naming inconsistency | **⚠️ MEDIUM** | Runtime errors |
| Missing tables referenced by code | **⚠️ MEDIUM** | App crashes |

**RECOMMENDATION**: Do NOT deploy to production until all 🔴 CRITICAL issues resolved.
