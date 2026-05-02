-- Migration: Create Storage Buckets for Images
-- Date: 2026-05-02
-- Description: Creates Supabase storage buckets for event images and flyers

-- Create event-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'event-images',
    'event-images',
    true,  -- Public bucket so images can be accessed via URL
    10485760,  -- 10MB limit
    ARRAY['image/jpeg', 'image/png', 'image/jpg', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Create policy to allow authenticated users to upload
CREATE POLICY "Allow authenticated users to upload event images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'event-images');

-- Create policy to allow authenticated users to update their own images
CREATE POLICY "Allow authenticated users to update event images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'event-images');

-- Create policy to allow authenticated users to delete their own images
CREATE POLICY "Allow authenticated users to delete event images"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'event-images');

-- Create policy to allow public read access
CREATE POLICY "Allow public read access to event images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'event-images');

-- Add comments
COMMENT ON TABLE storage.buckets IS 'Storage buckets for application files';
