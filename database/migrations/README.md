# Database Migrations

This directory contains SQL migration scripts for the Bottles Up Vendor application.

## Migration Files

### 001_add_event_fields.sql
- **Purpose**: Adds dress code and minimum age fields to events table
- **Tables Modified**: `events`
- **New Columns**:
  - `dress_code` (TEXT) - Event dress code requirement
  - `min_age` (INTEGER) - Minimum age restriction (0-100)

### 002_create_subscription_tables.sql
- **Purpose**: Creates subscription management system
- **Tables Created**:
  - `subscription_plans` - Available subscription plans
  - `vendor_subscriptions` - Vendor subscription records
- **Features**:
  - 4 predefined plans: Free, Starter, Professional, Enterprise
  - Stripe integration fields
  - Automatic timestamp updates

### 003_create_stripe_accounts_table.sql
- **Purpose**: Creates Stripe Connect account management
- **Tables Created**:
  - `stripe_accounts` - Vendor Stripe Connect accounts
  - `payout_records` - Payout history tracking
- **Features**:
  - Account verification status tracking
  - Payout scheduling configuration
  - Balance tracking

### 004_update_ticket_types_table.sql
- **Purpose**: Creates multi-tier ticketing system
- **Tables Created**:
  - `ticket_types` - Ticket tiers for events
- **Features**:
  - Multiple price tiers per event
  - Capacity and sold count tracking
  - Active/inactive status

### 005_update_event_team_members_table.sql
- **Purpose**: Creates team/DJ management system
- **Tables Created**:
  - `event_team_members` - Team members assigned to events
- **Features**:
  - Support for DJs, coordinators, security, etc.
  - Contact information storage

## How to Run Migrations

### Using Supabase CLI

```bash
# Run all migrations
supabase db reset

# Or run individual migrations
supabase db execute --file database/migrations/001_add_event_fields.sql
supabase db execute --file database/migrations/002_create_subscription_tables.sql
supabase db execute --file database/migrations/003_create_stripe_accounts_table.sql
supabase db execute --file database/migrations/004_update_ticket_types_table.sql
supabase db execute --file database/migrations/005_update_event_team_members_table.sql
```

### Using SQL Client (psql, pgAdmin, etc.)

1. Connect to your PostgreSQL database
2. Execute each migration file in order (001, 002, 003, 004, 005)

```bash
psql -h your-host -U your-user -d your-database -f database/migrations/001_add_event_fields.sql
psql -h your-host -U your-user -d your-database -f database/migrations/002_create_subscription_tables.sql
# ... continue for all migrations
```

### Using Supabase Dashboard

1. Go to your Supabase project
2. Navigate to SQL Editor
3. Copy and paste each migration file content
4. Execute in order

## Migration Order

**IMPORTANT**: Migrations must be run in numerical order:
1. 001_add_event_fields.sql
2. 002_create_subscription_tables.sql
3. 003_create_stripe_accounts_table.sql
4. 004_update_ticket_types_table.sql
5. 005_update_event_team_members_table.sql

## Rollback Scripts

### Rollback 001 - Event Fields
```sql
ALTER TABLE events DROP COLUMN IF EXISTS dress_code;
ALTER TABLE events DROP COLUMN IF EXISTS min_age;
DROP INDEX IF EXISTS idx_events_min_age;
```

### Rollback 002 - Subscriptions
```sql
DROP TRIGGER IF EXISTS trigger_vendor_subscriptions_updated_at ON vendor_subscriptions;
DROP TRIGGER IF EXISTS trigger_subscription_plans_updated_at ON subscription_plans;
DROP TABLE IF EXISTS vendor_subscriptions CASCADE;
DROP TABLE IF EXISTS subscription_plans CASCADE;
DROP FUNCTION IF EXISTS update_subscription_updated_at();
```

### Rollback 003 - Stripe Accounts
```sql
DROP TRIGGER IF EXISTS trigger_stripe_accounts_updated_at ON stripe_accounts;
DROP TABLE IF EXISTS payout_records CASCADE;
DROP TABLE IF EXISTS stripe_accounts CASCADE;
```

### Rollback 004 - Ticket Types
```sql
DROP TRIGGER IF EXISTS trigger_ticket_types_updated_at ON ticket_types;
DROP TABLE IF EXISTS ticket_types CASCADE;
```

### Rollback 005 - Event Team Members
```sql
DROP TRIGGER IF EXISTS trigger_event_team_members_updated_at ON event_team_members;
DROP TABLE IF EXISTS event_team_members CASCADE;
```

## Verification Queries

After running migrations, verify the changes:

```sql
-- Check events table has new columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'events'
AND column_name IN ('dress_code', 'min_age');

-- Check subscription plans are inserted
SELECT id, name, price FROM subscription_plans ORDER BY price;

-- Check all new tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('subscription_plans', 'vendor_subscriptions', 'stripe_accounts', 'payout_records', 'ticket_types', 'event_team_members');

-- Check indexes are created
SELECT indexname, tablename
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('events', 'vendor_subscriptions', 'stripe_accounts', 'payout_records', 'ticket_types', 'event_team_members');
```

## Notes

- All migrations use `IF NOT EXISTS` / `IF EXISTS` to be idempotent
- Timestamps use `TIMESTAMP WITH TIME ZONE` for proper timezone handling
- Foreign keys use `ON DELETE CASCADE` where appropriate
- Indexes are created for commonly queried columns
- Check constraints ensure data integrity
- Triggers automatically update `updated_at` timestamps

## Support

If you encounter any issues with migrations:
1. Check PostgreSQL version compatibility (recommended: 14+)
2. Ensure you have proper permissions
3. Verify foreign key relationships exist
4. Check for existing data conflicts
