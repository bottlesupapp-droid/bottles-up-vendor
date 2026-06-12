-- ============================================================================
-- CUSTOM DATABASE SECURITY FIX
-- ============================================================================
-- Generated based on actual schema inspection
-- Date: 2026-06-12
-- Safe to run multiple times (uses IF EXISTS and DROP POLICY IF EXISTS)
-- ============================================================================

-- ============================================================================
-- 1. FINANCIAL TABLES WITH vendor_id - CRITICAL
-- ============================================================================

-- Stripe Accounts (Has vendor_id, RLS OFF)
ALTER TABLE stripe_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors view own Stripe account" ON stripe_accounts;
CREATE POLICY "Vendors view own Stripe account"
  ON stripe_accounts FOR SELECT
  USING (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Vendors update own Stripe account" ON stripe_accounts;
CREATE POLICY "Vendors update own Stripe account"
  ON stripe_accounts FOR UPDATE
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Vendors insert own Stripe account" ON stripe_accounts;
CREATE POLICY "Vendors insert own Stripe account"
  ON stripe_accounts FOR INSERT
  WITH CHECK (vendor_id = auth.uid());

-- Payout Records (Has vendor_id, RLS OFF)
ALTER TABLE payout_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors view own payouts" ON payout_records;
CREATE POLICY "Vendors view own payouts"
  ON payout_records FOR SELECT
  USING (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Vendors insert own payouts" ON payout_records;
CREATE POLICY "Vendors insert own payouts"
  ON payout_records FOR INSERT
  WITH CHECK (vendor_id = auth.uid());

-- Vendor Subscriptions (Has vendor_id, RLS OFF)
ALTER TABLE vendor_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors view own subscription" ON vendor_subscriptions;
CREATE POLICY "Vendors view own subscription"
  ON vendor_subscriptions FOR SELECT
  USING (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Vendors update own subscription" ON vendor_subscriptions;
CREATE POLICY "Vendors update own subscription"
  ON vendor_subscriptions FOR UPDATE
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

DROP POLICY IF EXISTS "Vendors insert own subscription" ON vendor_subscriptions;
CREATE POLICY "Vendors insert own subscription"
  ON vendor_subscriptions FOR INSERT
  WITH CHECK (vendor_id = auth.uid());

-- ============================================================================
-- 2. EVENT-RELATED TABLES (No vendor_id - use event_id JOIN)
-- ============================================================================

-- Event Team Members (No vendor_id, RLS OFF)
-- Must join through events table to check ownership
ALTER TABLE event_team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Event creators manage team" ON event_team_members;
CREATE POLICY "Event creators manage team"
  ON event_team_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_team_members.event_id::text
      AND events.vendor_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_team_members.event_id::text
      AND events.vendor_id = auth.uid()
    )
  );

-- Ticket Types (No vendor_id, RLS already ON but may need policies)
-- Must join through events table to check ownership
DROP POLICY IF EXISTS "Event creators manage ticket types" ON ticket_types;
CREATE POLICY "Event creators manage ticket types"
  ON ticket_types FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = ticket_types.event_id::text
      AND events.vendor_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = ticket_types.event_id::text
      AND events.vendor_id = auth.uid()
    )
  );

-- ============================================================================
-- 3. ONBOARDING TABLES (Check if they exist, add policies if needed)
-- ============================================================================

-- Staff Profiles (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'staff_profiles') THEN
    ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Staff manage own profile" ON staff_profiles;
    EXECUTE 'CREATE POLICY "Staff manage own profile" ON staff_profiles FOR ALL USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid())';
  END IF;
END $$;

-- Promoter Profiles (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'promoter_profiles') THEN
    ALTER TABLE promoter_profiles ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Promoters manage own profile" ON promoter_profiles;
    EXECUTE 'CREATE POLICY "Promoters manage own profile" ON promoter_profiles FOR ALL USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid())';
  END IF;
END $$;

-- Organizer Profiles (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'organizer_profiles') THEN
    ALTER TABLE organizer_profiles ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Organizers manage own profile" ON organizer_profiles;
    EXECUTE 'CREATE POLICY "Organizers manage own profile" ON organizer_profiles FOR ALL USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid())';
  END IF;
END $$;

-- Venue Details (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'venue_details') THEN
    ALTER TABLE venue_details ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Venue owners manage details" ON venue_details;
    EXECUTE 'CREATE POLICY "Venue owners manage details" ON venue_details FOR ALL USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid())';
  END IF;
