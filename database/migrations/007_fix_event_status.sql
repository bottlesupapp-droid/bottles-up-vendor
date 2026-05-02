-- Migration: Fix Event Status Values
-- Date: 2026-05-02
-- Description: Updates existing events to have proper status values and ensures status field has proper constraints

-- Update any NULL status values to 'active'
UPDATE events
SET status = 'active'
WHERE status IS NULL;

-- Normalize any non-standard status values to 'active'
-- This handles cases like 'published', 'upcoming', or other legacy values
UPDATE events
SET status = 'active'
WHERE status NOT IN ('active', 'draft', 'completed', 'cancelled');

-- Auto-complete events that are in the past but still marked as 'active'
UPDATE events
SET status = 'completed'
WHERE status = 'active'
  AND event_date < CURRENT_DATE;

-- Update the status column to have a default if it doesn't already
ALTER TABLE events
ALTER COLUMN status SET DEFAULT 'active';

-- Add constraint to ensure only valid status values (optional but recommended)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'events_status_check'
    ) THEN
        ALTER TABLE events
        ADD CONSTRAINT events_status_check
        CHECK (status IN ('active', 'draft', 'completed', 'cancelled'));
    END IF;
END $$;

-- Add comment
COMMENT ON COLUMN events.status IS 'Event status: active (upcoming/published), draft (not published), completed (past event), cancelled';

-- Add index on status for better query performance
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_status_date ON events(status, event_date);
