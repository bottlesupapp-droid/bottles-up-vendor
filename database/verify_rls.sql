-- ============================================================================
-- RLS VERIFICATION SCRIPT
-- ============================================================================
-- Purpose: Comprehensive audit of Row Level Security across all tables
-- Run this in Supabase SQL Editor to verify RLS status and policies
-- Date: 2026-06-12
-- ============================================================================

-- ============================================================================
-- PART 1: RLS STATUS FOR ALL TABLES
-- ============================================================================

SELECT
    '=== RLS ENABLED STATUS ===' as section;

SELECT
    schemaname,
    tablename,
    CASE
        WHEN rowsecurity THEN '✅ ENABLED'
        ELSE '❌ DISABLED'
    END as rls_status,
    CASE
        WHEN rowsecurity THEN 'OK'
        WHEN tablename LIKE 'v_%' THEN 'N/A (View)'
        WHEN schemaname = 'storage' THEN 'Check storage policies'
        ELSE '🔴 CRITICAL - Enable RLS!'
    END as recommendation
FROM pg_tables
WHERE schemaname IN ('public', 'storage')
ORDER BY
    CASE WHEN rowsecurity THEN 1 ELSE 0 END,
    schemaname,
    tablename;

-- ============================================================================
-- PART 2: POLICY COUNT PER TABLE
-- ============================================================================

SELECT
    '=== POLICY COUNT PER TABLE ===' as section;

SELECT
    t.schemaname,
    t.tablename,
    CASE
        WHEN t.rowsecurity THEN '✅ Yes'
        ELSE '❌ No'
    END as rls_enabled,
    COUNT(p.policyname) as policy_count,
    CASE
        WHEN COUNT(p.policyname) = 0 AND t.rowsecurity THEN '🔴 CRITICAL - RLS enabled but NO policies!'
        WHEN COUNT(p.policyname) = 0 THEN '❌ No RLS, No policies'
        WHEN COUNT(p.policyname) < 4 THEN '⚠️  May need more policies (SELECT/INSERT/UPDATE/DELETE)'
        ELSE '✅ Has policies'
    END as status
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname IN ('public', 'storage')
GROUP BY t.schemaname, t.tablename, t.rowsecurity
ORDER BY policy_count ASC, t.tablename;

-- ============================================================================
-- PART 3: DETAILED POLICY LISTING
-- ============================================================================

SELECT
    '=== ALL POLICIES DETAIL ===' as section;

SELECT
    schemaname,
    tablename,
    policyname,
    CASE cmd
        WHEN '*' THEN 'ALL'
        ELSE cmd::text
    END as operation,
    CASE permissive
        WHEN 'PERMISSIVE' THEN '✅ Permissive'
        ELSE '⚠️  Restrictive'
    END as type,
    roles::text as applies_to,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE schemaname IN ('public', 'storage')
ORDER BY schemaname, tablename, policyname;

-- ============================================================================
-- PART 4: CRITICAL SECURITY CHECKS
-- ============================================================================

SELECT
    '=== CRITICAL SECURITY ISSUES ===' as section;

-- Check 1: Tables with RLS enabled but NO policies (data is invisible!)
SELECT
    '🔴 RLS Enabled but NO Policies (Table is invisible to users!)' as issue_type,
    t.tablename,
    'Enable policies or disable RLS' as action
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname = 'public'
    AND t.rowsecurity = true
    AND p.policyname IS NULL
GROUP BY t.tablename;

-- Check 2: Tables with NO RLS (data accessible to all!)
SELECT
    '🔴 RLS DISABLED (Data accessible to all authenticated users!)' as issue_type,
    tablename,
    'ALTER TABLE ' || tablename || ' ENABLE ROW LEVEL SECURITY;' as action
FROM pg_tables
WHERE schemaname = 'public'
    AND rowsecurity = false
    AND tablename NOT LIKE 'v_%'; -- Exclude views

-- Check 3: Policies with USING (true) for writes (allows any data!)
SELECT
    '⚠️  Policy with USING (true) - Allows unrestricted access!' as issue_type,
    tablename,
    policyname,
    cmd::text as operation,
    'Review and restrict this policy' as action
FROM pg_policies
WHERE schemaname = 'public'
    AND (
        qual::text ILIKE '%true%'
        OR with_check::text ILIKE '%true%'
    );

-- Check 4: Tables accessed by app but missing from database
SELECT
    '⚠️  Table referenced in code but may not exist' as issue_type,
    table_name,
    'Verify table exists or create it' as action
