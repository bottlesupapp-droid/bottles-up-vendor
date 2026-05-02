-- Migration: Ensure ticket_types table exists with proper structure
-- Date: 2026-04-29
-- Description: Creates or updates ticket_types table for multi-tier ticketing

-- Create ticket_types table if not exists
CREATE TABLE IF NOT EXISTS ticket_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    capacity INTEGER NOT NULL,
    sold_count INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Constraints
    CONSTRAINT check_capacity_positive CHECK (capacity > 0),
    CONSTRAINT check_sold_count_not_negative CHECK (sold_count >= 0),
    CONSTRAINT check_sold_count_not_exceed_capacity CHECK (sold_count <= capacity),
    CONSTRAINT check_price_not_negative CHECK (price >= 0)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ticket_types_event_id ON ticket_types(event_id);
CREATE INDEX IF NOT EXISTS idx_ticket_types_is_active ON ticket_types(is_active);
CREATE INDEX IF NOT EXISTS idx_ticket_types_created_at ON ticket_types(created_at);

-- Create trigger for updated_at
CREATE TRIGGER trigger_ticket_types_updated_at
    BEFORE UPDATE ON ticket_types
    FOR EACH ROW
    EXECUTE FUNCTION update_subscription_updated_at(); -- Reuse existing function

-- Add comments
COMMENT ON TABLE ticket_types IS 'Different ticket tiers/types for events (Early Bird, VIP, General, etc.)';
COMMENT ON COLUMN ticket_types.sold_count IS 'Number of tickets sold for this tier';
COMMENT ON COLUMN ticket_types.capacity IS 'Maximum number of tickets available for this tier';
