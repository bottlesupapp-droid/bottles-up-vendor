# 🔴 CRITICAL SECURITY ISSUES - Bottles Up Vendor Database

**Date:** 2026-06-12
**Severity:** CRITICAL - DO NOT DEPLOY TO PRODUCTION
**Auditor:** Database Migration Consolidation Review

---

## 🚨 Executive Summary

**CRITICAL FINDING**: The Bottles Up Vendor database has **SEVERE security vulnerabilities** that expose:
- 💰 **Financial data** (Stripe accounts, payouts, subscription billing)
- 👤 **User personal information** (staff profiles, ID documents, venue details)
- 📊 **Business data** (revenue, bookings, event analytics)

**Impact**: Any authenticated user can:
- Read/write all payment records
- Access all vendor Stripe account information
- View/modify subscription data for any vendor
- Access personal documents uploaded by staff

**Required Action**: ALL 🔴 CRITICAL issues must be resolved before production deployment.

---

## 🔴 CRITICAL ISSUES (Fix Immediately)

### 1. Financial Data Completely Exposed

**Affected Tables:**
- `stripe_accounts` - Stripe Connect account IDs, balances, payout schedules
- `payout_records` - Payment history, amounts, bank details
- `vendor_subscriptions` - Subscription status, billing info

**Current State:**
```sql
-- NO RLS POLICIES AT ALL!
-- Any authenticated user can:
SELECT * FROM stripe_accounts; -- See all vendor Stripe accounts
SELECT * FROM payout_records;   -- See all payout history
SELECT * FROM vendor_subscriptions; -- See all subscription data
```

**Severity:** 🔴 **CRITICAL - Data Breach**

**Impact:**
- Attackers can view competitor revenue
- Financial fraud potential
- GDPR/PCI compliance violation
- Legal liability

**Fix Required:**
```sql
-- Enable RLS
ALTER TABLE stripe_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_subscriptions ENABLE ROW LEVEL SECURITY;

-- Add vendor-only policies
CREATE POLICY "Vendors can only view own Stripe account"
  ON stripe_accounts FOR SELECT
  USING (vendor_id = auth.uid());

CREATE POLICY "Vendors can only view own payouts"
  ON payout_records FOR SELECT
  USING (vendor_id = auth.uid());

CREATE POLICY "Vendors can only view own subscription"
  ON vendor_subscriptions FOR SELECT
  USING (vendor_id = auth.uid());
```

---

### 2. Venue Boosts Table - Unrestricted Access

**Affected Table:** `venue_boosts`

**Current Policy:**
```sql
-- From 02_final_fix.sql lines 246-254
CREATE POLICY "Authenticated users can manage venue boosts"
  ON venue_boosts FOR ALL
  USING (auth.uid() IS NOT NULL); -- ❌ ANY logged-in user!
```

**Severity:** 🔴 **CRITICAL - Data Breach + Unauthorized Writes**

**What This Means:**
- ✅ User A logs in
- ✅ User A can read ALL venue boost data (impressions, clicks, payment info)
- ✅ User A can UPDATE boost records for User B's venue
- ✅ User A can DELETE User B's boost campaigns
- ✅ User A can INSERT fake boost records

