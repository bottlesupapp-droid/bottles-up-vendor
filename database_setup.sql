-- Database setup for Bottles Up Vendor App
-- Run this script in your Supabase SQL editor

-- Create vendors table
CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    business_name TEXT,
    phone_number TEXT,
    profile_image_url TEXT,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE,
    permissions TEXT[] DEFAULT '{}',
    role TEXT DEFAULT 'staff'
);

-- Create events table
CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    venue TEXT,
    date TIMESTAMP WITH TIME ZONE,
    price DECIMAL(10,2),
    capacity INTEGER,
    booked_seats INTEGER DEFAULT 0,
    vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'active',
    featured BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create inventory table
CREATE TABLE IF NOT EXISTS inventory (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,
    brand TEXT,
    description TEXT,
    price DECIMAL(10,2),
    stock INTEGER DEFAULT 0,
    min_stock INTEGER DEFAULT 0,
    vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
    featured BOOLEAN DEFAULT false,
    alcohol_content DECIMAL(5,2),
    volume INTEGER,
    unit TEXT,
    image_url TEXT,
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create bookings table
CREATE TABLE IF NOT EXISTS bookings (
    id TEXT PRIMARY KEY,
    event_id TEXT REFERENCES events(id) ON DELETE CASCADE,
    user_id TEXT,
    vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    customer_phone TEXT,
    seats INTEGER DEFAULT 1,
    total_amount DECIMAL(10,2),
    status TEXT DEFAULT 'pending',
    payment_status TEXT DEFAULT 'pending',
    payment_method TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create RLS (Row Level Security) policies
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Vendors policies
CREATE POLICY "Vendors can view own profile" ON vendors
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Vendors can update own profile" ON vendors
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Vendors can insert own profile" ON vendors
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Events policies
CREATE POLICY "Vendors can manage own events" ON events
    FOR ALL USING (auth.uid() = vendor_id);

-- Inventory policies
CREATE POLICY "Vendors can manage own inventory" ON inventory
    FOR ALL USING (auth.uid() = vendor_id);

-- Bookings policies
CREATE POLICY "Vendors can manage own bookings" ON bookings
    FOR ALL USING (auth.uid() = vendor_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_events_vendor_id ON events(vendor_id);
CREATE INDEX IF NOT EXISTS idx_events_date ON events(date);
CREATE INDEX IF NOT EXISTS idx_inventory_vendor_id ON inventory(vendor_id);
CREATE INDEX IF NOT EXISTS idx_bookings_vendor_id ON bookings(vendor_id);
CREATE INDEX IF NOT EXISTS idx_bookings_event_id ON bookings(event_id);

-- Insert sample data (optional)
-- You can uncomment these lines if you want to add sample data

/*
INSERT INTO vendors (id, email, name, business_name, is_verified, role, permissions) VALUES
('00000000-0000-0000-0000-000000000001', 'demo@bottlesup.com', 'Demo Vendor', 'Bottles Up Demo', true, 'admin', ARRAY['read_events', 'write_events', 'read_bookings', 'write_bookings', 'read_inventory', 'write_inventory', 'admin']);
*/
