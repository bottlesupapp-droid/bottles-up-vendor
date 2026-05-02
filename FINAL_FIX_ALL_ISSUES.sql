-- ============================================
-- FINAL FIX: All Issues - Run This Once
-- ============================================
-- This script fixes:
-- 1. Event creation constraint error
-- 2. Missing subscription plans
-- 3. Event status display issues
-- ============================================

-- PART 1: Fix Events Table
-- ============================================

-- Drop the problematic constraint
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;

-- Update NULL or invalid status values
UPDATE events
SET status = 'active'
WHERE status IS NULL OR status NOT IN ('active', 'draft', 'completed', 'cancelled');

-- Auto-complete past events
UPDATE events
SET status = 'completed'
WHERE status = 'active' AND event_date < CURRENT_DATE;

-- Set default value
ALTER TABLE events
ALTER COLUMN status SET DEFAULT 'active';

-- Add performance indexes
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_status_date ON events(status, event_date);
CREATE INDEX IF NOT EXISTS idx_events_user_status ON events(user_id, status);
CREATE INDEX IF NOT EXISTS idx_events_date_status ON events(event_date, status);

-- Add helpful comment
COMMENT ON COLUMN events.status IS 'Event status: active (upcoming), draft (not published), completed (past), cancelled';


-- PART 2: Fix Subscription Plans
-- ============================================

-- Ensure subscription_plans table exists
CREATE TABLE IF NOT EXISTS subscription_plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    billing_period TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_period IN ('monthly', 'yearly')),
    max_events INTEGER NOT NULL DEFAULT -1,
    max_tickets_per_event INTEGER NOT NULL DEFAULT -1,
    has_analytics BOOLEAN NOT NULL DEFAULT false,
    has_custom_branding BOOLEAN NOT NULL DEFAULT false,
    has_priority_support BOOLEAN NOT NULL DEFAULT false,
    has_advanced_reporting BOOLEAN NOT NULL DEFAULT false,
    team_member_limit INTEGER NOT NULL DEFAULT 1,
    features JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_popular BOOLEAN NOT NULL DEFAULT false,
    stripe_product_id TEXT,
    stripe_price_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert or update all 4 subscription plans
INSERT INTO subscription_plans (id, name, description, price, billing_period, max_events, max_tickets_per_event, has_analytics, has_custom_branding, has_priority_support, has_advanced_reporting, team_member_limit, features, is_popular)
VALUES
    ('free', 'Free', 'Perfect for getting started', 0, 'monthly', 3, 50, false, false, false, false, 1,
     '["Up to 3 events per month", "Max 50 tickets per event", "Basic analytics", "Email support"]'::jsonb, false),

    ('starter', 'Starter', 'Great for small event organizers', 29.99, 'monthly', 10, 200, true, false, false, false, 3,
     '["Up to 10 events per month", "Max 200 tickets per event", "Advanced analytics", "Custom ticket tiers", "3 team members", "Email support"]'::jsonb, true),

    ('professional', 'Professional', 'For growing event businesses', 79.99, 'monthly', 50, 1000, true, true, true, true, 10,
     '["Up to 50 events per month", "Max 1000 tickets per event", "Advanced analytics & reporting", "Custom branding", "Priority support", "10 team members", "API access", "White-label options"]'::jsonb, false),

    ('enterprise', 'Enterprise', 'For large-scale operations', 199.99, 'monthly', -1, -1, true, true, true, true, -1,
     '["Unlimited events", "Unlimited tickets", "Advanced analytics & reporting", "Full custom branding", "Dedicated support", "Unlimited team members", "API access", "White-label options", "Custom integrations", "SLA guarantee"]'::jsonb, false)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    billing_period = EXCLUDED.billing_period,
    max_events = EXCLUDED.max_events,
    max_tickets_per_event = EXCLUDED.max_tickets_per_event,
    has_analytics = EXCLUDED.has_analytics,
    has_custom_branding = EXCLUDED.has_custom_branding,
    has_priority_support = EXCLUDED.has_priority_support,
    has_advanced_reporting = EXCLUDED.has_advanced_reporting,
    team_member_limit = EXCLUDED.team_member_limit,
    features = EXCLUDED.features,
    is_popular = EXCLUDED.is_popular,
    updated_at = NOW();

-- Ensure vendor_subscriptions table exists
CREATE TABLE IF NOT EXISTS vendor_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL REFERENCES subscription_plans(id),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'trialing', 'past_due', 'canceled', 'unpaid', 'incomplete', 'incomplete_expired')),
    current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancel_at TIMESTAMP WITH TIME ZONE,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
    stripe_subscription_id TEXT UNIQUE,
    stripe_customer_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for vendor_subscriptions
CREATE INDEX IF NOT EXISTS idx_vendor_subscriptions_vendor_id ON vendor_subscriptions(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_subscriptions_status ON vendor_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_vendor_subscriptions_stripe_subscription_id ON vendor_subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_vendor_subscriptions_current_period_end ON vendor_subscriptions(current_period_end);

-- Add comments
COMMENT ON TABLE subscription_plans IS 'Available subscription plans for vendors';
COMMENT ON TABLE vendor_subscriptions IS 'Active and historical subscriptions for vendors';


-- PART 3: Verify Data
-- ============================================

-- Count events by status (for verification)
-- Uncomment to see results:
-- SELECT status, COUNT(*) FROM events GROUP BY status;

-- Count subscription plans (should be 4)
-- Uncomment to see results:
-- SELECT id, name, price FROM subscription_plans ORDER BY price;


-- ============================================
-- DONE!
-- ============================================
-- After running this script:
-- 1. Restart your Flutter app
-- 2. Try creating a new event
-- 3. Check Profile → Subscription (should see 4 plans)
-- 4. Events should display in Active tab
-- ============================================
