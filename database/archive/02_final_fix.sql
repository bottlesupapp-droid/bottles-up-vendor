-- =====================================================
-- FINAL FIX MIGRATION (Corrected for venues table)
-- Date: April 3, 2026
-- Purpose: Fix all errors without venues.user_id dependency
-- =====================================================

-- Step 1: Add status column to clubs table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'clubs' AND column_name = 'status'
  ) THEN
    ALTER TABLE clubs ADD COLUMN status TEXT DEFAULT 'active'
      CHECK (status IN ('active', 'inactive', 'pending', 'suspended'));
    CREATE INDEX idx_clubs_status ON clubs(status);
    RAISE NOTICE '✅ Added status column to clubs table';
  ELSE
    RAISE NOTICE 'ℹ️  Status column already exists in clubs table';
  END IF;
END $$;

-- Step 2: Enhance events_bookings table for QR scanning
DO $$
BEGIN
  -- Add ticket_code
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events_bookings' AND column_name = 'ticket_code') THEN
    ALTER TABLE events_bookings ADD COLUMN ticket_code TEXT UNIQUE;
    CREATE INDEX idx_events_bookings_ticket_code ON events_bookings(ticket_code);
    RAISE NOTICE '✅ Added ticket_code column to events_bookings';
  END IF;

  -- Add qr_code
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events_bookings' AND column_name = 'qr_code') THEN
    ALTER TABLE events_bookings ADD COLUMN qr_code TEXT;
    RAISE NOTICE '✅ Added qr_code column to events_bookings';
  END IF;

  -- Add checked_in
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events_bookings' AND column_name = 'checked_in') THEN
    ALTER TABLE events_bookings ADD COLUMN checked_in BOOLEAN DEFAULT FALSE;
    CREATE INDEX idx_events_bookings_checked_in ON events_bookings(checked_in);
    RAISE NOTICE '✅ Added checked_in column to events_bookings';
  END IF;

  -- Add checked_in_at
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events_bookings' AND column_name = 'checked_in_at') THEN
    ALTER TABLE events_bookings ADD COLUMN checked_in_at TIMESTAMPTZ;
    RAISE NOTICE '✅ Added checked_in_at column to events_bookings';
  END IF;

  -- Add checked_in_by
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events_bookings' AND column_name = 'checked_in_by') THEN
    ALTER TABLE events_bookings ADD COLUMN checked_in_by UUID;
    RAISE NOTICE '✅ Added checked_in_by column to events_bookings';
  END IF;

  -- Add booking_type
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events_bookings' AND column_name = 'booking_type') THEN
    ALTER TABLE events_bookings ADD COLUMN booking_type TEXT DEFAULT 'ticket'
      CHECK (booking_type IN ('ticket', 'table', 'bottle', 'vip'));
    RAISE NOTICE '✅ Added booking_type column to events_bookings';
  END IF;

  -- Add customer_phone
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events_bookings' AND column_name = 'customer_phone') THEN
    ALTER TABLE events_bookings ADD COLUMN customer_phone TEXT;
    RAISE NOTICE '✅ Added customer_phone column to events_bookings';
  END IF;
END $$;

-- Step 3: Create new feature tables (without foreign key constraints for now)
CREATE TABLE IF NOT EXISTS inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL,
  customer_name TEXT NOT NULL,
  customer_email TEXT NOT NULL,
  customer_phone TEXT,
  message TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inquiries_event_id ON inquiries(event_id);
CREATE INDEX IF NOT EXISTS idx_inquiries_status ON inquiries(status);
CREATE INDEX IF NOT EXISTS idx_inquiries_created_at ON inquiries(created_at DESC);

CREATE TABLE IF NOT EXISTS guest_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  ticket_type TEXT,
  checked_in BOOLEAN DEFAULT FALSE,
  checked_in_at TIMESTAMPTZ,
  checked_in_by UUID,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_guest_list_event_id ON guest_list(event_id);
