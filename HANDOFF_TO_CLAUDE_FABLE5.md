# Handoff to Claude Fable 5 - Database Security Fix

## Context
This is a Flutter app (Bottles Up Vendor) using Supabase as backend. We're trying to fix **6 critical database security vulnerabilities** by enabling Row Level Security (RLS) policies.

## The Problem

### What We're Trying to Do
Apply RLS policies to protect sensitive data:
- Financial tables: `stripe_accounts`, `payout_records`, `vendor_subscriptions`
- Event management: `event_team_members`, `ticket_types`
- Onboarding tables: `staff_profiles`, `promoter_profiles`, `organizer_profiles`, `venue_details`

### Why It's Failing
**Type mismatch error:**
```
ERROR: 42883: operator does not exist: uuid = text
HINT: No operator matches the given name and argument types. You might need to add explicit type casts.
```

**The issue:** We don't know the actual data types in the live Supabase database.

### What We Know from Diagnostic
From running a schema diagnostic query, we found:

| Table | Has vendor_id? | RLS Status |
|-------|---------------|------------|
| event_team_members | ❌ No | ❌ OFF |
| ticket_types | ❌ No | ✅ ON |
| stripe_accounts | ✅ Yes | ❌ OFF |
| payout_records | ✅ Yes | ❌ OFF |
| vendor_subscriptions | ✅ Yes | ❌ OFF |

**Key finding:** `event_team_members` and `ticket_types` don't have `vendor_id`, so they need to JOIN through the `events` table.

## The Type Mismatch Problem

### From Migration Files
```sql
-- database_setup.sql
CREATE TABLE events (
    id TEXT PRIMARY KEY,  -- ❌ TEXT!
    ...
);

-- database/migrations/005_update_event_team_members_table.sql
CREATE TABLE event_team_members (
    id UUID,
    event_id UUID REFERENCES events(id),  -- ❌ UUID references TEXT!
    ...
);
```

### Our Attempted Fix (Failed)
```sql
-- database/FIX_RLS_CUSTOM.sql line 76
CREATE POLICY "Event creators manage team"
  ON event_team_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_team_members.event_id::text  -- ❌ Fails here
      AND events.vendor_id = auth.uid()
    )
  );
```

**Error:** If `event_team_members.event_id` is UUID and `events.id` is TEXT, we can't cast UUID to text in comparison.

## What We Need You to Do

### Step 1: Determine Actual Data Types

Run this query in Supabase SQL Editor to see the REAL data types:

```sql
-- Check events table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'events'
ORDER BY ordinal_position;

-- Check event_team_members table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'event_team_members'
ORDER BY ordinal_position;

-- Check ticket_types table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'ticket_types'
ORDER BY ordinal_position;
```

### Step 2: Generate Correct RLS Policies

Based on the actual data types, create policies that work. Here are the scenarios:

#### Scenario A: Both are TEXT
```sql
CREATE POLICY "Event creators manage team"
  ON event_team_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_team_members.event_id  -- No cast needed
      AND events.vendor_id = auth.uid()
    )
  );
```

#### Scenario B: Both are UUID
```sql
CREATE POLICY "Event creators manage team"
  ON event_team_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_team_members.event_id  -- No cast needed
      AND events.vendor_id = auth.uid()
    )
  );
```

#### Scenario C: events.id is TEXT, event_team_members.event_id is UUID
```sql
CREATE POLICY "Event creators manage team"
  ON event_team_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_team_members.event_id::text  -- Cast UUID to TEXT
      AND events.vendor_id = auth.uid()
    )
  );
```

#### Scenario D: events.id is UUID, event_team_members.event_id is TEXT
```sql
CREATE POLICY "Event creators manage team"
  ON event_team_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id::text = event_team_members.event_id  -- Cast UUID to TEXT
      AND events.vendor_id = auth.uid()
    )
  );
```

### Step 3: Create Final SQL Script

Generate a complete SQL script that:

1. **Enables RLS** on critical tables:
   - `stripe_accounts`
   - `payout_records`
   - `vendor_subscriptions`
   - `event_team_members`