FROM (
    VALUES
        ('vendor_inventory'),
        ('vendor_events'),
        ('vendor_bookings'),
        ('categories'),
        ('zones'),
        ('event_templates'),
        ('promo_codes'),
        ('shifts')
) AS referenced(table_name)
WHERE NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE tablename = referenced.table_name
    AND schemaname = 'public'
);

-- ============================================================================
-- PART 5: STORAGE BUCKET POLICIES
-- ============================================================================

SELECT
    '=== STORAGE BUCKET POLICIES ===' as section;

SELECT
    bucket_id,
    COUNT(*) as policy_count,
    array_agg(DISTINCT operation) as operations_covered
FROM storage.objects
JOIN pg_policies ON pg_policies.tablename = 'objects'
GROUP BY bucket_id
ORDER BY bucket_id;

-- Alternative storage bucket check
SELECT
    id as bucket_name,
    public as is_public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
ORDER BY id;

-- ============================================================================
-- PART 6: SPECIFIC TABLE SECURITY AUDIT
-- ============================================================================

SELECT
    '=== FINANCIAL DATA TABLES ===' as section;

-- Check RLS on financial tables
SELECT
    tablename,
    CASE WHEN rowsecurity THEN '✅ Protected' ELSE '🔴 EXPOSED!' END as status
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'stripe_accounts',
        'payout_records',
        'vendor_subscriptions',
        'subscription_plans',
        'events_bookings',
        'bookings'
    )
ORDER BY tablename;

SELECT
    '=== USER DATA TABLES ===' as section;

-- Check RLS on user profile tables
SELECT
    tablename,
    CASE WHEN rowsecurity THEN '✅ Protected' ELSE '🔴 EXPOSED!' END as status
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'vendors',
        'staff_profiles',
        'promoter_profiles',
        'organizer_profiles',
        'venue_details',
        'vendor_details'
    )
ORDER BY tablename;

-- ============================================================================
-- PART 7: RECOMMENDATIONS SUMMARY
-- ============================================================================

SELECT
    '=== RECOMMENDATIONS SUMMARY ===' as section;

WITH rls_stats AS (
    SELECT
        COUNT(*) FILTER (WHERE rowsecurity = false) as tables_without_rls,
        COUNT(*) FILTER (WHERE rowsecurity = true) as tables_with_rls,
        COUNT(*) as total_tables
    FROM pg_tables
    WHERE schemaname = 'public'
        AND tablename NOT LIKE 'v_%'
),
policy_stats AS (
    SELECT
        COUNT(DISTINCT t.tablename) FILTER (
            WHERE t.rowsecurity = true AND p.policyname IS NULL
        ) as tables_rls_no_policies,
        COUNT(DISTINCT p.tablename) as tables_with_policies
    FROM pg_tables t
    LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
    WHERE t.schemaname = 'public'
        AND t.tablename NOT LIKE 'v_%'
)
SELECT
    r.total_tables as total_public_tables,
    r.tables_with_rls as has_rls_enabled,
    r.tables_without_rls as missing_rls,
    p.tables_with_policies as has_policies,
    p.tables_rls_no_policies as rls_enabled_but_no_policies,
    CASE
        WHEN r.tables_without_rls > 0 OR p.tables_rls_no_policies > 0 THEN '🔴 CRITICAL - Fix immediately!'
        WHEN p.tables_with_policies < r.total_tables * 0.8 THEN '⚠️  WARNING - Many tables lack policies'
        ELSE '✅ GOOD - Most tables protected'
    END as overall_security_status
FROM rls_stats r, policy_stats p;

-- ============================================================================
-- USAGE INSTRUCTIONS
-- ============================================================================

/*
HOW TO USE THIS SCRIPT:
1. Copy entire script to Supabase SQL Editor
2. Run script (it's read-only, safe to run multiple times)
3. Review each section output:
   - Section 1: Lists all tables and RLS status
   - Section 2: Shows policy count (need at least SELECT policy)
   - Section 3: Details every policy
   - Section 4: **MOST IMPORTANT** - Lists critical security issues
   - Section 5: Storage bucket security
   - Section 6: Specific audit of financial/user tables
   - Section 7: Overall recommendation

INTERPRETING RESULTS:
- 🔴 CRITICAL: Must fix before production
- ⚠️  WARNING: Should fix soon
- ✅ OK: No immediate action needed

NEXT STEPS:
1. Fix all 🔴 CRITICAL issues first
2. Address ⚠️  warnings
3. Re-run this script to verify fixes
*/
