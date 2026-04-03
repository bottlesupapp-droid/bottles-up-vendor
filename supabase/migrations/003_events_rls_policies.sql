-- Migration: Events Table Row Level Security (RLS) Policies
-- Date: 2025-12-19
-- Purpose: Implement role-based access control for events

-- =========================================================
-- PART 1: Enable RLS and Drop Existing Policies
-- =========================================================

-- Enable RLS on events table
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (safe to run multiple times)
DROP POLICY IF EXISTS "Venue owners can view events at their venues" ON events;
DROP POLICY IF EXISTS "Organizers can view their events" ON events;
DROP POLICY IF EXISTS "Promoters can view events they promote" ON events;
DROP POLICY IF EXISTS "Staff can view events they're assigned to" ON events;
DROP POLICY IF EXISTS "Venue owners and organizers can create events" ON events;
DROP POLICY IF EXISTS "Event creators and venue owners can update events" ON events;
DROP POLICY IF EXISTS "Event creators and venue owners can delete events" ON events;

-- =========================================================
-- PART 2: SELECT Policies (Who Can View Events)
-- =========================================================

-- Policy 1: Venue owners can view events at their venues
CREATE POLICY "Venue owners can view events at their venues"
ON events FOR SELECT
USING (
  club_id IN (
    SELECT id FROM clubs WHERE owner_id = auth.uid()
  )
);

-- Policy 2: Organizers can view events they created
CREATE POLICY "Organizers can view their events"
ON events FOR SELECT
USING (user_id = auth.uid());

-- Policy 3: Promoters can view events they have promo codes for
CREATE POLICY "Promoters can view events they promote"
ON events FOR SELECT
USING (
  id IN (
    SELECT event_id FROM promo_codes
    WHERE promoter_id = auth.uid()
    AND event_id IS NOT NULL
  )
);

-- Policy 4: Staff can view events they're assigned to via shifts
CREATE POLICY "Staff can view events they're assigned to"
ON events FOR SELECT
USING (
  id IN (
    SELECT event_id FROM shifts
    WHERE staff_id = auth.uid()
  )
);

-- =========================================================
-- PART 3: INSERT Policy (Who Can Create Events)
-- =========================================================

-- Policy 5: Only venue owners and organizers can create events
CREATE POLICY "Venue owners and organizers can create events"
ON events FOR INSERT
WITH CHECK (
  user_id = auth.uid() AND
  EXISTS (
    SELECT 1 FROM vendors
    WHERE id = auth.uid()
    AND role IN ('venue_owner', 'organizer')
  )
);

-- =========================================================
-- PART 4: UPDATE Policy (Who Can Edit Events)
-- =========================================================

-- Policy 6: Event creators OR venue owners can update events
CREATE POLICY "Event creators and venue owners can update events"
ON events FOR UPDATE
USING (
  -- Creator can update their event
  user_id = auth.uid()
  OR
  -- Venue owner can update events at their venue
  club_id IN (
    SELECT id FROM clubs WHERE owner_id = auth.uid()
  )
)
WITH CHECK (
  -- Same conditions for the updated data
  user_id = auth.uid()
  OR
  club_id IN (
    SELECT id FROM clubs WHERE owner_id = auth.uid()
  )
);

-- =========================================================
-- PART 5: DELETE Policy (Who Can Delete Events)
-- =========================================================

-- Policy 7: Event creators OR venue owners can delete events
CREATE POLICY "Event creators and venue owners can delete events"
ON events FOR DELETE
USING (
  -- Creator can delete their event
  user_id = auth.uid()
  OR
  -- Venue owner can delete events at their venue
  club_id IN (
    SELECT id FROM clubs WHERE owner_id = auth.uid()
  )
);

-- =========================================================
-- PART 6: Additional Helper Policies (Optional)
-- =========================================================

-- Create a function to check if user can manage an event
CREATE OR REPLACE FUNCTION can_manage_event(event_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM events e
    LEFT JOIN clubs c ON e.club_id = c.id
    WHERE e.id = event_id
    AND (
      e.user_id = auth.uid() -- Creator
      OR c.owner_id = auth.uid() -- Venue owner
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to check user's event access level
CREATE OR REPLACE FUNCTION get_event_access_level(event_id UUID)
RETURNS TEXT AS $$
DECLARE
  access_level TEXT;
BEGIN
  -- Check if user is the event creator
  IF EXISTS (
    SELECT 1 FROM events WHERE id = event_id AND user_id = auth.uid()
  ) THEN
    RETURN 'organizer';
  END IF;

  -- Check if user is the venue owner
  IF EXISTS (
    SELECT 1 FROM events e
    INNER JOIN clubs c ON e.club_id = c.id
    WHERE e.id = event_id AND c.owner_id = auth.uid()
  ) THEN
    RETURN 'venue_owner';
  END IF;

  -- Check if user is a promoter for this event
  IF EXISTS (
    SELECT 1 FROM promo_codes
    WHERE event_id = event_id AND promoter_id = auth.uid()
  ) THEN
    RETURN 'promoter';
  END IF;

  -- Check if user is staff for this event
  IF EXISTS (
    SELECT 1 FROM shifts
    WHERE event_id = event_id AND staff_id = auth.uid()
  ) THEN
    RETURN 'staff';
  END IF;

  -- No access
  RETURN 'none';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =========================================================
-- VERIFICATION QUERIES (Run these to test)
-- =========================================================

-- Test 1: View your access level to an event
-- SELECT get_event_access_level('event-uuid-here');

-- Test 2: Check if you can manage an event
-- SELECT can_manage_event('event-uuid-here');

-- Test 3: View all events you have access to (respects RLS)
-- SELECT * FROM events;

-- Test 4: Count events by status
-- SELECT status, COUNT(*) FROM events GROUP BY status;
