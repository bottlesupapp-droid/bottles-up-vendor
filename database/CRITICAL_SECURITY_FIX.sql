-- ============================================================================
-- CRITICAL SECURITY FIXES - Bottles Up Vendor Database
-- ============================================================================
-- Date: 2026-06-12
-- Purpose: Apply Row Level Security policies to tables with missing protection
-- IMPORTANT: Run this in Supabase SQL Editor BEFORE production deployment
-- ============================================================================

-- ============================================================================
-- 1. FINANCIAL TABLES - CRITICAL
-- ============================================================================
-- These tables contain sensitive payment and subscription data

-- Stripe Accounts Table
ALTER TABLE IF EXISTS stripe_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors view own Stripe account" ON stripe_accounts;
CREATE POLICY "Vendors view own Stripe account"
  ON stripe_accounts FOR SELECT
  USING (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Vendors update own Stripe account" ON stripe_accounts;
CREATE POLICY "Vendors update own Stripe account"
  ON stripe_accounts FOR UPDATE
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Payout Records Table
ALTER TABLE IF EXISTS payout_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors view own payouts" ON payout_records;
CREATE POLICY "Vendors view own payouts"
  ON payout_records FOR SELECT
  USING (vendor_id = auth.uid());

-- Vendor Subscriptions Table
ALTER TABLE IF EXISTS vendor_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors view own subscription" ON vendor_subscriptions;
CREATE POLICY "Vendors view own subscription"
  ON vendor_subscriptions FOR SELECT
  USING (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Vendors update own subscription" ON vendor_subscriptions;
CREATE POLICY "Vendors update own subscription"
  ON vendor_subscriptions FOR UPDATE
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- ============================================================================
-- 2. TEAM & TICKET TABLES - CRITICAL
-- ============================================================================
-- These tables were created without RLS enabled

-- Event Team Members Table
ALTER TABLE IF EXISTS event_team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Event creators manage team" ON event_team_members;
CREATE POLICY "Event creators manage team"
  ON event_team_members FOR ALL
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

-- Ticket Types Table
ALTER TABLE IF EXISTS ticket_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Event creators manage ticket types" ON ticket_types;
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

-- ============================================================================
-- 3. ONBOARDING TABLES - FIX MISSING POLICIES
-- ============================================================================
-- These tables have RLS enabled but some policies may be missing or incorrect

-- Staff Profiles - Add missing INSERT/UPDATE/DELETE policies
DROP POLICY IF EXISTS "Staff manage own profile" ON staff_profiles;
CREATE POLICY "Staff manage own profile"
  ON staff_profiles FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Promoter Profiles - Add missing INSERT/UPDATE/DELETE policies
DROP POLICY IF EXISTS "Promoters manage own profile" ON promoter_profiles;
CREATE POLICY "Promoters manage own profile"
  ON promoter_profiles FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Organizer Profiles - Add missing INSERT/UPDATE/DELETE policies
DROP POLICY IF EXISTS "Organizers manage own profile" ON organizer_profiles;
CREATE POLICY "Organizers manage own profile"
  ON organizer_profiles FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Venue Details - Add missing INSERT/UPDATE/DELETE policies
DROP POLICY IF EXISTS "Venue owners manage details" ON venue_details;
CREATE POLICY "Venue owners manage details"
  ON venue_details FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Venue Gallery - Add missing INSERT/UPDATE/DELETE policies
DROP POLICY IF EXISTS "Venue owners manage gallery" ON venue_gallery;
CREATE POLICY "Venue owners manage gallery"
  ON venue_gallery FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Venue Documents - Add missing INSERT/UPDATE/DELETE policies
DROP POLICY IF EXISTS "Venue owners manage documents" ON venue_documents;
CREATE POLICY "Venue owners manage documents"
  ON venue_documents FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Venue Zones - Add missing INSERT/UPDATE/DELETE policies
DROP POLICY IF EXISTS "Venue owners manage zones" ON venue_zones;
CREATE POLICY "Venue owners manage zones"
  ON venue_zones FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- Venue Bottle Menu - Add missing policies
DROP POLICY IF EXISTS "Venue owners manage bottle menu" ON venue_bottle_menu;
CREATE POLICY "Venue owners manage bottle menu"
  ON venue_bottle_menu FOR ALL
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- ============================================================================
-- 4. SUBSCRIPTION PLANS - PUBLIC READ ONLY
-- ============================================================================
-- Subscription plans should be viewable by all users but only modifiable by service role

ALTER TABLE IF EXISTS subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active subscription plans" ON subscription_plans;
CREATE POLICY "Anyone can view active subscription plans"
  ON subscription_plans FOR SELECT
  TO authenticated
  USING (is_active = true);

-- ============================================================================
-- 5. PROMOTER EVENT ASSIGNMENTS - ADD MISSING POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Promoters view own assignments" ON promoter_event_assignments;
CREATE POLICY "Promoters view own assignments"
  ON promoter_event_assignments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM promoter_profiles
      WHERE promoter_profiles.id = promoter_event_assignments.promoter_id
      AND promoter_profiles.vendor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Organizers manage assignments" ON promoter_event_assignments;
CREATE POLICY "Organizers manage assignments"
  ON promoter_event_assignments FOR ALL
  USING (organizer_id = auth.uid())
  WITH CHECK (organizer_id = auth.uid());

-- ============================================================================
-- 6. STAFF SHIFTS - ADD MISSING POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Staff view own shifts" ON staff_shifts;
CREATE POLICY "Staff view own shifts"
  ON staff_shifts FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM staff_profiles
      WHERE staff_profiles.id = staff_shifts.staff_id
      AND staff_profiles.vendor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Venue owners manage shifts" ON staff_shifts;
CREATE POLICY "Venue owners manage shifts"
  ON staff_shifts FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM venue_details
      WHERE venue_details.id = staff_shifts.venue_id
      AND venue_details.vendor_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM venue_details
      WHERE venue_details.id = staff_shifts.venue_id
      AND venue_details.vendor_id = auth.uid()
    )
  );

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Run this query to verify all critical tables now have RLS enabled:

SELECT
  tablename,
  CASE WHEN rowsecurity THEN '✅ ENABLED' ELSE '❌ DISABLED' END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'stripe_accounts',
    'payout_records',
    'vendor_subscriptions',
    'event_team_members',
    'ticket_types',
    'staff_profiles',
    'promoter_profiles',
    'organizer_profiles',
    'venue_details',
    'venue_gallery',
    'venue_documents',
    'venue_zones',
    'venue_bottle_menu',
    'subscription_plans'
  )
ORDER BY tablename;

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- All tables should show '✅ ENABLED'
-- If any show '❌ DISABLED', that table either:
-- 1. Does not exist in your database (safe to ignore)
-- 2. Needs RLS enabled manually
--
-- After running this script, re-run the verify_rls.sql script to confirm
-- all critical issues are resolved.
-- ============================================================================
