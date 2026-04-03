-- =====================================================
-- SUPABASE DATABASE SCHEMA FOR NEW FEATURES
-- Bottles Up Vendor App
-- =====================================================
-- Created: March 21, 2026
-- Purpose: Support Analytics, QR Scanner, Guest List, Scheduled Releases, Venue Boost
-- =====================================================

-- =====================================================
-- 1. INQUIRIES TABLE
-- Purpose: Store customer inquiries for events
-- =====================================================
CREATE TABLE IF NOT EXISTS inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  customer_name TEXT NOT NULL,
  customer_email TEXT NOT NULL,
  customer_phone TEXT,
  message TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for inquiries
CREATE INDEX IF NOT EXISTS idx_inquiries_event_id ON inquiries(event_id);
CREATE INDEX IF NOT EXISTS idx_inquiries_status ON inquiries(status);
CREATE INDEX IF NOT EXISTS idx_inquiries_created_at ON inquiries(created_at DESC);

-- RLS Policies for inquiries
ALTER TABLE inquiries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their event inquiries"
  ON inquiries FOR SELECT
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert inquiries"
  ON inquiries FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Event owners can update inquiries"
  ON inquiries FOR UPDATE
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

-- =====================================================
-- 2. GUEST LIST TABLE
-- Purpose: Manage event guest lists with check-in tracking
-- =====================================================
CREATE TABLE IF NOT EXISTS guest_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  ticket_type TEXT,
  checked_in BOOLEAN DEFAULT FALSE,
  checked_in_at TIMESTAMPTZ,
  checked_in_by UUID REFERENCES auth.users(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for guest_list
CREATE INDEX IF NOT EXISTS idx_guest_list_event_id ON guest_list(event_id);
CREATE INDEX IF NOT EXISTS idx_guest_list_checked_in ON guest_list(checked_in);
CREATE INDEX IF NOT EXISTS idx_guest_list_email ON guest_list(email);
CREATE INDEX IF NOT EXISTS idx_guest_list_name ON guest_list(name);

-- RLS Policies for guest_list
ALTER TABLE guest_list ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Event owners can view guest list"
  ON guest_list FOR SELECT
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Event owners can insert guests"
  ON guest_list FOR INSERT
  WITH CHECK (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Event owners can update guests"
  ON guest_list FOR UPDATE
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Event owners can delete guests"
  ON guest_list FOR DELETE
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

-- =====================================================
-- 3. SCHEDULED TICKET RELEASES TABLE
-- Purpose: Manage timed ticket release schedules
-- =====================================================
CREATE TABLE IF NOT EXISTS scheduled_releases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  release_date TIMESTAMPTZ NOT NULL,
  ticket_quantity INTEGER NOT NULL CHECK (ticket_quantity > 0),
  price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  is_active BOOLEAN DEFAULT TRUE,
  tickets_sold INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for scheduled_releases
CREATE INDEX IF NOT EXISTS idx_scheduled_releases_event_id ON scheduled_releases(event_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_releases_release_date ON scheduled_releases(release_date);
CREATE INDEX IF NOT EXISTS idx_scheduled_releases_is_active ON scheduled_releases(is_active);

-- RLS Policies for scheduled_releases
ALTER TABLE scheduled_releases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Event owners can view releases"
  ON scheduled_releases FOR SELECT
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Event owners can insert releases"
  ON scheduled_releases FOR INSERT
  WITH CHECK (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Event owners can update releases"
  ON scheduled_releases FOR UPDATE
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Event owners can delete releases"
  ON scheduled_releases FOR DELETE
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

-- =====================================================
-- 4. VENUE BOOSTS TABLE
-- Purpose: Track venue visibility boost packages
-- =====================================================
CREATE TABLE IF NOT EXISTS venue_boosts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
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

-- Indexes for venue_boosts
CREATE INDEX IF NOT EXISTS idx_venue_boosts_venue_id ON venue_boosts(venue_id);
CREATE INDEX IF NOT EXISTS idx_venue_boosts_is_active ON venue_boosts(is_active);
CREATE INDEX IF NOT EXISTS idx_venue_boosts_dates ON venue_boosts(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_venue_boosts_payment_status ON venue_boosts(payment_status);

-- RLS Policies for venue_boosts
ALTER TABLE venue_boosts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Venue owners can view their boosts"
  ON venue_boosts FOR SELECT
  USING (
    venue_id IN (
      SELECT id FROM venues WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Venue owners can insert boosts"
  ON venue_boosts FOR INSERT
  WITH CHECK (
    venue_id IN (
      SELECT id FROM venues WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Venue owners can update boosts"
  ON venue_boosts FOR UPDATE
  USING (
    venue_id IN (
      SELECT id FROM venues WHERE user_id = auth.uid()
    )
  );

-- =====================================================
-- 5. BOOKINGS TABLE (Enhanced for QR Scanning)
-- Purpose: Manage ticket bookings with QR code support
-- Note: May already exist, this adds missing columns
-- =====================================================

-- Add columns to existing bookings table if they don't exist
DO $$
BEGIN
  -- Add ticket_code column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bookings' AND column_name = 'ticket_code'
  ) THEN
    ALTER TABLE bookings ADD COLUMN ticket_code TEXT UNIQUE;
    CREATE INDEX idx_bookings_ticket_code ON bookings(ticket_code);
  END IF;

  -- Add qr_code column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bookings' AND column_name = 'qr_code'
  ) THEN
    ALTER TABLE bookings ADD COLUMN qr_code TEXT;
  END IF;

  -- Add checked_in column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bookings' AND column_name = 'checked_in'
  ) THEN
    ALTER TABLE bookings ADD COLUMN checked_in BOOLEAN DEFAULT FALSE;
    CREATE INDEX idx_bookings_checked_in ON bookings(checked_in);
  END IF;

  -- Add checked_in_at column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bookings' AND column_name = 'checked_in_at'
  ) THEN
    ALTER TABLE bookings ADD COLUMN checked_in_at TIMESTAMPTZ;
  END IF;

  -- Add checked_in_by column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bookings' AND column_name = 'checked_in_by'
  ) THEN
    ALTER TABLE bookings ADD COLUMN checked_in_by UUID REFERENCES auth.users(id);
  END IF;

  -- Add booking_type column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bookings' AND column_name = 'booking_type'
  ) THEN
    ALTER TABLE bookings ADD COLUMN booking_type TEXT DEFAULT 'ticket'
      CHECK (booking_type IN ('ticket', 'table', 'bottle', 'vip'));
  END IF;

  -- Add customer_phone column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bookings' AND column_name = 'customer_phone'
  ) THEN
    ALTER TABLE bookings ADD COLUMN customer_phone TEXT;
  END IF;
END $$;

-- =====================================================
-- 6. HELPER FUNCTIONS
-- =====================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all tables
DROP TRIGGER IF EXISTS update_inquiries_updated_at ON inquiries;
CREATE TRIGGER update_inquiries_updated_at
  BEFORE UPDATE ON inquiries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_guest_list_updated_at ON guest_list;
CREATE TRIGGER update_guest_list_updated_at
  BEFORE UPDATE ON guest_list
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_scheduled_releases_updated_at ON scheduled_releases;
CREATE TRIGGER update_scheduled_releases_updated_at
  BEFORE UPDATE ON scheduled_releases
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_venue_boosts_updated_at ON venue_boosts;
CREATE TRIGGER update_venue_boosts_updated_at
  BEFORE UPDATE ON venue_boosts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to generate unique ticket codes
CREATE OR REPLACE FUNCTION generate_ticket_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := 'TKT-';
  i INTEGER;
BEGIN
  FOR i IN 1..10 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to auto-generate ticket code on booking insert
CREATE OR REPLACE FUNCTION auto_generate_ticket_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.ticket_code IS NULL THEN
    NEW.ticket_code := generate_ticket_code();
    NEW.qr_code := NEW.ticket_code; -- QR code contains the ticket code
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_ticket_code ON bookings;
CREATE TRIGGER trigger_generate_ticket_code
  BEFORE INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_ticket_code();

-- =====================================================
-- 7. VIEWS FOR ANALYTICS
-- =====================================================

-- View for organizer analytics summary
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

-- View for revenue breakdown by event
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

-- View for event performance insights
CREATE OR REPLACE VIEW v_event_performance AS
SELECT
  e.id as event_id,
  e.name as event_name,
  e.user_id,
  e.max_capacity as total_tickets,
  e.current_bookings as sold_tickets,
  e.rsvp_count,
  COUNT(b.id) FILTER (WHERE b.checked_in = true) as checked_in_count,
  ROUND((e.current_bookings::NUMERIC / NULLIF(e.max_capacity, 0) * 100), 2) as conversion_rate,
  ROUND((COUNT(b.id) FILTER (WHERE b.checked_in = true)::NUMERIC / NULLIF(e.current_bookings, 0) * 100), 2) as attendance_rate,
  ROUND((e.revenue::NUMERIC / NULLIF(e.current_bookings, 0)), 2) as revenue_per_ticket
FROM events e
LEFT JOIN bookings b ON e.id = b.event_id
GROUP BY e.id, e.name, e.user_id, e.max_capacity, e.current_bookings, e.rsvp_count, e.revenue;

-- =====================================================
-- 8. SAMPLE DATA (Optional - for testing)
-- =====================================================

-- Uncomment to insert sample data for testing
/*
-- Sample inquiries
INSERT INTO inquiries (event_id, customer_name, customer_email, customer_phone, message, status)
SELECT
  id,
  'John Doe',
  'john@example.com',
  '+1234567890',
  'Interested in VIP table booking for 8 people',
  'pending'
FROM events LIMIT 1;

-- Sample guest list
INSERT INTO guest_list (event_id, name, email, phone, ticket_type, checked_in)
SELECT
  id,
  'Jane Smith',
  'jane@example.com',
  '+0987654321',
  'VIP',
  false
FROM events LIMIT 1;

-- Sample scheduled release
INSERT INTO scheduled_releases (event_id, name, release_date, ticket_quantity, price)
SELECT
  id,
  'Early Bird',
  NOW() + INTERVAL '7 days',
  100,
  45.00
FROM events LIMIT 1;
*/

-- =====================================================
-- SCHEMA DEPLOYMENT COMPLETE
-- =====================================================

-- Verify tables were created
SELECT
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_name IN ('inquiries', 'guest_list', 'scheduled_releases', 'venue_boosts', 'bookings')
ORDER BY table_name;

-- Show RLS status
SELECT
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('inquiries', 'guest_list', 'scheduled_releases', 'venue_boosts', 'bookings');
