-- Migration: Fix Event Status Constraint
-- Date: 2026-05-02
-- Description: Removes conflicting constraint and ensures proper status handling

-- Drop the existing constraint if it exists
ALTER TABLE events
DROP CONSTRAINT IF EXISTS events_status_check;

-- Update any NULL status values to 'active'
UPDATE events
SET status = 'active'
WHERE status IS NULL;

-- Normalize any non-standard status values to 'active'
UPDATE events
SET status = 'active'
WHERE status NOT IN ('active', 'draft', 'completed', 'cancelled');

-- Auto-complete events that are in the past
UPDATE events
SET status = 'completed'
WHERE status = 'active'
  AND event_date < CURRENT_DATE;

-- Set default for status column
ALTER TABLE events
ALTER COLUMN status SET DEFAULT 'active';

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_status_date ON events(status, event_date);

-- Add comment
COMMENT ON COLUMN events.status IS 'Event status: active, draft, completed, or cancelled';
