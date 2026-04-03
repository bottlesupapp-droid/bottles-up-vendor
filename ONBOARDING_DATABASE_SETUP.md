# Onboarding Database Setup Guide

This guide explains how to set up the database tables and storage buckets for the onboarding system.

## Overview

The onboarding system has been designed to support 4 different user roles, each with their own onboarding flow:

1. **Venue Owner** - 7-step onboarding with venue details, gallery, documents, zones, and menu
2. **Organizer** - 4-step onboarding with organization info, logo, and social links
3. **Promoter** - 3-step onboarding with basic info and promo code setup
4. **Staff** - 3-step onboarding with role selection and ID verification

## Database Migrations

### Step 1: Apply Table Migrations

Run the following migration in your Supabase SQL Editor:

```bash
# File: supabase/migrations/004_onboarding_tables_and_storage.sql
```

This migration creates:

**Updated Vendors Table:**
- Adds `logo_url`, `stripe_account_id`, `onboarding_completed`, `two_fa_enabled`, `updated_at` fields
- Adds automatic `updated_at` trigger

**Venue Owner Tables:**
- `venue_details` - Main venue information
- `venue_gallery` - Venue photos (minimum 5 required)
- `venue_documents` - Legal documents (bar license, FSSAI, GST, etc.)
- `venue_zones` - Floor plan zones/areas
- `venue_bottle_menu` - Bottle offerings and pricing

**Organizer Tables:**
- `organizer_profiles` - Organization info and social links

**Promoter Tables:**
- `promoter_profiles` - Promoter info and bank details
- `promoter_event_assignments` - Track which events promoters are promoting

**Staff Tables:**
- `staff_profiles` - Staff roles and ID documents
- `staff_shifts` - Shift scheduling for staff

### Step 2: Apply Storage Bucket Migration

Run the following migration in your Supabase SQL Editor:

```bash
# File: supabase/migrations/005_storage_buckets_and_policies.sql
```

This creates 4 storage buckets:

1. **venue-gallery** (public)
   - Max file size: 10MB
   - Allowed types: JPEG, PNG, WebP
   - Purpose: Venue photos

2. **venue-documents** (private)
   - Max file size: 10MB
   - Allowed types: PDF, JPEG, PNG
   - Purpose: Legal documents

3. **profile-photos** (public)
   - Max file size: 5MB
   - Allowed types: JPEG, PNG, WebP
   - Purpose: User profile photos

4. **id-documents** (private)
   - Max file size: 10MB
   - Allowed types: PDF, JPEG, PNG
   - Purpose: Staff ID verification documents

### Step 3: Verify Installation

After running both migrations, verify the setup:

1. **Check Tables:**
   ```sql
   SELECT table_name
   FROM information_schema.tables
   WHERE table_schema = 'public'
   AND table_name LIKE '%venue%' OR table_name LIKE '%organizer%' OR table_name LIKE '%promoter%' OR table_name LIKE '%staff%';
   ```

2. **Check Storage Buckets:**
   ```sql
   SELECT id, name, public FROM storage.buckets;
   ```

3. **Check RLS Policies:**
   ```sql
   SELECT schemaname, tablename, policyname
   FROM pg_policies
   WHERE schemaname = 'public';
   ```

## Database Schema Reference

### Venue Owner Data Flow

```
vendors (role = 'venue_owner')
  ├─> venue_details (1:1)
  ├─> venue_gallery (1:many)
  ├─> venue_documents (1:many)
  ├─> venue_zones (1:many)
  └─> venue_bottle_menu (1:many)
```

### Organizer Data Flow

```
vendors (role = 'organizer')
  └─> organizer_profiles (1:1)
```

### Promoter Data Flow

```
vendors (role = 'promoter')
  └─> promoter_profiles (1:1)
      └─> promoter_event_assignments (1:many)
```

### Staff Data Flow

```
vendors (role = 'staff')
  └─> staff_profiles (1:1)
      └─> staff_shifts (1:many)
```

## Storage Bucket File Paths

All uploaded files follow this pattern:
```
{bucket-name}/{vendor_id}/{timestamp}_{random}_{filename}
```

Examples:
- `venue-gallery/123e4567-e89b-12d3-a456-426614174000/20231221_143025_a1b2c3d4.jpg`
- `venue-documents/123e4567-e89b-12d3-a456-426614174000/bar_license_20231221_143025.pdf`
- `profile-photos/123e4567-e89b-12d3-a456-426614174000/profile_20231221_143025.jpg`
- `id-documents/123e4567-e89b-12d3-a456-426614174000/aadhaar_20231221_143025.pdf`

## Row Level Security (RLS) Summary

### Venue Tables
- **Venue owners** can manage their own venue data
- **Organizers** can VIEW venue data (for browsing and sending proposals)
- **Documents** are only visible to the venue owner

### Profile Tables
- **Each role** can manage their own profile
- **Related roles** can view profiles (e.g., organizers can view promoter profiles)

