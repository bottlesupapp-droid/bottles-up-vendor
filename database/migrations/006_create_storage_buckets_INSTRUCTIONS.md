# Storage Bucket Setup Instructions

## ⚠️ Important: Storage buckets cannot be created via SQL migration
Storage buckets must be created through the Supabase Dashboard UI due to permission restrictions.

## Step-by-Step Instructions

### 1. Create the Storage Bucket

1. Go to your Supabase Dashboard: https://app.supabase.com
2. Select your project: `bottles-up-2d907`
3. Click on **Storage** in the left sidebar
4. Click **New bucket** button
5. Fill in the details:
   - **Name**: `event-images`
   - **Public bucket**: ✅ **Enable** (check the box)
   - **File size limit**: `10485760` (10 MB)
   - **Allowed MIME types**: `image/jpeg, image/png, image/jpg, image/webp`
6. Click **Create bucket**

### 2. Set Up RLS Policies

After creating the bucket, run this SQL in the SQL Editor to set up the access policies:

```sql
-- Allow authenticated users to upload event images
CREATE POLICY "Allow authenticated users to upload event images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'event-images');

-- Allow authenticated users to update event images
CREATE POLICY "Allow authenticated users to update event images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'event-images');

-- Allow authenticated users to delete event images
CREATE POLICY "Allow authenticated users to delete event images"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'event-images');

-- Allow public read access to event images
CREATE POLICY "Allow public read access to event images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'event-images');
```

### 3. Verify Setup

After completing the above steps, verify:
- The bucket `event-images` appears in Storage section
- It shows as **Public**
- File size limit is 10 MB
- You can see the RLS policies under Storage > Policies

## Alternative: Quick Setup via Dashboard Only

You can also set policies through the UI:
1. Go to **Storage** > Click on `event-images` bucket
2. Click **Policies** tab
3. Click **New Policy** for each operation (SELECT, INSERT, UPDATE, DELETE)
4. Use the templates or create custom policies as shown above

## Troubleshooting

If you get permission errors:
- Make sure you're logged in as the project owner
- Check that RLS is enabled on storage.objects table
- Verify your authentication is working correctly

## After Setup

Once the bucket is created and policies are set, your image upload feature will work automatically. No code changes needed!
