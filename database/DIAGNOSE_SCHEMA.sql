-- ============================================================================
-- DATABASE SCHEMA DIAGNOSTIC
-- ============================================================================
-- Purpose: Inspect actual table structures in your Supabase database
-- Run this in Supabase SQL Editor to see what tables and columns exist
-- ============================================================================

-- ============================================================================
-- 1. LIST ALL TABLES
-- ============================================================================
SELECT
  '=== ALL TABLES IN PUBLIC SCHEMA ===' as section;

SELECT
  tablename,
  CASE WHEN rowsecurity THEN '✅ RLS ON' ELSE '❌ RLS OFF' END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================================================
-- 2. CRITICAL TABLES - DETAILED COLUMN INSPECTION
-- ============================================================================

-- Check if event_team_members exists and what columns it has
SELECT
  '=== TABLE: event_team_members ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'event_team_members'
ORDER BY ordinal_position;

-- Check ticket_types
SELECT
  '=== TABLE: ticket_types ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'ticket_types'
ORDER BY ordinal_position;

-- Check stripe_accounts
SELECT
  '=== TABLE: stripe_accounts ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'stripe_accounts'
ORDER BY ordinal_position;

-- Check payout_records
SELECT
  '=== TABLE: payout_records ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'payout_records'
ORDER BY ordinal_position;

-- Check vendor_subscriptions
SELECT
  '=== TABLE: vendor_subscriptions ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'vendor_subscriptions'
ORDER BY ordinal_position;

-- Check events table (IMPORTANT - check if id is TEXT or UUID)
SELECT
  '=== TABLE: events ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'events'
ORDER BY ordinal_position;

-- Check staff_profiles
SELECT
  '=== TABLE: staff_profiles ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'staff_profiles'
ORDER BY ordinal_position;

-- Check promoter_profiles
SELECT
  '=== TABLE: promoter_profiles ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'promoter_profiles'
ORDER BY ordinal_position;

-- Check organizer_profiles
SELECT
  '=== TABLE: organizer_profiles ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'organizer_profiles'
ORDER BY ordinal_position;

-- Check venue_details
SELECT
  '=== TABLE: venue_details ===' as section;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'venue_details'
ORDER BY ordinal_position;

-- ============================================================================
-- 3. CHECK FOREIGN KEY RELATIONSHIPS
-- ============================================================================

SELECT
  '=== FOREIGN KEY CONSTRAINTS ===' as section;

SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.table_name IN (
    'event_team_members',
    'ticket_types',
    'stripe_accounts',
    'payout_records',
    'vendor_subscriptions'
  )
ORDER BY tc.table_name, kcu.column_name;

-- ============================================================================
-- 4. CURRENT RLS POLICIES
-- ============================================================================

SELECT
  '=== EXISTING RLS POLICIES ON CRITICAL TABLES ===' as section;

SELECT
  tablename,
  policyname,
  CASE cmd
    WHEN '*' THEN 'ALL'
    ELSE cmd::text
  END as operation,
  qual as using_clause
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
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
ORDER BY tablename, policyname;

-- ============================================================================
-- INSTRUCTIONS
-- ============================================================================

/*
HOW TO USE:
1. Copy this entire script
2. Paste into Supabase SQL Editor
3. Run it
4. Send the output back so we can create accurate RLS policies

WHAT THIS TELLS US:
- Which tables actually exist
- What columns each table has (especially vendor_id vs event_id)
- What data types are used (TEXT vs UUID for event IDs)
- What foreign keys exist
- What RLS policies are already in place

This will let us write 100% accurate security policies.
*/
