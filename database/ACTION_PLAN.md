# Supabase Production Readiness Action Plan

**Project:** Bottles Up Vendor App
**Date Created:** 2026-06-12
**Status:** 🔴 NOT PRODUCTION READY
**Target:** Make database production-safe within 48-72 hours

---

## 📋 Quick Reference

| Document | Purpose |
|----------|---------|
| **[SECURITY_ISSUES.md](SECURITY_ISSUES.md)** | 🔴 Critical security vulnerabilities - READ FIRST |
| **[MIGRATION_CONSOLIDATION_REPORT.md](MIGRATION_CONSOLIDATION_REPORT.md)** | Detailed migration analysis |
| **[verify_rls.sql](verify_rls.sql)** | SQL script to audit RLS status |
| **[archive/README.md](archive/README.md)** | Why certain files were archived |

---

## 🎯 GOALS

### Primary Goal
✅ Make Supabase database **production-safe** by fixing all CRITICAL security issues

### Secondary Goal
✅ Consolidate fragmented migrations into clean, maintainable structure

### Success Metrics
- ✅ verify_rls.sql shows 0 🔴 CRITICAL issues
- ✅ All financial/personal data protected by RLS
- ✅ All tables used by app exist and are accessible
- ✅ Clean migration history (14 numbered files, no ad-hoc fixes)

---

## ⚡ IMMEDIATE ACTIONS (Next 4 Hours)

### Step 1: Understand Current State (30 min)

1. **Read critical documents:**
   ```bash
   # In order of priority:
   cat database/SECURITY_ISSUES.md        # Critical vulnerabilities
   cat database/MIGRATION_CONSOLIDATION_REPORT.md  # Migration analysis
   ```

2. **Run RLS audit on your Supabase project:**
   - Open Supabase SQL Editor
   - Copy contents of `database/verify_rls.sql`
   - Run script
   - Save output for reference

3. **Identify which issues affect YOUR deployment:**
   - Are you using Stripe? → Issues 1, 4 are CRITICAL
   - Are you storing staff profiles? → Issue 3 is CRITICAL
   - Are you using venue boosts? → Issue 2 is CRITICAL

### Step 2: Fix CRITICAL Security Issues (3 hours)

**Priority Order:**

#### 🔴 Fix 1: Financial Data Protection (30 min)

**File to create:** `supabase/migrations/900_hotfix_financial_rls.sql`

```sql
-- Emergency RLS for financial tables
-- Run this IMMEDIATELY if using Stripe

-- stripe_accounts
ALTER TABLE IF EXISTS stripe_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors view own Stripe account" ON stripe_accounts;
CREATE POLICY "Vendors view own Stripe account"
  ON stripe_accounts FOR SELECT
  USING (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Service role manages Stripe accounts" ON stripe_accounts;
CREATE POLICY "Service role manages Stripe accounts"
  ON stripe_accounts FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- payout_records
ALTER TABLE IF EXISTS payout_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors view own payouts" ON payout_records;
CREATE POLICY "Vendors view own payouts"
  ON payout_records FOR SELECT
  USING (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Service role manages payouts" ON payout_records;
CREATE POLICY "Service role manages payouts"
  ON payout_records FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- vendor_subscriptions
ALTER TABLE IF EXISTS vendor_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors view own subscription" ON vendor_subscriptions;
CREATE POLICY "Vendors view own subscription"
  ON vendor_subscriptions FOR SELECT
  USING (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Service role manages subscriptions" ON vendor_subscriptions;
CREATE POLICY "Service role manages subscriptions"
  ON vendor_subscriptions FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
```

**How to apply:**
1. Copy SQL above to Supabase SQL Editor
2. Run it
3. Test by trying to query `SELECT * FROM stripe_accounts` as a non-owner vendor
4. Should return empty or only own records

#### 🔴 Fix 2: Venue Boosts Access Control (15 min)

