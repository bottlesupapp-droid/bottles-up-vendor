-- Migration: Storage Buckets and Policies
-- Description: Creates storage buckets and RLS policies for file uploads
-- Date: 2025-12-21

-- ============================================================================
-- 1. CREATE STORAGE BUCKETS
-- ============================================================================

-- Insert buckets into storage.buckets table
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    -- Venue gallery photos (public, up to 10MB per image)
    ('venue-gallery', 'venue-gallery', true, 10485760, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']),

    -- Venue legal documents (private, up to 10MB per document)
    ('venue-documents', 'venue-documents', false, 10485760, ARRAY['application/pdf', 'image/jpeg', 'image/jpg', 'image/png']),

    -- Profile photos for promoters, staff, organizers (public, up to 5MB)
    ('profile-photos', 'profile-photos', true, 5242880, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']),

    -- Staff ID documents (private, up to 10MB)
    ('id-documents', 'id-documents', false, 10485760, ARRAY['application/pdf', 'image/jpeg', 'image/jpg', 'image/png'])
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 2. VENUE GALLERY BUCKET POLICIES
-- ============================================================================

-- Venue owners can upload to their own folder
CREATE POLICY "Venue owners can upload gallery photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'venue-gallery'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Venue owners can update their own photos
CREATE POLICY "Venue owners can update their gallery photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'venue-gallery'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Venue owners can delete their own photos
CREATE POLICY "Venue owners can delete their gallery photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'venue-gallery'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Anyone authenticated can view gallery photos (public bucket)
CREATE POLICY "Authenticated users can view gallery photos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'venue-gallery');

-- ============================================================================
-- 3. VENUE DOCUMENTS BUCKET POLICIES
-- ============================================================================

-- Venue owners can upload documents to their own folder
CREATE POLICY "Venue owners can upload documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'venue-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Venue owners can update their own documents
CREATE POLICY "Venue owners can update their documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'venue-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Venue owners can delete their own documents
CREATE POLICY "Venue owners can delete their documents"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'venue-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Venue owners can view their own documents
CREATE POLICY "Venue owners can view their documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'venue-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- 4. PROFILE PHOTOS BUCKET POLICIES
-- ============================================================================

-- Users can upload their own profile photo
CREATE POLICY "Users can upload their profile photo"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'profile-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can update their own profile photo
CREATE POLICY "Users can update their profile photo"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'profile-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own profile photo
CREATE POLICY "Users can delete their profile photo"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'profile-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Anyone authenticated can view profile photos (public bucket)
CREATE POLICY "Authenticated users can view profile photos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'profile-photos');

-- ============================================================================
-- 5. ID DOCUMENTS BUCKET POLICIES
-- ============================================================================

-- Staff can upload their own ID documents
CREATE POLICY "Staff can upload ID documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'id-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Staff can update their own ID documents
CREATE POLICY "Staff can update their ID documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'id-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Staff can delete their own ID documents
CREATE POLICY "Staff can delete their ID documents"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'id-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Staff can view their own ID documents
CREATE POLICY "Staff can view their ID documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'id-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Venue owners can view ID documents of staff assigned to their venues
CREATE POLICY "Venue owners can view staff ID documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'id-documents'
    AND EXISTS (
        SELECT 1 FROM staff_profiles sp
        JOIN staff_shifts ss ON sp.id = ss.staff_id
        JOIN venue_details vd ON ss.venue_id = vd.id
        WHERE sp.vendor_id::text = (storage.foldername(name))[1]
        AND vd.vendor_id = auth.uid()
    )
);

-- ============================================================================
-- 6. HELPER FUNCTIONS
-- ============================================================================

-- Function to get file extension
CREATE OR REPLACE FUNCTION storage.get_file_extension(filename text)
RETURNS text AS $$
BEGIN
    RETURN lower(substring(filename from '\.([^\.]*)$'));
END;
$$ LANGUAGE plpgsql;

-- Function to generate unique filename
CREATE OR REPLACE FUNCTION storage.generate_unique_filename(
    original_filename text,
    user_id uuid
)
RETURNS text AS $$
DECLARE
    extension text;
    timestamp_str text;
    random_str text;
BEGIN
    extension := storage.get_file_extension(original_filename);
    timestamp_str := to_char(now(), 'YYYYMMDD_HH24MISS');
    random_str := substr(md5(random()::text), 1, 8);

    RETURN user_id::text || '/' || timestamp_str || '_' || random_str || '.' || extension;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

-- Example file paths structure:
-- venue-gallery/{vendor_id}/20231221_143025_a1b2c3d4.jpg
-- venue-documents/{vendor_id}/bar_license_20231221_143025.pdf
-- profile-photos/{vendor_id}/profile_20231221_143025.jpg
-- id-documents/{vendor_id}/aadhaar_20231221_143025.pdf

-- To upload a file from Flutter:
-- final String path = await storage.generate_unique_filename('photo.jpg', userId);
-- await supabase.storage.from('venue-gallery').upload(path, file);
-- final String publicUrl = supabase.storage.from('venue-gallery').getPublicUrl(path);