2. **Adds policies** for tables with `vendor_id`:
   ```sql
   CREATE POLICY "Vendors manage own data"
     ON table_name FOR ALL
     USING (vendor_id = auth.uid())
     WITH CHECK (vendor_id = auth.uid());
   ```

3. **Adds policies** for tables with `event_id` (using correct type cast):
   ```sql
   CREATE POLICY "Event creators manage data"
     ON table_name FOR ALL
     USING (
       EXISTS (
         SELECT 1 FROM events
         WHERE events.id [CORRECT_COMPARISON] table_name.event_id
         AND events.vendor_id = auth.uid()
       )
     );
   ```

4. **Conditionally handles** optional tables:
   - `staff_profiles`, `promoter_profiles`, `organizer_profiles`
   - `venue_details`, `venue_gallery`, `venue_documents`, `venue_zones`

   Use `DO $$ ... END $$` blocks to check if they exist first.

5. **Includes verification** at the end:
   ```sql
   SELECT tablename, rowsecurity
   FROM pg_tables
   WHERE schemaname = 'public'
     AND tablename IN ('stripe_accounts', 'payout_records', ...);
   ```

## Files to Reference

### Current Attempt (Has Type Error)
- [`database/FIX_RLS_CUSTOM.sql`](database/FIX_RLS_CUSTOM.sql) - Lines 76-87 and 94-105 have the type cast issue

### Migration Files (May Not Match Reality)
- `database_setup.sql` - Says events.id is TEXT
- `database/migrations/005_update_event_team_members_table.sql` - Says event_id is UUID
- `database/migrations/004_update_ticket_types_table.sql` - Says event_id is UUID

### Diagnostic Tools
- [`database/DIAGNOSE_SCHEMA.sql`](database/DIAGNOSE_SCHEMA.sql) - Full schema inspection queries

### Documentation
- [`DATABASE_SECURITY_FIX_INSTRUCTIONS.md`](DATABASE_SECURITY_FIX_INSTRUCTIONS.md) - Background
- [`database/SECURITY_ISSUES.md`](database/SECURITY_ISSUES.md) - Security audit details

## Expected Deliverable

A single SQL file (e.g., `database/FIX_RLS_FINAL.sql`) that:
- ✅ Runs without errors
- ✅ Enables RLS on all critical tables
- ✅ Creates policies with correct type casts
- ✅ Handles optional tables gracefully
- ✅ Includes verification query
- ✅ Is safe to run multiple times

## Success Criteria

After running the SQL, this verification should show all `✅ RLS ENABLED`:

```sql
SELECT
  tablename,
  CASE WHEN rowsecurity THEN '✅ RLS ENABLED' ELSE '❌ RLS DISABLED' END as status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'stripe_accounts',
    'payout_records',
    'vendor_subscriptions',
    'event_team_members',
    'ticket_types'
  )
ORDER BY tablename;
```

## Questions to Answer

1. What is the actual data type of `events.id` in the live database?
2. What is the actual data type of `event_team_members.event_id`?
3. What is the actual data type of `ticket_types.event_id`?
4. Do the onboarding tables exist? (staff_profiles, promoter_profiles, etc.)

Once you have these answers, you can generate the perfect SQL script.

## Security Impact

🔴 **CRITICAL:** Production deployment is blocked until this is fixed.

**Current exposure:**
- Any vendor can see ALL Stripe account data
- Any vendor can see ALL payout records
- Any vendor can see ALL subscription data
- Any vendor can see/modify ALL event teams
- Any vendor can see/modify ALL ticket pricing

**After fix:**
- Vendors can ONLY see their own financial data
- Vendors can ONLY manage their own event teams/tickets
- Data properly isolated by vendor

## Timeline

This is the ONLY blocker to production. Everything else is ready:
- ✅ Phase 1: Vendor onboarding complete
- ✅ Phase 2: Stripe edge functions ready
- ❌ Phase 3: Database security **← BLOCKED HERE**
- ✅ Phase 5: Production hardening complete

**Target:** Get the data types, generate SQL, apply fix in ~15 minutes

---

**Start Here:** Run the column inspection queries in Step 1, then generate the correct SQL based on actual data types.
