import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/responsive_wrapper.dart';

class DatabaseSetupScreen extends StatelessWidget {
  const DatabaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Database Setup Required'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ResponsiveWrapper(
        centerContent: true,
        maxWidth: 600,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.storage,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Database Setup Required',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Description
              Text(
                'Your Supabase database needs to be set up with the required tables and permissions. Follow the steps below to complete the setup.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Steps
              _buildStep(
                context,
                step: 1,
                title: 'Open Supabase Dashboard',
                description: 'Go to your Supabase project dashboard',
                action: () => _openSupabaseDashboard(context),
                actionText: 'Open Dashboard',
              ),
              
              const SizedBox(height: 16),
              
              _buildStep(
                context,
                step: 2,
                title: 'Copy SQL Script',
                description: 'Copy the database setup script to your clipboard',
                action: () => _copySqlScript(context),
                actionText: 'Copy Script',
              ),
              
              const SizedBox(height: 16),
              
              _buildStep(
                context,
                step: 3,
                title: 'Run SQL Script',
                description: 'Paste and run the script in the SQL Editor',
                action: () => _showSqlInstructions(context),
                actionText: 'View Instructions',
              ),
              
              const SizedBox(height: 32),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.go('/auth/login');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: const Text(
                        'Continue to Login',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.go('/debug');
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Debug Tools'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Help text
              Text(
                'Need help? Check the documentation or contact support.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required int step,
    required String title,
    required String description,
    required VoidCallback action,
    required String actionText,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Step number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Action button
          TextButton(
            onPressed: action,
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  void _openSupabaseDashboard(BuildContext context) async {
    const url = 'https://supabase.com/dashboard';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Supabase dashboard')),
        );
      }
    }
  }

  void _copySqlScript(BuildContext context) {
    const sqlScript = '''
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
''';

    Clipboard.setData(const ClipboardData(text: sqlScript));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SQL script copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showSqlInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Run the SQL Script'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Go to your Supabase project dashboard'),
            SizedBox(height: 8),
            Text('2. Click on "SQL Editor" in the left sidebar'),
            SizedBox(height: 8),
            Text('3. Click "New query" to create a new SQL query'),
            SizedBox(height: 8),
            Text('4. Paste the copied SQL script into the editor'),
            SizedBox(height: 8),
            Text('5. Click "Run" to execute the script'),
            SizedBox(height: 8),
            Text('6. Wait for the script to complete successfully'),
            SizedBox(height: 8),
            Text('7. Return to the app and try registering again'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