**Impact:**
- Competitor espionage (see who is boosting, how much)
- Data manipulation (delete competitors' boosts)
- Financial fraud (create fake boosts)

**Fix Required:**
```sql
-- Remove the dangerous policy
DROP POLICY "Authenticated users can manage venue boosts" ON venue_boosts;

-- Add proper vendor-only policy (assuming venue_boosts links to venues.vendor_id)
CREATE POLICY "Venue owners can manage their boosts"
  ON venue_boosts FOR ALL
  USING (
    venue_id IN (
      SELECT id FROM venues WHERE vendor_id = auth.uid()
    )
  );
```

---

### 3. Onboarding Profile Tables - No Access Control

**Affected Tables:**
- `staff_profiles` - Staff personal data, phone numbers, ID documents
- `promoter_profiles` - Promoter data, commission tracking
- `organizer_profiles` - Organization details, social media
- `venue_details`, `venue_gallery`, `venue_documents`, `venue_zones`

**Current State:**
```sql
-- RLS IS ENABLED (migration 004) but NO POLICIES DEFINED!
-- Result: Tables are INVISIBLE to everyone, including owners
```

**Severity:** 🔴 **CRITICAL - Data Inaccessible + Privacy Risk**

**Impact:**
- Onboarding screens will fail (cannot save data)
- If policies added incorrectly → data leak
- Staff ID documents (Aadhaar, license scans) unprotected

**Fix Required:**
```sql
-- Staff Profiles
CREATE POLICY "Vendors can view own staff profile"
  ON staff_profiles FOR ALL
  USING (vendor_id = auth.uid());

-- Promoter Profiles
CREATE POLICY "Vendors can view own promoter profile"
  ON promoter_profiles FOR ALL
  USING (vendor_id = auth.uid());

-- Organizer Profiles
CREATE POLICY "Vendors can view own organizer profile"
  ON organizer_profiles FOR ALL
  USING (vendor_id = auth.uid());

-- Venue Details (with related tables)
CREATE POLICY "Venue owners can manage venue details"
  ON venue_details FOR ALL
  USING (vendor_id = auth.uid());

CREATE POLICY "Venue owners can manage gallery"
  ON venue_gallery FOR ALL
  USING (vendor_id = auth.uid());

CREATE POLICY "Venue owners can manage documents"
  ON venue_documents FOR ALL
  USING (vendor_id = auth.uid());

CREATE POLICY "Venue owners can manage zones"
  ON venue_zones FOR ALL
  USING (vendor_id = auth.uid());
```

---

### 4. Team & Ticket Tables - No RLS

**Affected Tables:**
- `event_team` - DJ/staff assignments, set times, pay rates
- `ticket_types` - Multi-tier ticket pricing, inventory

**Current State:**
```sql
-- NO RLS ENABLED AT ALL!
-- Migration files create tables but never enable RLS
```

**Severity:** 🔴 **CRITICAL - Business Data Exposed**

**Impact:**
- Competitors can see your pricing strategy
- Competitors can see staff pay rates
- Competitors can clone your event structure

**Fix Required:**
```sql
-- Enable RLS
ALTER TABLE event_team ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_types ENABLE ROW LEVEL SECURITY;

-- Event team: only event creators can manage
CREATE POLICY "Event creators can manage team"
  ON event_team FOR ALL
  USING (
    event_id IN (
      SELECT id FROM events WHERE vendor_id = auth.uid()
    )
  );

-- Ticket types: only event creators can manage
CREATE POLICY "Event creators can manage ticket types"
  ON ticket_types FOR ALL
  USING (
    event_id IN (
      SELECT id FROM events WHERE vendor_id = auth.uid()
    )
  );
```

---

### 5. Foreign Key Integrity Issues

**Problem:** RLS policies reference columns/tables that don't exist

**Examples:**

1. **events.user_id vs events.vendor_id**
   ```sql
   -- File: 003_events_rls_policies.sql, line 37
   CREATE POLICY "Organizers can view their events"
   ON events FOR SELECT
   USING (user_id = auth.uid()); -- ❌ Column doesn't exist!

   -- Actual schema (database_setup.sql, line 29):
   vendor_id UUID REFERENCES vendors(id) -- ✅ Correct column
   ```

2. **clubs.owner_id vs clubs.user_id**
   ```sql
   -- RLS policies reference:
   SELECT id FROM clubs WHERE owner_id = auth.uid()

   -- But schema may have:
   user_id UUID REFERENCES vendors(id)
   ```

3. **Non-existent tables in policies:**
   - `promo_codes` table (referenced in 003_events_rls_policies.sql:44)
   - `shifts` table (referenced in 003_events_rls_policies.sql:55)

**Severity:** 🔴 **CRITICAL - Runtime Failures**

**Impact:**
- RLS policies will FAIL when executed
- Queries will error out
- App will crash on certain operations

**Fix Required:**
1. Run schema inspection: `\d events`, `\d clubs` in psql
2. Update ALL policies to use correct column names
3. Remove policies referencing non-existent tables OR create those tables

---

### 6. inquiries, guest_list, scheduled_releases - Bad Policies

**Current Policies:**
```sql
-- From 01_actual_fix.sql
CREATE POLICY "Users can view inquiries for their events"
  ON inquiries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = inquiries.event_id
      AND events.user_id = auth.uid() -- ❌ Wrong column!
    )
  );
```

**Problems:**
1. References `events.user_id` (should be `events.vendor_id`)
2. If foreign key exists but column renamed, policy will fail silently
3. Policy shows enabled but doesn't work → false sense of security

**Severity:** ⚠️ **HIGH - Security Misconfiguration**

**Fix Required:**
```sql
-- Update all policies to use vendor_id
CREATE OR REPLACE POLICY "Users can view inquiries for their events"
  ON inquiries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = inquiries.event_id
      AND events.vendor_id = auth.uid()
    )
  );

-- Repeat for guest_list, scheduled_releases
```

---

## ⚠️ HIGH PRIORITY ISSUES

### 7. Table Naming Inconsistency: bookings vs events_bookings

**Problem:**
- Base schema creates table `bookings` (database_setup.sql:58)
- App code uses `events_bookings` (90+ references in Dart files)
- Ad-hoc fix migrations add columns to `events_bookings`
- Views join on `events_bookings`

**Current State:**
```dart
// Code expects:
supabase.from('events_bookings') // Used in 15+ files

// But schema may have:
CREATE TABLE bookings (...) // From database_setup.sql
```

**Impact:**
- Runtime errors: "relation 'events_bookings' does not exist"
- OR: duplicate tables with split data
- Data inconsistency

**Fix Options:**
1. **Rename in database:**
   ```sql
   ALTER TABLE bookings RENAME TO events_bookings;
   -- Update all foreign keys, indexes, policies
   ```

2. **Update all code:**
   ```dart
   // Change 90+ instances:
   .from('events_bookings') → .from('bookings')
   ```

**Recommendation:** Option 1 (rename in DB) - less code changes

---

### 8. Missing Tables Referenced by Code

**Tables used in app but missing from migrations:**

| Table | References | Impact |
|-------|------------|--------|
| `vendor_inventory` | 6 files | Dashboard inventory display fails |
| `vendor_events` | 4 files | Event queries fail |
| `vendor_bookings` | 3 files | Booking queries fail |
| `categories` | 3 files | Event categorization fails |
| `zones` | 2 files | Venue zone management fails |
| `event_templates` | 2 files | Template feature broken |
| `promo_codes` | RLS policy | Promoter RLS checks fail |
| `shifts` | RLS policy | Staff RLS checks fail |
| `vendor_details` | 9 files | Vendor profile fails |
| `venue_requests` | 13 files | Venue booking requests broken |

**Severity:** ⚠️ **HIGH - App Functionality Broken**

**Fix Required:**
1. Determine if these are:
   - Views that need creating
   - Tables that need migration files
   - Renamed tables (e.g., `inventory` → `vendor_inventory`)
2. Create missing migrations or views
3. Or update code to use existing table names

---

## 📋 MEDIUM PRIORITY ISSUES

### 9. Storage Bucket Policies - Overly Permissive

**Issue:** Some storage policies allow broad access

**Example:**
```sql
-- Anyone authenticated can view ALL venue gallery photos
CREATE POLICY "Authenticated users can view gallery photos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'venue-gallery');
```

**Recommendation:** Review if this is intentional for public venue galleries

---

### 10. subscription_plans Table - Public Read

**Current State:** No RLS on `subscription_plans`

**Analysis:**
- ✅ OK if subscription plans should be publicly viewable
- ❌ Problem if admin-only

**Recommendation:** Add read-only policy:
```sql
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view subscription plans"
  ON subscription_plans FOR SELECT
  TO authenticated
  USING (is_active = true);

CREATE POLICY "Only service role can modify plans"
  ON subscription_plans FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
```

---

## 🔧 REMEDIATION PLAN

### Phase 1: IMMEDIATE (Before ANY Production Deploy)

1. ✅ Run [verify_rls.sql](verify_rls.sql) to audit current state
2. ⚠️ Enable RLS on financial tables:
   - `stripe_accounts`
   - `payout_records`
   - `vendor_subscriptions`
3. ⚠️ Fix `venue_boosts` policy (remove `auth.uid() IS NOT NULL`)
4. ⚠️ Add policies for onboarding tables
5. ⚠️ Enable RLS on `event_team`, `ticket_types`

### Phase 2: HIGH PRIORITY (Next 48 Hours)

1. Fix column name mismatches (user_id → vendor_id)
2. Resolve `bookings` vs `events_bookings` inconsistency
3. Create missing tables or update code
4. Fix broken foreign key policies

### Phase 3: CLEANUP (Next Week)

1. Consolidate migrations (remove duplicate fixes)
2. Test all RLS policies with multiple test users
3. Add integration tests for security
4. Document RLS policy design

---

## 📊 COMPLIANCE IMPACT

### GDPR (EU Data Protection)

**Violations:**
- ❌ No access controls on personal data (staff profiles, ID docs)
- ❌ Data minimization principle violated (anyone can see all data)
- ❌ No audit trail for data access

**Penalty Risk:** Up to €20 million or 4% of annual revenue

### PCI DSS (Payment Card Industry)

**Violations:**
- ❌ Payment data not properly segmented
- ❌ No access controls on financial records

**Impact:** Cannot process card payments without compliance

### SOC 2 (Service Organization Control)

**Control Failures:**
- ❌ Logical access controls (CC6.1)
- ❌ Data classification (CC6.7)

---

## 🎯 SUCCESS CRITERIA

Database is production-ready when:

1. ✅ [verify_rls.sql](verify_rls.sql) shows 0 🔴 CRITICAL issues
2. ✅ All financial tables have vendor-scoped RLS
3. ✅ All personal data tables have RLS
4. ✅ No policies with `USING (auth.uid() IS NOT NULL)`
5. ✅ No policies with `USING (true)` for writes
6. ✅ All foreign key references valid
7. ✅ All tables used by app exist
8. ✅ Integration tests pass with multi-user scenarios

---

## 📞 NEXT STEPS

1. **Immediate:** Review this document with the team
2. **Immediate:** Run [verify_rls.sql](verify_rls.sql) on production Supabase
3. **Today:** Fix all 🔴 CRITICAL issues (Items 1-6)
4. **This Week:** Fix all ⚠️ HIGH issues (Items 7-8)
5. **Next Week:** Execute [MIGRATION_CONSOLIDATION_REPORT.md](MIGRATION_CONSOLIDATION_REPORT.md) plan
6. **Before Deploy:** Re-run verify_rls.sql and confirm 0 critical issues

---

**Document Maintained By:** Database Security Audit
**Last Updated:** 2026-06-12
**Status:** 🔴 ACTIVE CRITICAL ISSUES