**Add to same file** (`900_hotfix_financial_rls.sql`):

```sql
-- Fix venue_boosts dangerous policy
DROP POLICY IF EXISTS "Authenticated users can manage venue boosts" ON venue_boosts;
DROP POLICY IF EXISTS "Authenticated users can view venue boosts" ON venue_boosts;

-- FIRST: Determine correct foreign key
-- Run this to check venue_boosts structure:
-- \d venue_boosts;

-- OPTION A: If venue_boosts.venue_id → venues.id → venues.vendor_id:
CREATE POLICY "Venue owners manage their boosts"
  ON venue_boosts FOR ALL
  USING (
    venue_id IN (
      SELECT id FROM venues WHERE vendor_id = auth.uid()
    )
  );

-- OPTION B: If venue_boosts has vendor_id directly:
-- CREATE POLICY "Venue owners manage their boosts"
--   ON venue_boosts FOR ALL
--   USING (vendor_id = auth.uid());
```

#### 🔴 Fix 3: Onboarding Profile Access (30 min)

**Create:** `supabase/migrations/901_hotfix_profile_rls.sql`

```sql
-- RLS policies for onboarding tables

-- Staff Profiles
CREATE POLICY "Vendors manage own staff profile"
  ON staff_profiles FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Promoter Profiles
CREATE POLICY "Vendors manage own promoter profile"
  ON promoter_profiles FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Organizer Profiles
CREATE POLICY "Vendors manage own organizer profile"
  ON organizer_profiles FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Venue Details
CREATE POLICY "Venue owners manage details"
  ON venue_details FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

CREATE POLICY "Venue owners manage gallery"
  ON venue_gallery FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

CREATE POLICY "Venue owners manage documents"
  ON venue_documents FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

CREATE POLICY "Venue owners manage zones"
  ON venue_zones FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());
```

#### 🔴 Fix 4: Team & Ticket Tables RLS (30 min)

**Add to** `901_hotfix_profile_rls.sql`:

```sql
-- Enable RLS on event-related tables
ALTER TABLE IF EXISTS event_team ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS ticket_types ENABLE ROW LEVEL SECURITY;

-- Event Team policies
CREATE POLICY "Event creators manage team"
  ON event_team FOR ALL
  USING (
    event_id IN (
      SELECT id FROM events WHERE vendor_id = auth.uid()
    )
  )
  WITH CHECK (
    event_id IN (
      SELECT id FROM events WHERE vendor_id = auth.uid()
    )
  );

-- Ticket Types policies
CREATE POLICY "Event creators manage ticket types"
  ON ticket_types FOR ALL
  USING (
    event_id IN (
      SELECT id FROM events WHERE vendor_id = auth.uid()
    )
  )
  WITH CHECK (
    event_id IN (
      SELECT id FROM events WHERE vendor_id = auth.uid()
    )
  );
```

#### 🔴 Fix 5: Foreign Key Column Fixes (1 hour)

**Create:** `supabase/migrations/902_hotfix_column_references.sql`

```sql
-- Fix events RLS policies to use correct column name

-- First, check actual column name in events table:
-- \d events;
-- If column is vendor_id (not user_id), update policies:

DROP POLICY IF EXISTS "Organizers can view their events" ON events;
CREATE POLICY "Organizers can view their events"
  ON events FOR SELECT
  USING (vendor_id = auth.uid()); -- Changed from user_id

DROP POLICY IF EXISTS "Venue owners and organizers can create events" ON events;
CREATE POLICY "Venue owners and organizers can create events"
  ON events FOR INSERT
  WITH CHECK (
    vendor_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM vendors
      WHERE id = auth.uid()
      AND role IN ('venue_owner', 'organizer')
    )
  );

-- Fix inquiries, guest_list, scheduled_releases policies
DROP POLICY IF EXISTS "Users can view inquiries for their events" ON inquiries;
CREATE POLICY "Users can view inquiries for their events"
  ON inquiries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = inquiries.event_id
      AND events.vendor_id = auth.uid() -- Changed from user_id
    )
  );

DROP POLICY IF EXISTS "Event owners can manage guest list" ON guest_list;
CREATE POLICY "Event owners can manage guest list"
  ON guest_list FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = guest_list.event_id
      AND events.vendor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Event owners can manage releases" ON scheduled_releases;
CREATE POLICY "Event owners can manage releases"
  ON scheduled_releases FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = scheduled_releases.event_id
      AND events.vendor_id = auth.uid()
    )
  );
```