END $$;

-- Venue Gallery (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'venue_gallery') THEN
    ALTER TABLE venue_gallery ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Venue owners manage gallery" ON venue_gallery;
    EXECUTE 'CREATE POLICY "Venue owners manage gallery" ON venue_gallery FOR ALL USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid())';
  END IF;
END $$;

-- Venue Documents (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'venue_documents') THEN
    ALTER TABLE venue_documents ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Venue owners manage documents" ON venue_documents;
    EXECUTE 'CREATE POLICY "Venue owners manage documents" ON venue_documents FOR ALL USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid())';
  END IF;
END $$;

-- Venue Zones (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'venue_zones') THEN
    ALTER TABLE venue_zones ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Venue owners manage zones" ON venue_zones;
    EXECUTE 'CREATE POLICY "Venue owners manage zones" ON venue_zones FOR ALL USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid())';
  END IF;
END $$;

-- Venue Bottle Menu (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'venue_bottle_menu') THEN
    ALTER TABLE venue_bottle_menu ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Venue owners manage bottle menu" ON venue_bottle_menu;
    EXECUTE 'CREATE POLICY "Venue owners manage bottle menu" ON venue_bottle_menu FOR ALL USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid())';
  END IF;
END $$;

-- Subscription Plans (if exists - make read-only for authenticated users)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'subscription_plans') THEN
    ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Anyone can view active subscription plans" ON subscription_plans;
    EXECUTE 'CREATE POLICY "Anyone can view active subscription plans" ON subscription_plans FOR SELECT TO authenticated USING (is_active = true)';
  END IF;
END $$;

-- Promoter Event Assignments (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'promoter_event_assignments') THEN
    ALTER TABLE promoter_event_assignments ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Promoters view own assignments" ON promoter_event_assignments;
    EXECUTE 'CREATE POLICY "Promoters view own assignments" ON promoter_event_assignments FOR SELECT USING (EXISTS (SELECT 1 FROM promoter_profiles WHERE promoter_profiles.id = promoter_event_assignments.promoter_id AND promoter_profiles.vendor_id = auth.uid()))';

    DROP POLICY IF EXISTS "Organizers manage assignments" ON promoter_event_assignments;
    EXECUTE 'CREATE POLICY "Organizers manage assignments" ON promoter_event_assignments FOR ALL USING (organizer_id = auth.uid()) WITH CHECK (organizer_id = auth.uid())';
  END IF;
END $$;

-- Staff Shifts (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'staff_shifts') THEN
    ALTER TABLE staff_shifts ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Staff view own shifts" ON staff_shifts;
    EXECUTE 'CREATE POLICY "Staff view own shifts" ON staff_shifts FOR SELECT USING (EXISTS (SELECT 1 FROM staff_profiles WHERE staff_profiles.id = staff_shifts.staff_id AND staff_profiles.vendor_id = auth.uid()))';

    DROP POLICY IF EXISTS "Venue owners manage shifts" ON staff_shifts;
    EXECUTE 'CREATE POLICY "Venue owners manage shifts" ON staff_shifts FOR ALL USING (EXISTS (SELECT 1 FROM venue_details WHERE venue_details.id = staff_shifts.venue_id AND venue_details.vendor_id = auth.uid())) WITH CHECK (EXISTS (SELECT 1 FROM venue_details WHERE venue_details.id = staff_shifts.venue_id AND venue_details.vendor_id = auth.uid()))';
  END IF;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT '✅ RLS POLICIES APPLIED SUCCESSFULLY!' as status;

-- Show updated RLS status
SELECT
  tablename,
  CASE WHEN rowsecurity THEN '✅ RLS ENABLED' ELSE '❌ RLS DISABLED' END as rls_status
FROM pg_tables
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
ORDER BY tablename;

-- ============================================================================
-- EXPECTED RESULT
-- ============================================================================
-- All tables should now show "✅ RLS ENABLED"
--
-- CRITICAL TABLES FIXED:
-- - stripe_accounts: RLS enabled with vendor-scoped policies
-- - payout_records: RLS enabled with vendor-scoped policies
-- - vendor_subscriptions: RLS enabled with vendor-scoped policies
-- - event_team_members: RLS enabled with event ownership check
-- - ticket_types: Policies added (RLS was already on)
--
-- Additional tables secured if they exist in your database.
-- ============================================================================
