-- Migration: Onboarding Tables and Storage Buckets
-- Description: Creates tables and storage buckets for role-specific onboarding data
-- Date: 2025-12-21

-- ============================================================================
-- 1. UPDATE VENDORS TABLE
-- ============================================================================
-- Add missing fields to vendors table that VendorUser model expects
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS stripe_account_id TEXT;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS two_fa_enabled BOOLEAN DEFAULT false;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update the role field to have proper default
ALTER TABLE vendors ALTER COLUMN role SET DEFAULT 'staff';

-- Create updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_vendors_updated_at ON vendors;
CREATE TRIGGER update_vendors_updated_at
    BEFORE UPDATE ON vendors
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 2. VENUE OWNER TABLES
-- ============================================================================

-- Venue details table (for venue_owner role)
CREATE TABLE IF NOT EXISTS venue_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,

    -- Basic venue information (Step 1)
    venue_name TEXT NOT NULL,
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    capacity INTEGER NOT NULL,
    description TEXT,

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT venue_details_unique_vendor UNIQUE(vendor_id)
);

-- Venue gallery images table (Step 2)
CREATE TABLE IF NOT EXISTS venue_gallery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES venue_details(id) ON DELETE CASCADE,

    image_url TEXT NOT NULL,
    storage_path TEXT NOT NULL, -- Path in Supabase storage
    display_order INTEGER DEFAULT 0,
    is_primary BOOLEAN DEFAULT false,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT venue_gallery_unique_path UNIQUE(storage_path)
);

-- Venue legal documents table (Step 3)
CREATE TABLE IF NOT EXISTS venue_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES venue_details(id) ON DELETE CASCADE,

    document_type TEXT NOT NULL, -- bar_license, fssai, gst, fire_noc, shop_act
    document_url TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    document_number TEXT,
    issue_date DATE,
    expiry_date DATE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT venue_documents_unique_path UNIQUE(storage_path),
    CONSTRAINT venue_documents_type_check CHECK (document_type IN ('bar_license', 'fssai', 'gst', 'fire_noc', 'shop_act'))
);

-- Venue zones/areas for floorplan (Step 4)
CREATE TABLE IF NOT EXISTS venue_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES venue_details(id) ON DELETE CASCADE,

    zone_name TEXT NOT NULL,
    zone_type TEXT, -- vip, general, bar, dance_floor, etc.
    capacity INTEGER,
    description TEXT,
    display_order INTEGER DEFAULT 0,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Venue bottle menu (Step 5)
CREATE TABLE IF NOT EXISTS venue_bottle_menu (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES venue_details(id) ON DELETE CASCADE,

    bottle_name TEXT NOT NULL,
    brand TEXT,
    category TEXT, -- vodka, whiskey, rum, wine, champagne, etc.
    size TEXT, -- 750ml, 1L, etc.
    price DECIMAL(10,2) NOT NULL,
    description TEXT,
    is_available BOOLEAN DEFAULT true,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 3. ORGANIZER TABLES
-- ============================================================================

-- Organizer profile table
CREATE TABLE IF NOT EXISTS organizer_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,

    -- Organization info (Step 1)
    organization_name TEXT NOT NULL,
    description TEXT,

    -- Logo (Step 2) - stored in vendors.logo_url

    -- Social links (Step 3)
    instagram_handle TEXT NOT NULL,
    facebook_page TEXT,
    twitter_handle TEXT,
    website_url TEXT,

    -- Payout setup (Step 4) - stored in vendors.stripe_account_id

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT organizer_profiles_unique_vendor UNIQUE(vendor_id)
);

-- ============================================================================
-- 4. PROMOTER TABLES
-- ============================================================================

-- Promoter profile table
CREATE TABLE IF NOT EXISTS promoter_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,

    -- Basic info (Step 1)
    phone_number TEXT,
    profile_photo_url TEXT,
    profile_photo_path TEXT, -- Storage path

    -- Promo code info (Step 2)
    promo_code TEXT UNIQUE, -- Assigned by organizers, null until assigned
    total_sales INTEGER DEFAULT 0,
    total_commission DECIMAL(10,2) DEFAULT 0,

    -- Payout setup (Step 3) - can use vendors.stripe_account_id or separate bank details
    bank_account_holder TEXT,
    bank_account_number TEXT,
    bank_ifsc_code TEXT,
    bank_name TEXT,

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT promoter_profiles_unique_vendor UNIQUE(vendor_id)
);

