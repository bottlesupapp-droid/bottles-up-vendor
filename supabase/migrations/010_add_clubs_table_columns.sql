-- Migration: Add missing columns to clubs table for venue onboarding
-- Description: Adds address, gallery, floorplan_data, social_links columns to support comprehensive venue information
-- Date: 2026-06-14

-- ============================================================================
-- 1. ADD MISSING COLUMNS TO CLUBS TABLE
-- ============================================================================

-- Add address column (JSONB to store street, city, state, zip, country)
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS address JSONB;

-- Add gallery column (array of photo URLs)
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS gallery TEXT[] DEFAULT '{}';

-- Add license_documents column (array of document URLs)
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS license_documents TEXT[] DEFAULT '{}';

-- Add floorplan_data column (JSONB to store description and other floorplan info)
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS floorplan_data JSONB;

-- Add social_links column (JSONB to store music genres, amenities, venue details)
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS social_links JSONB;

-- Add created_at and updated_at if they don't exist
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- ============================================================================
-- 2. ADD TRIGGER FOR UPDATED_AT
-- ============================================================================

-- Add trigger to automatically update updated_at (reuse existing function)
DROP TRIGGER IF EXISTS update_clubs_updated_at ON clubs;
CREATE TRIGGER update_clubs_updated_at
    BEFORE UPDATE ON clubs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 3. ADD COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON COLUMN clubs.address IS 'JSONB storing address details: {street, city, state, zip, country}';
COMMENT ON COLUMN clubs.gallery IS 'Array of photo URLs (banner, menu, interior photos)';
COMMENT ON COLUMN clubs.license_documents IS 'Array of legal document URLs (bar license, FSSAI, etc.)';
COMMENT ON COLUMN clubs.floorplan_data IS 'JSONB storing venue description and floorplan information';
COMMENT ON COLUMN clubs.social_links IS 'JSONB storing music genres, amenities, venue type, age requirement, dress code, VIP booths, side tables, etc.';

-- ============================================================================
-- 4. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Index for searching venues by city
CREATE INDEX IF NOT EXISTS idx_clubs_address_city ON clubs ((address->>'city'));

-- Index for searching venues by status
CREATE INDEX IF NOT EXISTS idx_clubs_status ON clubs (status);

-- Index for getting venues by owner
CREATE INDEX IF NOT EXISTS idx_clubs_owner_id ON clubs (owner_id);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify columns were added:
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'clubs'
-- ORDER BY ordinal_position;