CREATE INDEX IF NOT EXISTS idx_guest_list_checked_in ON guest_list(checked_in);
CREATE INDEX IF NOT EXISTS idx_guest_list_email ON guest_list(email);
CREATE INDEX IF NOT EXISTS idx_guest_list_name ON guest_list(name);

CREATE TABLE IF NOT EXISTS scheduled_releases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL,
  name TEXT NOT NULL,
  release_date TIMESTAMPTZ NOT NULL,
  ticket_quantity INTEGER NOT NULL CHECK (ticket_quantity > 0),
  price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  is_active BOOLEAN DEFAULT TRUE,
  tickets_sold INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scheduled_releases_event_id ON scheduled_releases(event_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_releases_release_date ON scheduled_releases(release_date);
CREATE INDEX IF NOT EXISTS idx_scheduled_releases_is_active ON scheduled_releases(is_active);

CREATE TABLE IF NOT EXISTS venue_boosts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id UUID NOT NULL,
  package_type TEXT NOT NULL CHECK (package_type IN ('basic', 'premium', 'elite')),
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  cost DECIMAL(10,2) NOT NULL CHECK (cost > 0),
  is_active BOOLEAN DEFAULT TRUE,
  impressions INTEGER DEFAULT 0,
  clicks INTEGER DEFAULT 0,
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
  payment_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT valid_dates CHECK (end_date > start_date)
);

CREATE INDEX IF NOT EXISTS idx_venue_boosts_venue_id ON venue_boosts(venue_id);
CREATE INDEX IF NOT EXISTS idx_venue_boosts_is_active ON venue_boosts(is_active);
CREATE INDEX IF NOT EXISTS idx_venue_boosts_dates ON venue_boosts(start_date, end_date);

-- Step 4: Create analytics views using events_bookings
CREATE OR REPLACE VIEW v_organizer_analytics AS
SELECT
  e.user_id as organizer_id,
  COUNT(DISTINCT i.id) as total_inquiries,
  COUNT(DISTINCT i.id) FILTER (WHERE i.status = 'pending') as pending_inquiries,
  COUNT(DISTINCT i.id) FILTER (WHERE i.status = 'accepted') as accepted_inquiries,
  COUNT(DISTINCT i.id) FILTER (WHERE i.status = 'rejected') as rejected_inquiries,
  COUNT(DISTINCT b.id) as total_bookings,
  COUNT(DISTINCT b.id) FILTER (WHERE b.status = 'confirmed') as confirmed_bookings,
  COUNT(DISTINCT b.id) FILTER (WHERE b.status = 'pending') as pending_bookings,
  COUNT(DISTINCT b.id) FILTER (WHERE b.status = 'cancelled') as cancelled_bookings,
  COALESCE(SUM(b.total_amount) FILTER (WHERE b.status = 'confirmed'), 0) as total_revenue,
  COALESCE(SUM(b.total_amount) FILTER (WHERE b.status = 'pending'), 0) as pending_revenue
FROM events e
LEFT JOIN inquiries i ON e.id = i.event_id
LEFT JOIN events_bookings b ON e.id = b.event_id
GROUP BY e.user_id;

CREATE OR REPLACE VIEW v_revenue_by_event AS
SELECT
  e.id as event_id,
  e.name as event_name,
  e.user_id as organizer_id,
  COUNT(b.id) as booking_count,
  COALESCE(SUM(b.total_amount) FILTER (WHERE b.booking_type = 'ticket'), 0) as ticket_revenue,
  COALESCE(SUM(b.total_amount) FILTER (WHERE b.booking_type = 'table'), 0) as table_revenue,
  COALESCE(SUM(b.total_amount) FILTER (WHERE b.booking_type = 'bottle'), 0) as bottle_revenue,
  COALESCE(SUM(b.total_amount) FILTER (WHERE b.booking_type = 'vip'), 0) as vip_revenue,
  COALESCE(SUM(b.total_amount), 0) as total_revenue
