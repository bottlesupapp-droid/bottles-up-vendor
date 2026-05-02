-- Migration: Add dress_code and min_age fields to events table
-- Date: 2026-04-29
-- Description: Adds new fields for event dress code and minimum age restriction

-- Add dress_code column
ALTER TABLE events
ADD COLUMN IF NOT EXISTS dress_code TEXT;

-- Add min_age column
ALTER TABLE events
ADD COLUMN IF NOT EXISTS min_age INTEGER;

-- Add check constraint for min_age (0-100)
ALTER TABLE events
ADD CONSTRAINT check_min_age_range
CHECK (min_age IS NULL OR (min_age >= 0 AND min_age <= 100));

-- Add comment for documentation
COMMENT ON COLUMN events.dress_code IS 'Dress code requirement for the event (e.g., Smart Casual, Formal)';
COMMENT ON COLUMN events.min_age IS 'Minimum age requirement for event entry (0-100)';

-- Create index for filtering events by age restriction
CREATE INDEX IF NOT EXISTS idx_events_min_age ON events(min_age) WHERE min_age IS NOT NULL;

-- Update existing events to have NULL values (no dress code or age restriction)
-- No action needed as ALTER TABLE ADD COLUMN defaults to NULL
