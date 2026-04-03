import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class DatabaseSetup {
  static final SupabaseClient _client = SupabaseConfig.client;

  /// Check if the database is properly set up
  static Future<bool> isDatabaseReady() async {
    try {
      // Try to query the vendors table
      await _client.from('vendors').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Set up the database tables and policies
  static Future<void> setupDatabase() async {
    try {
      // Create vendors table
      await _createVendorsTable();
      
      // Create events table
      await _createEventsTable();
      
      // Create inventory table
      await _createInventoryTable();
      
      // Create bookings table
      await _createBookingsTable();
      
      // Set up RLS policies
      await _setupRLSPolicies();
      
      // Create indexes
      await _createIndexes();
      
      print('Database setup completed successfully');
    } catch (e) {
      print('Database setup failed: $e');
      rethrow;
    }
  }

  static Future<void> _createVendorsTable() async {
    await _client.rpc('exec_sql', params: {
      'sql': '''
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
      '''
    });
  }

  static Future<void> _createEventsTable() async {
    await _client.rpc('exec_sql', params: {
      'sql': '''
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
      '''
    });
  }

  static Future<void> _createInventoryTable() async {
    await _client.rpc('exec_sql', params: {
      'sql': '''
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
      '''
    });
  }

  static Future<void> _createBookingsTable() async {
    await _client.rpc('exec_sql', params: {
      'sql': '''
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
      '''
    });
  }

  static Future<void> _setupRLSPolicies() async {
    // Enable RLS on all tables
    await _client.rpc('exec_sql', params: {
      'sql': '''
        ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
        ALTER TABLE events ENABLE ROW LEVEL SECURITY;
        ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
        ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
      '''
    });

    // Create policies
    await _client.rpc('exec_sql', params: {
      'sql': '''
        DROP POLICY IF EXISTS "Vendors can view own profile" ON vendors;
        CREATE POLICY "Vendors can view own profile" ON vendors
          FOR SELECT USING (auth.uid() = id);

        DROP POLICY IF EXISTS "Vendors can update own profile" ON vendors;
        CREATE POLICY "Vendors can update own profile" ON vendors
          FOR UPDATE USING (auth.uid() = id);

        DROP POLICY IF EXISTS "Vendors can insert own profile" ON vendors;
        CREATE POLICY "Vendors can insert own profile" ON vendors
          FOR INSERT WITH CHECK (auth.uid() = id);

        DROP POLICY IF EXISTS "Vendors can manage own events" ON events;
        CREATE POLICY "Vendors can manage own events" ON events
          FOR ALL USING (auth.uid() = vendor_id);

        DROP POLICY IF EXISTS "Vendors can manage own inventory" ON inventory;
        CREATE POLICY "Vendors can manage own inventory" ON inventory
          FOR ALL USING (auth.uid() = vendor_id);

        DROP POLICY IF EXISTS "Vendors can manage own bookings" ON bookings;
        CREATE POLICY "Vendors can manage own bookings" ON bookings
          FOR ALL USING (auth.uid() = vendor_id);
      '''
    });
  }

  static Future<void> _createIndexes() async {
    await _client.rpc('exec_sql', params: {
      'sql': '''
        CREATE INDEX IF NOT EXISTS idx_events_vendor_id ON events(vendor_id);
        CREATE INDEX IF NOT EXISTS idx_events_date ON events(date);
        CREATE INDEX IF NOT EXISTS idx_inventory_vendor_id ON inventory(vendor_id);
        CREATE INDEX IF NOT EXISTS idx_bookings_vendor_id ON bookings(vendor_id);
        CREATE INDEX IF NOT EXISTS idx_bookings_event_id ON bookings(event_id);
      '''
    });
  }
}
