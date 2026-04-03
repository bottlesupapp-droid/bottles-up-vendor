# Database Setup Guide

## Issue
You're encountering a "Database error saving new user" error during registration. This happens because the required database tables don't exist in your Supabase project.

## Solution

### Step 1: Set up your Supabase Database

1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Navigate to the **SQL Editor** in the left sidebar
3. Create a new query and paste the contents of `database_setup.sql`
4. Click **Run** to execute the script

### Step 2: Verify the Setup

After running the script, you should see:
- `vendors` table created
- `events` table created  
- `inventory` table created
- `bookings` table created
- Row Level Security (RLS) policies enabled
- Database indexes created

### Step 3: Test Registration

1. Run your Flutter app
2. Try registering a new user
3. The registration should now work without the database error

## Database Schema Overview

### Vendors Table
Stores vendor user profiles with authentication and permissions.

### Events Table  
Stores event information managed by vendors.

### Inventory Table
Stores product inventory managed by vendors.

### Bookings Table
Stores customer bookings for events.

## Troubleshooting

### If you still get errors:

1. **Check Supabase Connection**: Verify your Supabase URL and anon key in `lib/core/config/supabase_config.dart`

2. **Check RLS Policies**: Make sure Row Level Security is properly configured

3. **Check Table Permissions**: Ensure the `auth.users` table exists and is accessible

4. **Check Logs**: Look at the Supabase logs in the dashboard for detailed error messages

### Common Issues:

- **Table doesn't exist**: Run the database setup script
- **Permission denied**: Check RLS policies
- **Foreign key constraint**: Ensure the `auth.users` table exists

## Support

If you continue to have issues, check the Supabase logs in your project dashboard for more detailed error information.