-- Promoter event assignments (organizers assign promoters to events with promo codes)
CREATE TABLE IF NOT EXISTS promoter_event_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promoter_id UUID NOT NULL REFERENCES promoter_profiles(id) ON DELETE CASCADE,
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    organizer_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,

    promo_code TEXT NOT NULL,
    commission_percentage DECIMAL(5,2) NOT NULL, -- e.g., 10.00 for 10%
    tickets_sold INTEGER DEFAULT 0,
    commission_earned DECIMAL(10,2) DEFAULT 0,

    status TEXT DEFAULT 'active', -- active, inactive, completed

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT promoter_event_unique_code UNIQUE(event_id, promo_code)
);

-- ============================================================================
-- 5. STAFF TABLES
-- ============================================================================

-- Staff profile table
CREATE TABLE IF NOT EXISTS staff_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,

    -- Basic info (Step 1)
    phone_number TEXT,
    profile_photo_url TEXT,
    profile_photo_path TEXT, -- Storage path

    -- Role selection (Step 2)
    roles TEXT[] NOT NULL DEFAULT '{}', -- door, bottle_service, bartender, server, security, manager

    -- ID upload (Step 3)
    id_document_url TEXT,
    id_document_path TEXT, -- Storage path
    id_document_type TEXT, -- aadhaar, passport, driving_license, etc.
    id_document_number TEXT,

    -- Employment status
    is_available BOOLEAN DEFAULT true,
    current_venue_id UUID, -- Which venue they're currently assigned to

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT staff_profiles_unique_vendor UNIQUE(vendor_id),
    CONSTRAINT staff_roles_check CHECK (cardinality(roles) > 0) -- At least one role required
);

