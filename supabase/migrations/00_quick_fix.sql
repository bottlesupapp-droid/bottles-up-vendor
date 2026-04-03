-- =====================================================
-- QUICK FIX MIGRATION
-- Date: April 3, 2026
-- Purpose: Fix immediate errors in Analytics and Venues
-- =====================================================

-- Step 1: Add missing 'status' column to clubs table
-- Fixes: "column clubs.status does not exist"
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'clubs') THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'clubs' AND column_name = 'status'
    ) THEN
      ALTER TABLE clubs ADD COLUMN status TEXT DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'pending', 'suspended'));
      CREATE INDEX idx_clubs_status ON clubs(status);
      RAISE NOTICE 'Added status column to clubs table';
    ELSE
      RAISE NOTICE 'Status column already exists in clubs table';
    END IF;
  ELSE
    RAISE NOTICE 'Clubs table does not exist - skipping';
  END IF;
END $$;

-- Step 2: Enhance bookings table for QR scanning
-- Adds columns needed for check-in functionality
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bookings') THEN

    -- Add ticket_code
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bookings' AND column_name = 'ticket_code') THEN
      ALTER TABLE bookings ADD COLUMN ticket_code TEXT UNIQUE;
      CREATE INDEX idx_bookings_ticket_code ON bookings(ticket_code);
      RAISE NOTICE 'Added ticket_code column';
    END IF;

    -- Add qr_code
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bookings' AND column_name = 'qr_code') THEN
      ALTER TABLE bookings ADD COLUMN qr_code TEXT;
      RAISE NOTICE 'Added qr_code column';
    END IF;

    -- Add checked_in
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bookings' AND column_name = 'checked_in') THEN
      ALTER TABLE bookings ADD COLUMN checked_in BOOLEAN DEFAULT FALSE;
      CREATE INDEX idx_bookings_checked_in ON bookings(checked_in);
      RAISE NOTICE 'Added checked_in column';
    END IF;

    -- Add checked_in_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bookings' AND column_name = 'checked_in_at') THEN
      ALTER TABLE bookings ADD COLUMN checked_in_at TIMESTAMPTZ;
      RAISE NOTICE 'Added checked_in_at column';
    END IF;

    -- Add checked_in_by
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bookings' AND column_name = 'checked_in_by') THEN
      ALTER TABLE bookings ADD COLUMN checked_in_by UUID;
      RAISE NOTICE 'Added checked_in_by column';
    END IF;

    -- Add booking_type
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bookings' AND column_name = 'booking_type') THEN
      ALTER TABLE bookings ADD COLUMN booking_type TEXT DEFAULT 'ticket'
        CHECK (booking_type IN ('ticket', 'table', 'bottle', 'vip'));
      RAISE NOTICE 'Added booking_type column';
    END IF;

    -- Add customer_phone
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bookings' AND column_name = 'customer_phone') THEN
      ALTER TABLE bookings ADD COLUMN customer_phone TEXT;
      RAISE NOTICE 'Added customer_phone column';
    END IF;

  ELSE
    RAISE WARNING 'Bookings table does not exist - cannot enhance it';
  END IF;
END $$;

-- Step 3: Create new feature tables
-- INQUIRIES TABLE
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

-- GUEST LIST TABLE
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

-- SCHEDULED RELEASES TABLE
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

-- VENUE BOOSTS TABLE
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

-- Step 4: Create analytics views (only if events and bookings exist)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'events')
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bookings') THEN

    -- View 1: Organizer Analytics
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
    LEFT JOIN bookings b ON e.id = b.event_id
    GROUP BY e.user_id;

    -- View 2: Revenue by Event
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
    LEFT JOIN bookings b ON e.id = b.event_id AND b.status = 'confirmed'
    GROUP BY e.id, e.name, e.user_id;

    -- View 3: Event Performance (with user_id)
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
    LEFT JOIN bookings b ON e.id = b.event_id
    GROUP BY e.id, e.name, e.user_id, e.max_capacity, e.current_bookings, e.rsvp_count, e.revenue;

    RAISE NOTICE 'Analytics views created successfully';
  ELSE
    RAISE WARNING 'Events or Bookings table does not exist - skipping view creation';
  END IF;
END $$;

-- Step 5: Enable RLS on new tables
ALTER TABLE inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_boosts ENABLE ROW LEVEL SECURITY;

-- Step 6: Create basic RLS policies
-- Inquiries policies
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

-- Guest list policies
DROP POLICY IF EXISTS "Event owners can manage guest list" ON guest_list;
CREATE POLICY "Event owners can manage guest list"
  ON guest_list FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events WHERE events.id = guest_list.event_id AND events.user_id = auth.uid()
    )
  );

-- Scheduled releases policies
DROP POLICY IF EXISTS "Event owners can manage releases" ON scheduled_releases;
CREATE POLICY "Event owners can manage releases"
  ON scheduled_releases FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM events WHERE events.id = scheduled_releases.event_id AND events.user_id = auth.uid()
    )
  );

-- Venue boosts policies (if clubs table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'clubs') THEN
    DROP POLICY IF EXISTS "Venue owners can view their boosts" ON venue_boosts;
    CREATE POLICY "Venue owners can view their boosts"
      ON venue_boosts FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM clubs WHERE clubs.id = venue_boosts.venue_id AND clubs.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Quick fix migration completed successfully!';
  RAISE NOTICE 'Tables created: inquiries, guest_list, scheduled_releases, venue_boosts';
  RAISE NOTICE 'Columns enhanced: bookings (QR/check-in support), clubs (status)';
  RAISE NOTICE 'Views created: v_organizer_analytics, v_revenue_by_event, v_event_performance';
END $$;