### Step 3: Verify Fixes (30 min)

1. **Re-run verify_rls.sql:**
   - Should show fewer 🔴 CRITICAL issues
   - All financial tables should show ✅ Protected

2. **Test with real user:**
   ```sql
   -- Create test vendor
   -- Login as that vendor
   -- Try to access another vendor's data
   SELECT * FROM stripe_accounts; -- Should only see own
   SELECT * FROM payout_records;   -- Should only see own
   ```

3. **Test app functionality:**
   - Run `flutter run`
   - Test onboarding screens (can save profiles?)
   - Test earnings screen (can view own Stripe data?)
   - Test event creation (can create events?)

---

## 📅 SHORT TERM ACTIONS (Next 48 Hours)

### Day 1 Afternoon: Fix Table Issues

#### Task 1: Resolve bookings vs events_bookings (2 hours)

**Option A: Rename in Database (RECOMMENDED)**

```sql
-- Check if events_bookings exists
SELECT EXISTS (
  SELECT 1 FROM pg_tables
  WHERE tablename = 'events_bookings'
);

-- If it doesn't exist but bookings does:
ALTER TABLE bookings RENAME TO events_bookings;

-- Update dependent objects:
-- (indexes, foreign keys, policies automatically updated by Postgres)
```

**Option B: Create Alias View**

```sql
-- If both tables exist with different data:
CREATE OR REPLACE VIEW events_bookings AS
SELECT * FROM bookings;

-- Allow writes through view:
CREATE RULE events_bookings_insert AS
  ON INSERT TO events_bookings
  DO INSTEAD
  INSERT INTO bookings VALUES (NEW.*);
-- (repeat for UPDATE, DELETE)
```

#### Task 2: Create Missing Tables (2 hours)

**Identify which are needed:**

```bash
# Search code for actual usage
grep -r "\.from('vendor_inventory')" lib/
grep -r "\.from('vendor_events')" lib/
grep -r "\.from('categories')" lib/
```

**Likely needed:**

```sql
-- If vendor_inventory is used but inventory exists:
CREATE OR REPLACE VIEW vendor_inventory AS
SELECT * FROM inventory;

-- If categories table is needed:
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- If zones table is needed:
CREATE TABLE zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID REFERENCES clubs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  capacity INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- etc.
```

### Day 2 Morning: Test Everything (3 hours)

1. **Unit test RLS policies:**
   - Create script that logs in as multiple vendors
   - Attempts to access each other's data
   - All should fail with no results

2. **Integration test app:**
   - Fresh install
   - Create new vendor account
   - Complete onboarding
   - Create event
   - Verify all screens work

3. **Load test:**
   - Create 10+ test vendors
   - Create 50+ events
   - Run analytics queries
   - Check performance

---

## 🗓️ MEDIUM TERM ACTIONS (Next 2 Weeks)

### Week 1: Migration Consolidation

**Goal:** Clean up migration files for maintainability

**Steps:**
1. Create consolidated migration files (001-014) as outlined in [MIGRATION_CONSOLIDATION_REPORT.md](MIGRATION_CONSOLIDATION_REPORT.md)
2. Test on fresh Supabase project
3. Compare schema with production using pg_dump
4. Create migration to update production to match consolidated schema

### Week 2: Documentation & Monitoring

1. **Create RLS Policy Documentation:**
   - Document every table's access rules
   - Explain business logic behind policies
   - Add examples