-- Staff shift assignments (venues assign staff to shifts)
CREATE TABLE IF NOT EXISTS staff_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID NOT NULL REFERENCES staff_profiles(id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES venue_details(id) ON DELETE CASCADE,
    event_id TEXT REFERENCES events(id) ON DELETE CASCADE, -- Can be for a specific event or general venue work

    shift_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    role TEXT NOT NULL, -- Which role they're working this shift

    status TEXT DEFAULT 'scheduled', -- scheduled, confirmed, completed, cancelled
    hourly_rate DECIMAL(10,2),
    total_hours DECIMAL(5,2),
    total_pay DECIMAL(10,2),

    notes TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 6. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Venue details indexes
CREATE INDEX IF NOT EXISTS idx_venue_details_vendor_id ON venue_details(vendor_id);

-- Venue gallery indexes
CREATE INDEX IF NOT EXISTS idx_venue_gallery_vendor_id ON venue_gallery(vendor_id);
CREATE INDEX IF NOT EXISTS idx_venue_gallery_venue_id ON venue_gallery(venue_id);
CREATE INDEX IF NOT EXISTS idx_venue_gallery_order ON venue_gallery(venue_id, display_order);

-- Venue documents indexes
CREATE INDEX IF NOT EXISTS idx_venue_documents_vendor_id ON venue_documents(vendor_id);
CREATE INDEX IF NOT EXISTS idx_venue_documents_venue_id ON venue_documents(venue_id);
CREATE INDEX IF NOT EXISTS idx_venue_documents_type ON venue_documents(venue_id, document_type);

-- Venue zones indexes
CREATE INDEX IF NOT EXISTS idx_venue_zones_vendor_id ON venue_zones(vendor_id);
CREATE INDEX IF NOT EXISTS idx_venue_zones_venue_id ON venue_zones(venue_id);

-- Venue bottle menu indexes
CREATE INDEX IF NOT EXISTS idx_venue_bottle_menu_vendor_id ON venue_bottle_menu(vendor_id);
CREATE INDEX IF NOT EXISTS idx_venue_bottle_menu_venue_id ON venue_bottle_menu(venue_id);
CREATE INDEX IF NOT EXISTS idx_venue_bottle_menu_category ON venue_bottle_menu(venue_id, category);

-- Organizer profiles indexes
CREATE INDEX IF NOT EXISTS idx_organizer_profiles_vendor_id ON organizer_profiles(vendor_id);

-- Promoter profiles indexes
CREATE INDEX IF NOT EXISTS idx_promoter_profiles_vendor_id ON promoter_profiles(vendor_id);
CREATE INDEX IF NOT EXISTS idx_promoter_profiles_promo_code ON promoter_profiles(promo_code) WHERE promo_code IS NOT NULL;

-- Promoter event assignments indexes
CREATE INDEX IF NOT EXISTS idx_promoter_events_promoter_id ON promoter_event_assignments(promoter_id);
CREATE INDEX IF NOT EXISTS idx_promoter_events_event_id ON promoter_event_assignments(event_id);
CREATE INDEX IF NOT EXISTS idx_promoter_events_organizer_id ON promoter_event_assignments(organizer_id);

-- Staff profiles indexes
CREATE INDEX IF NOT EXISTS idx_staff_profiles_vendor_id ON staff_profiles(vendor_id);
CREATE INDEX IF NOT EXISTS idx_staff_profiles_available ON staff_profiles(is_available) WHERE is_available = true;

-- Staff shifts indexes
CREATE INDEX IF NOT EXISTS idx_staff_shifts_staff_id ON staff_shifts(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_shifts_venue_id ON staff_shifts(venue_id);
CREATE INDEX IF NOT EXISTS idx_staff_shifts_event_id ON staff_shifts(event_id) WHERE event_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_staff_shifts_date ON staff_shifts(shift_date);

-- ============================================================================
-- 7. ADD TRIGGERS FOR UPDATED_AT
-- ============================================================================

-- Venue details
DROP TRIGGER IF EXISTS update_venue_details_updated_at ON venue_details;
CREATE TRIGGER update_venue_details_updated_at
    BEFORE UPDATE ON venue_details
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Venue zones
DROP TRIGGER IF EXISTS update_venue_zones_updated_at ON venue_zones;
CREATE TRIGGER update_venue_zones_updated_at
    BEFORE UPDATE ON venue_zones
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Venue bottle menu
DROP TRIGGER IF EXISTS update_venue_bottle_menu_updated_at ON venue_bottle_menu;
CREATE TRIGGER update_venue_bottle_menu_updated_at
    BEFORE UPDATE ON venue_bottle_menu
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Organizer profiles
DROP TRIGGER IF EXISTS update_organizer_profiles_updated_at ON organizer_profiles;
CREATE TRIGGER update_organizer_profiles_updated_at
    BEFORE UPDATE ON organizer_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Promoter profiles
DROP TRIGGER IF EXISTS update_promoter_profiles_updated_at ON promoter_profiles;
CREATE TRIGGER update_promoter_profiles_updated_at
    BEFORE UPDATE ON promoter_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Promoter event assignments
DROP TRIGGER IF EXISTS update_promoter_event_assignments_updated_at ON promoter_event_assignments;
CREATE TRIGGER update_promoter_event_assignments_updated_at
    BEFORE UPDATE ON promoter_event_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Staff profiles
DROP TRIGGER IF EXISTS update_staff_profiles_updated_at ON staff_profiles;
CREATE TRIGGER update_staff_profiles_updated_at
    BEFORE UPDATE ON staff_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Staff shifts
DROP TRIGGER IF EXISTS update_staff_shifts_updated_at ON staff_shifts;
CREATE TRIGGER update_staff_shifts_updated_at
    BEFORE UPDATE ON staff_shifts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all new tables
ALTER TABLE venue_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_gallery ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_bottle_menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE promoter_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE promoter_event_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_shifts ENABLE ROW LEVEL SECURITY;

-- VENUE DETAILS POLICIES
CREATE POLICY "Venue owners can manage their venue details" ON venue_details
    FOR ALL USING (auth.uid() = vendor_id);

CREATE POLICY "Organizers can view venue details" ON venue_details
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors
            WHERE vendors.id = auth.uid()
            AND vendors.role = 'organizer'
        )
    );

