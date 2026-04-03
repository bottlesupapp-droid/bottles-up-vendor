# Supabase Setup Instructions

## 1. Create a Supabase Project
1. Go to [https://supabase.com](https://supabase.com)
2. Sign up or login to your account
3. Click "New Project"
4. Choose your organization and fill in:
   - Project name: `bottles-up-vendor`
   - Database password: (choose a strong password)
   - Region: (choose closest to your location)

## 2. Get Your Project Credentials
1. Go to your project dashboard
2. Click on Settings > API
3. Copy your:
   - Project URL (e.g., `https://xxxxx.supabase.co`)
   - `anon` public key

## 3. Configure Your App
Update `lib/core/config/supabase_config.dart` with your credentials:

```dart
class SupabaseConfig {
  static const String url = 'https://your-project-id.supabase.co';
  static const String anonKey = 'your-anon-key-here';
  
  // ... rest of the code
}
```

## 4. Set Up Database Tables
Run these SQL commands in your Supabase SQL Editor:

```sql
-- Create vendors table
CREATE TABLE vendors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR UNIQUE NOT NULL,
  name VARCHAR NOT NULL,
  business_name VARCHAR,
  phone_number VARCHAR,
  profile_image_url VARCHAR,
  is_verified BOOLEAN DEFAULT FALSE,
  role VARCHAR DEFAULT 'staff',
  permissions JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create events table
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title VARCHAR NOT NULL,
  description TEXT,
  venue VARCHAR,
  date TIMESTAMP WITH TIME ZONE,
  price DECIMAL(10,2),
  capacity INTEGER,
  booked_seats INTEGER DEFAULT 0,
  vendor_id UUID REFERENCES vendors(id),
  status VARCHAR DEFAULT 'active',
  featured BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create inventory table
CREATE TABLE inventory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR NOT NULL,
  category VARCHAR,
  brand VARCHAR,
  description TEXT,
  price DECIMAL(10,2),
  stock INTEGER DEFAULT 0,
  min_stock INTEGER DEFAULT 0,
  vendor_id UUID REFERENCES vendors(id),
  featured BOOLEAN DEFAULT FALSE,
  alcohol_content DECIMAL(4,2),
  volume INTEGER,
  unit VARCHAR DEFAULT 'ml',
  image_url VARCHAR,
  tags JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create bookings table
CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id),
  user_id UUID,
  vendor_id UUID REFERENCES vendors(id),
  customer_name VARCHAR NOT NULL,
  customer_email VARCHAR NOT NULL,
  customer_phone VARCHAR,
  seats INTEGER DEFAULT 1,
  total_amount DECIMAL(10,2),
  status VARCHAR DEFAULT 'pending',
  payment_status VARCHAR DEFAULT 'pending',
  payment_method VARCHAR,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Add RLS policies (vendors can only see their own data)
CREATE POLICY "Vendors can view own data" ON vendors FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Vendors can update own data" ON vendors FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Vendors can view own events" ON events FOR ALL USING (vendor_id = auth.uid());
CREATE POLICY "Vendors can view own inventory" ON inventory FOR ALL USING (vendor_id = auth.uid());
CREATE POLICY "Vendors can view own bookings" ON bookings FOR ALL USING (vendor_id = auth.uid());
```

## 5. Run the App
After setting up the credentials and database, run:
```bash
flutter run
```

The app will automatically create sample data when a new user registers.