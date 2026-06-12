# Database Security Fix - Step-by-Step Instructions

## The Problem

The SQL scripts are failing because they were written based on migration files, but your actual Supabase database schema may be different from what's in the migration files.

**Error you're seeing:**
```
ERROR: 42703: column "vendor_id" does not exist
```

This means the table doesn't have a `vendor_id` column - it might have a different column name or structure.

## The Solution - 3 Steps

### STEP 1: Diagnose Your Actual Schema (5 minutes)

1. Open **Supabase SQL Editor** (go to your Supabase project → SQL Editor)
2. Copy the **entire contents** of [`database/DIAGNOSE_SCHEMA.sql`](database/DIAGNOSE_SCHEMA.sql)
3. Paste into SQL Editor
4. Click **Run**
5. **Save the output** or keep the tab open

This will show us:
- ✅ Which tables actually exist in your database
- ✅ What columns each table has
- ✅ What data types are used
- ✅ What RLS policies already exist

### STEP 2: Share the Output

You have two options:

**Option A: Create a file with the output**
1. Copy the query results from Supabase SQL Editor
2. Save to a file: `database/ACTUAL_SCHEMA_OUTPUT.txt`
3. Then I can generate the correct SQL

**Option B: Tell me what you see**

Just tell me the key findings:
- Does `event_team_members` table exist? If yes, what columns does it have?
- Does `ticket_types` table exist? If yes, what columns does it have?
- Does `stripe_accounts` exist? Does it have a `vendor_id` column?
- What data type is `events.id`? (TEXT or UUID?)

### STEP 3: Apply the Correct Fix

Once we know the actual schema, I'll generate a SQL script that:
- ✅ Only references tables that exist
- ✅ Only references columns that exist
- ✅ Uses correct data types for joins
- ✅ Won't cause any errors

## Why This Happened

There's a mismatch between your migration files and the actual database:

### Migration Files Say:
```sql
-- From database/migrations/005_update_event_team_members_table.sql
CREATE TABLE event_team_members (
    id UUID,
    event_id UUID,  -- References events(id)
    ...
);
```

### But Database Setup Says:
```sql
-- From database_setup.sql
CREATE TABLE events (
    id TEXT PRIMARY KEY,  -- TEXT, not UUID!
    ...
);
```

This creates a **type mismatch** - you can't have a UUID foreign key pointing to a TEXT primary key.

## Possible Scenarios

### Scenario 1: Tables Don't Exist Yet
If `event_team_members` and `ticket_types` don't exist, we need to:
1. Skip RLS policies for those tables (they're not created yet)
2. Only fix the tables that do exist

### Scenario 2: Tables Exist with Different Columns
If tables exist but with different column names, we need to:
1. Use the correct column names in RLS policies
2. Adjust the join conditions

### Scenario 3: Events Table Was Never Migrated
If your `events` table still has `id TEXT` (not UUID), we need to:
1. Either migrate the events table to use UUID
2. Or adjust foreign key references to match TEXT type

## Quick Check - Run This Now

Run this single query in Supabase SQL Editor to quickly check:

```sql
-- Quick check: Which critical tables exist and have vendor_id?
SELECT
  t.tablename,
  CASE WHEN c.column_name IS NOT NULL THEN '✅ Has vendor_id' ELSE '❌ No vendor_id' END as has_vendor_id,
  CASE WHEN t.rowsecurity THEN '✅ RLS ON' ELSE '❌ RLS OFF' END as rls_status
FROM pg_tables t
LEFT JOIN information_schema.columns c
  ON c.table_name = t.tablename
  AND c.column_name = 'vendor_id'
  AND c.table_schema = 'public'
WHERE t.schemaname = 'public'
  AND t.tablename IN (
    'event_team_members',
    'ticket_types',
    'stripe_accounts',
    'payout_records',
    'vendor_subscriptions',
    'staff_profiles',
    'promoter_profiles',
    'organizer_profiles',
    'venue_details'
  )
ORDER BY t.tablename;
```

**Expected output format:**
```
tablename               | has_vendor_id      | rls_status
------------------------|--------------------|-----------
event_team_members      | ❌ No vendor_id    | ❌ RLS OFF
stripe_accounts         | ✅ Has vendor_id   | ❌ RLS OFF
ticket_types            | ❌ No vendor_id    | ❌ RLS OFF
...
```

This will tell us immediately which tables need vendor_id-based policies vs event_id-based policies.

## What Happens Next

Once you run the diagnostic and share the output:

1. I'll generate a **custom SQL script** for YOUR exact database schema
2. The script will be 100% accurate and won't cause errors
3. You'll paste it into Supabase and run it
4. All security issues will be fixed in ~5 minutes

## Files Reference

- **[`database/DIAGNOSE_SCHEMA.sql`](database/DIAGNOSE_SCHEMA.sql)** - Full diagnostic (run this first)
- **Quick check SQL** - Single query above (fastest way to check)
- **`database/CRITICAL_SECURITY_FIX.sql`** - Don't use yet (based on migration files, not actual schema)

## Questions?

If you're not sure how to run SQL in Supabase:

1. Go to https://supabase.com/dashboard
2. Select your project
3. Click "SQL Editor" in left sidebar
4. Click "+ New query"
5. Paste the SQL
6. Click "Run" (or press Cmd/Ctrl + Enter)

---

**Next Step:** Run the quick check SQL above and share the output, then we'll generate the perfect fix!