-- VENUE GALLERY POLICIES
CREATE POLICY "Venue owners can manage their gallery" ON venue_gallery
    FOR ALL USING (auth.uid() = vendor_id);

CREATE POLICY "Organizers can view venue galleries" ON venue_gallery
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors
            WHERE vendors.id = auth.uid()
            AND vendors.role = 'organizer'
        )
    );

-- VENUE DOCUMENTS POLICIES
CREATE POLICY "Venue owners can manage their documents" ON venue_documents
    FOR ALL USING (auth.uid() = vendor_id);

-- VENUE ZONES POLICIES
CREATE POLICY "Venue owners can manage their zones" ON venue_zones
    FOR ALL USING (auth.uid() = vendor_id);

CREATE POLICY "Organizers can view venue zones" ON venue_zones
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors
            WHERE vendors.id = auth.uid()
            AND vendors.role = 'organizer'
        )
    );

-- VENUE BOTTLE MENU POLICIES
CREATE POLICY "Venue owners can manage their bottle menu" ON venue_bottle_menu
    FOR ALL USING (auth.uid() = vendor_id);

CREATE POLICY "Organizers can view venue bottle menus" ON venue_bottle_menu
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors
            WHERE vendors.id = auth.uid()
            AND vendors.role = 'organizer'
        )
    );

-- ORGANIZER PROFILES POLICIES
CREATE POLICY "Organizers can manage their profile" ON organizer_profiles
    FOR ALL USING (auth.uid() = vendor_id);

CREATE POLICY "Venue owners can view organizer profiles" ON organizer_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors
            WHERE vendors.id = auth.uid()
            AND vendors.role = 'venue_owner'
        )
    );

-- PROMOTER PROFILES POLICIES
CREATE POLICY "Promoters can manage their profile" ON promoter_profiles
    FOR ALL USING (auth.uid() = vendor_id);

CREATE POLICY "Organizers can view promoter profiles" ON promoter_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors
            WHERE vendors.id = auth.uid()
            AND vendors.role = 'organizer'
        )
    );

-- PROMOTER EVENT ASSIGNMENTS POLICIES
CREATE POLICY "Promoters can view their assignments" ON promoter_event_assignments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM promoter_profiles
            WHERE promoter_profiles.id = promoter_event_assignments.promoter_id
            AND promoter_profiles.vendor_id = auth.uid()
        )
    );

CREATE POLICY "Organizers can manage promoter assignments" ON promoter_event_assignments
    FOR ALL USING (auth.uid() = organizer_id);

-- STAFF PROFILES POLICIES
CREATE POLICY "Staff can manage their profile" ON staff_profiles
    FOR ALL USING (auth.uid() = vendor_id);

CREATE POLICY "Venue owners can view staff profiles" ON staff_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors
            WHERE vendors.id = auth.uid()
            AND vendors.role = 'venue_owner'
        )
    );

-- STAFF SHIFTS POLICIES
CREATE POLICY "Staff can view their shifts" ON staff_shifts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM staff_profiles
            WHERE staff_profiles.id = staff_shifts.staff_id
            AND staff_profiles.vendor_id = auth.uid()
        )
    );

CREATE POLICY "Venue owners can manage shifts for their venue" ON staff_shifts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM venue_details
            WHERE venue_details.id = staff_shifts.venue_id
            AND venue_details.vendor_id = auth.uid()
        )
    );

-- ============================================================================
-- 9. STORAGE BUCKETS
-- ============================================================================
-- Note: Storage buckets need to be created via Supabase dashboard or CLI
-- This is a reference for bucket creation and policies

-- Buckets to create:
-- 1. venue-gallery (for venue photos)
-- 2. venue-documents (for legal documents)
-- 3. profile-photos (for promoter and staff profile photos)
-- 4. id-documents (for staff ID documents)

-- Storage policies will be set up in the next migration or via dashboard
