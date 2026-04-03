# Database Setup Guide - Step by Step

**Date:** April 3, 2026
**Purpose:** Proper database setup for Bottles Up Vendor App

---

## CRITICAL: Database Issues Found

### Current Errors:
1. ❌ **Analytics Error**: `relation "public.v_organizer_analytics" does not exist`
2. ❌ **Venues Error**: `column clubs.status does not exist`
3. ❌ **Migration Error**: `relation "bookings" does not exist`

### Root Cause:
The existing schema (`supabase_schema.sql`) assumes tables like `events`, `bookings`, and `venues/clubs` already exist, but they don't.

---

## Step 1: Check What Tables Actually Exist

Run this in **Supabase SQL Editor**:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
```

**Expected tables** (from your existing app):
- `clubs` (or `venues`)
- `events`
- `bookings`
- `users` or `vendors`

---

## Step 2: Fix Missing Columns in Existing Tables

### A. Add `status` column to `clubs` table

```sql
-- Add status column to clubs table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'clubs' AND column_name = 'status'
  ) THEN
    ALTER TABLE clubs ADD COLUMN status TEXT DEFAULT 'active'
      CHECK (status IN ('active', 'inactive', 'pending'));
    CREATE INDEX IF NOT EXISTS idx_clubs_status ON clubs(status);
  END IF;
END $$;
```

### B. Enhance `bookings` table for QR scanning

```sql
-- Add QR/check-in columns to bookings table
DO $$
BEGIN
  -- Add ticket_code column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bookings' AND column_name = 'ticket_code'
  ) THEN
    ALTER TABLE bookings ADD COLUMN ticket_code TEXT UNIQUE;
    CREATE INDEX IF NOT EXISTS idx_bookings_ticket_code ON bookings(ticket_code);
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
    CREATE INDEX IF NOT EXISTS idx_bookings_checked_in ON bookings(checked_in);
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
    ALTER TABLE bookings ADD COLUMN checked_in_by UUID;
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
```

---

## Step 3: Create New Feature Tables

Run the complete schema from `supabase_schema.sql` for these tables:

### Quick Version (Copy this to SQL Editor):

```sql
-- 1. INQUIRIES TABLE
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

-- 2. GUEST LIST TABLE
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

-- 3. SCHEDULED RELEASES TABLE
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

-- 4. VENUE BOOSTS TABLE
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
  payment_status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_venue_boosts_venue_id ON venue_boosts(venue_id);
```

---

## Step 4: Create Analytics Views

**IMPORTANT:** Replace `TABLE_NAME` and `COLUMN_NAME` with your actual table/column names.

### Check your actual column names first:

```sql
-- Check events table columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'events'
ORDER BY ordinal_position;

-- Check bookings table columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'bookings'
ORDER BY ordinal_position;
```

### Create views (adjust column names as needed):

```sql
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

-- View 3: Event Performance (FIXED with user_id)
CREATE OR REPLACE VIEW v_event_performance AS
SELECT
  e.id as event_id,
  e.name as event_name,
  e.user_id,
  e.max_capacity as total_tickets,
  e.current_bookings as sold_tickets,
  COALESCE(e.rsvp_count, 0) as rsvp_count,
  COUNT(b.id) FILTER (WHERE b.checked_in = true) as checked_in_count,
  ROUND((COALESCE(e.current_bookings, 0)::NUMERIC / NULLIF(e.max_capacity, 0) * 100), 2) as conversion_rate,
  ROUND((COUNT(b.id) FILTER (WHERE b.checked_in = true)::NUMERIC / NULLIF(e.current_bookings, 0) * 100), 2) as attendance_rate,
  ROUND((COALESCE(e.revenue, 0)::NUMERIC / NULLIF(e.current_bookings, 0)), 2) as revenue_per_ticket
FROM events e
LEFT JOIN bookings b ON e.id = b.event_id
GROUP BY e.id, e.name, e.user_id, e.max_capacity, e.current_bookings, e.rsvp_count, e.revenue;
```

---

## Step 5: Enable Row Level Security (RLS)

```sql
-- Enable RLS on new tables
ALTER TABLE inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_boosts ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (adjust based on your auth setup)
-- For inquiries
CREATE POLICY "Users can view inquiries for their events"
  ON inquiries FOR SELECT
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Anyone can insert inquiries"
  ON inquiries FOR INSERT
  WITH CHECK (true);

-- For guest_list
CREATE POLICY "Event owners can manage guest list"
  ON guest_list FOR ALL
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

-- For scheduled_releases
CREATE POLICY "Event owners can manage releases"
  ON scheduled_releases FOR ALL
  USING (
    event_id IN (
      SELECT id FROM events WHERE user_id = auth.uid()
    )
  );

-- For venue_boosts
CREATE POLICY "Venue owners can view their boosts"
  ON venue_boosts FOR SELECT
  USING (
    venue_id IN (
      SELECT id FROM clubs WHERE user_id = auth.uid()
    )
  );
```

---

## Step 6: Verify Setup

Run this verification query:

```sql
-- Check all tables exist
SELECT table_name,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name IN ('clubs', 'events', 'bookings', 'inquiries', 'guest_list', 'scheduled_releases', 'venue_boosts')
ORDER BY table_name;

-- Check all views exist
SELECT table_name as view_name
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name LIKE 'v_%'
ORDER BY table_name;

-- Check clubs has status column
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'clubs' AND column_name = 'status';
```

---

## Common Issues & Fixes

### Issue: "relation 'events' does not exist"
**Solution:** You need to create the events table first. Check your existing schema or Firebase data.

### Issue: "column 'user_id' does not exist"
**Solution:** Your events table might use a different column name (like `organizer_id` or `vendor_id`). Update the views accordingly.

### Issue: "column 'total_amount' does not exist in bookings"
**Solution:** Your bookings table might use different column names. Check with:
```sql
SELECT column_name FROM information_schema.columns WHERE table_name = 'bookings';
```
Then update the view definitions to use the correct column names.

### Issue: "permission denied for table"
**Solution:** Make sure you're logged in with the correct credentials and have proper permissions.

---

## After Setup: Test in App

1. **Hot restart** your app
2. Navigate to **Analytics** tab
3. Navigate to **Venues** tab
4. Both should now load without errors

---

## Need Help?

If you encounter errors, share:
1. The exact error message
2. Output from the verification query (Step 6)
3. Your table structure:
   ```sql
   SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
   ```