### Storage Buckets
- **Users** can only upload/modify/delete files in their own folder (`{vendor_id}/`)
- **Public buckets** (venue-gallery, profile-photos) are viewable by all authenticated users
- **Private buckets** (venue-documents, id-documents) are only viewable by the owner

## Dart Models

New models have been created in `lib/shared/models/`:

1. **venue_details_model.dart**
   - `VenueDetailsModel`
   - `VenueGalleryModel`
   - `VenueDocumentModel`
   - `VenueZoneModel`
   - `VenueBottleMenuModel`

2. **onboarding_profiles_model.dart**
   - `OrganizerProfileModel`
   - `PromoterProfileModel`
   - `StaffProfileModel`
   - `PromoterEventAssignmentModel`

## Next Steps

To integrate the onboarding screens with Supabase:

1. Create services for each profile type in `lib/shared/services/`:
   - `venue_onboarding_service.dart`
   - `organizer_onboarding_service.dart`
   - `promoter_onboarding_service.dart`
   - `staff_onboarding_service.dart`

2. Update onboarding screens to:
   - Upload images/documents to Supabase Storage
   - Save form data to respective tables
   - Update `vendors.onboarding_completed = true` on completion

3. Implement file upload helpers:
   - Create `lib/shared/utils/storage_helper.dart` for file uploads
   - Use `supabase.storage.from('bucket-name').upload(path, file)`
   - Generate public URLs with `supabase.storage.from('bucket-name').getPublicUrl(path)`

## Security Considerations

1. **File Size Limits**: All buckets have size limits to prevent abuse
2. **File Type Validation**: Only allowed MIME types can be uploaded
3. **Path-Based Security**: Users can only access files in their own folder
4. **RLS Policies**: All tables have row-level security enabled
5. **Private Documents**: Legal documents and ID documents are in private buckets

## Troubleshooting

### Common Issues

1. **"Policy violation" error when inserting**
   - Ensure RLS policies are properly set up
   - Check that `auth.uid()` matches `vendor_id`

2. **"Storage bucket not found"**
   - Run migration 005 to create buckets
   - Check bucket name matches exactly (case-sensitive)

3. **"File too large" error**
   - Check file size limits in bucket configuration
   - Compress images before upload

4. **"Invalid MIME type" error**
   - Check `allowed_mime_types` in bucket configuration
   - Ensure file extension matches actual file type

## Testing

To test the setup:

1. **Test Venue Owner Flow:**
   ```dart
   // Create venue details
   final venueDetails = VenueDetailsModel(...);
   await supabase.from('venue_details').insert(venueDetails.toMap());

   // Upload gallery photo
   final path = '$vendorId/${DateTime.now().millisecondsSinceEpoch}_photo.jpg';
   await supabase.storage.from('venue-gallery').upload(path, file);
   ```

2. **Test Organizer Flow:**
   ```dart
   // Create organizer profile
   final profile = OrganizerProfileModel(...);
   await supabase.from('organizer_profiles').insert(profile.toMap());
   ```

3. **Test Promoter Flow:**
   ```dart
   // Create promoter profile
   final profile = PromoterProfileModel(...);
   await supabase.from('promoter_profiles').insert(profile.toMap());
   ```

4. **Test Staff Flow:**
   ```dart
   // Create staff profile with roles
   final profile = StaffProfileModel(roles: ['door', 'security'], ...);
   await supabase.from('staff_profiles').insert(profile.toMap());
   ```

## Migration Rollback

If you need to rollback the migrations:

```sql
-- Drop all tables (in reverse order of creation)
DROP TABLE IF EXISTS staff_shifts CASCADE;
DROP TABLE IF EXISTS staff_profiles CASCADE;
DROP TABLE IF EXISTS promoter_event_assignments CASCADE;
DROP TABLE IF EXISTS promoter_profiles CASCADE;
DROP TABLE IF EXISTS organizer_profiles CASCADE;
DROP TABLE IF EXISTS venue_bottle_menu CASCADE;
DROP TABLE IF EXISTS venue_zones CASCADE;
DROP TABLE IF EXISTS venue_documents CASCADE;
DROP TABLE IF EXISTS venue_gallery CASCADE;
DROP TABLE IF EXISTS venue_details CASCADE;

-- Drop buckets
DELETE FROM storage.buckets WHERE id IN ('venue-gallery', 'venue-documents', 'profile-photos', 'id-documents');

-- Revert vendors table changes
ALTER TABLE vendors DROP COLUMN IF EXISTS logo_url;
ALTER TABLE vendors DROP COLUMN IF EXISTS stripe_account_id;
ALTER TABLE vendors DROP COLUMN IF EXISTS onboarding_completed;
ALTER TABLE vendors DROP COLUMN IF EXISTS two_fa_enabled;
ALTER TABLE vendors DROP COLUMN IF EXISTS updated_at;
```

## Support

For issues or questions:
1. Check Supabase dashboard for error logs
2. Review RLS policies in Settings > Policies
3. Check Storage policies in Storage > Policies
4. Review migration files for correct syntax