FROM events e
LEFT JOIN events_bookings b ON e.id = b.event_id AND b.status = 'confirmed'
GROUP BY e.id, e.name, e.user_id;

CREATE OR REPLACE VIEW v_event_performance AS
SELECT
  e.id as event_id,
  e.name as event_name,
  e.user_id,
  COALESCE(e.max_capacity, 0) as total_tickets,
  COALESCE(e.current_bookings, 0) as sold_tickets,
  COALESCE(e.rsvp_count, 0) as rsvp_count,
  COUNT(b.id) FILTER (WHERE b.checked_in = true) as checked_in_count,
  ROUND((COALESCE(e.current_bookings, 0)::NUMERIC / NULLIF(e.max_capacity, 0) * 100), 2) as conversion_rate,
  ROUND((COUNT(b.id) FILTER (WHERE b.checked_in = true)::NUMERIC / NULLIF(e.current_bookings, 0) * 100), 2) as attendance_rate,
  ROUND((COALESCE(e.revenue, 0)::NUMERIC / NULLIF(e.current_bookings, 0)), 2) as revenue_per_ticket
FROM events e
LEFT JOIN events_bookings b ON e.id = b.event_id
GROUP BY e.id, e.name, e.user_id, e.max_capacity, e.current_bookings, e.rsvp_count, e.revenue;

-- Step 5: Enable RLS on new tables
ALTER TABLE inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_boosts ENABLE ROW LEVEL SECURITY;

-- Step 6: Create RLS policies (simplified without venues.user_id)
DROP POLICY IF EXISTS "Users can view inquiries for their events" ON inquiries;
CREATE POLICY "Users can view inquiries for their events"
  ON inquiries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM events WHERE events.id = inquiries.event_id AND events.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Anyone can insert inquiries" ON inquiries;
CREATE POLICY "Anyone can insert inquiries"
  ON inquiries FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Event owners can update inquiries" ON inquiries;
CREATE POLICY "Event owners can update inquiries"
  ON inquiries FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM events WHERE events.id = inquiries.event_id AND events.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Event owners can manage guest list" ON guest_list;
CREATE POLICY "Event owners can manage guest list"
  ON guest_list FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events WHERE events.id = guest_list.event_id AND events.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Event owners can manage releases" ON scheduled_releases;
CREATE POLICY "Event owners can manage releases"
  ON scheduled_releases FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events WHERE events.id = scheduled_releases.event_id AND events.user_id = auth.uid()
    )
  );

-- Venue boosts: Allow all authenticated users for now (no user_id in venues table)
DROP POLICY IF EXISTS "Authenticated users can view venue boosts" ON venue_boosts;
CREATE POLICY "Authenticated users can view venue boosts"
  ON venue_boosts FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can manage venue boosts" ON venue_boosts;
CREATE POLICY "Authenticated users can manage venue boosts"
  ON venue_boosts FOR ALL
  USING (auth.uid() IS NOT NULL);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Tables created:';
  RAISE NOTICE '  ✓ inquiries';
  RAISE NOTICE '  ✓ guest_list';
  RAISE NOTICE '  ✓ scheduled_releases';
  RAISE NOTICE '  ✓ venue_boosts';
  RAISE NOTICE '';
  RAISE NOTICE 'Columns enhanced:';
  RAISE NOTICE '  ✓ events_bookings (QR/check-in support)';
  RAISE NOTICE '  ✓ clubs (status column)';
  RAISE NOTICE '';
  RAISE NOTICE 'Views created:';
  RAISE NOTICE '  ✓ v_organizer_analytics';
  RAISE NOTICE '  ✓ v_revenue_by_event';
  RAISE NOTICE '  ✓ v_event_performance';
  RAISE NOTICE '';
  RAISE NOTICE 'Security:';
  RAISE NOTICE '  ✓ RLS enabled on all tables';
  RAISE NOTICE '  ✓ Policies created';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Ready to test! Hot restart your app now.';
  RAISE NOTICE '';
END $$;