2. **Set up monitoring:**
   - Supabase Dashboard alerts for auth failures
   - Log analysis for RLS policy violations
   - Performance monitoring for complex RLS queries

3. **Security audit:**
   - Penetration test with multiple user accounts
   - Review Supabase logs for unauthorized access attempts
   - Compliance check (GDPR, PCI if applicable)

---

## 🎓 LONG TERM ACTIONS (Next Month)

1. **Automated Testing:**
   - CI/CD pipeline for migration testing
   - Automated RLS policy tests
   - Security regression tests

2. **Schema Versioning:**
   - Proper migration numbering system
   - Change log for each migration
   - Rollback procedures

3. **Access Control Refinement:**
   - Role-based access (admin, manager, staff)
   - Audit logging for sensitive operations
   - Data retention policies

---

## ✅ CHECKLIST: Pre-Production Deploy

Before deploying to production, verify:

### Security
- [ ] verify_rls.sql shows 0 🔴 CRITICAL issues
- [ ] All financial tables have RLS enabled with vendor-scoped policies
- [ ] All personal data tables have RLS enabled
- [ ] No policies with `USING (auth.uid() IS NOT NULL)` for ALL operations
- [ ] No policies with `USING (true)` for writes (except service_role)
- [ ] Storage buckets have appropriate policies

### Data Integrity
- [ ] All tables referenced by app exist
- [ ] All foreign keys use correct column names
- [ ] Table naming consistent (events_bookings vs bookings resolved)
- [ ] All views reference correct tables

### Functionality
- [ ] Onboarding screens save data successfully
- [ ] Stripe Connect integration works
- [ ] Earnings screen displays data
- [ ] Event creation/editing works
- [ ] Analytics dashboard loads
- [ ] Team management works
- [ ] Ticket types can be managed

### Performance
- [ ] RLS policies use indexed columns
- [ ] No slow queries (>100ms) on common operations
- [ ] Connection pooling configured
- [ ] Supabase plan appropriate for load

### Compliance
- [ ] GDPR data access controls in place
- [ ] PCI DSS requirements met (if processing payments)
- [ ] Data backup strategy defined
- [ ] Data retention policy implemented

---

## 📞 SUPPORT

If you need help:

1. **Supabase Issues:**
   - Check [Supabase Docs: Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
   - Supabase Discord: #help channel

2. **Flutter/Dart Issues:**
   - Check [supabase-flutter package](https://pub.dev/packages/supabase_flutter)
   - Flutter Discord: #supabase channel

3. **This Codebase:**
   - Review generated documentation in database/ folder
   - Run verify_rls.sql to check current state
   - Check SECURITY_ISSUES.md for known issues

---

## 📊 PROGRESS TRACKING

| Phase | Status | ETA |
|-------|--------|-----|
| Immediate Fixes (Critical Security) | ⏳ IN PROGRESS | 4 hours |
| Short Term (Table Issues) | 📋 PLANNED | 2 days |
| Medium Term (Migration Cleanup) | 📋 PLANNED | 2 weeks |
| Long Term (Automation) | 📋 PLANNED | 1 month |

**Last Updated:** 2026-06-12
**Next Review:** After completing Immediate Fixes (re-run verify_rls.sql)

---

## 🎯 TL;DR - DO THIS NOW

1. **Read:** [SECURITY_ISSUES.md](SECURITY_ISSUES.md) (10 min)
2. **Run:** [verify_rls.sql](verify_rls.sql) in Supabase (5 min)
3. **Fix:** Apply hotfix migrations 900-902 from above (3 hours)
4. **Test:** Re-run verify_rls.sql and verify 0 critical issues (30 min)
5. **Deploy:** Only after all 🔴 CRITICAL issues resolved

**Current Status:** 🔴 NOT READY FOR PRODUCTION
**After Fixes:** Should be ✅ READY FOR STAGING

Good luck! 🚀
