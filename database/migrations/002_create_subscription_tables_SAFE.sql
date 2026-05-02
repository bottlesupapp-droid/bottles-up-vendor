-- Migration: Create subscription management tables (SAFE VERSION)
-- Date: 2026-04-29
-- Description: Creates tables for subscription plans and vendor subscriptions
-- This version handles existing objects gracefully

-- Create subscription_plans table
CREATE TABLE IF NOT EXISTS subscription_plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    billing_period TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_period IN ('monthly', 'yearly')),
    max_events INTEGER NOT NULL DEFAULT -1, -- -1 means unlimited
    max_tickets_per_event INTEGER NOT NULL DEFAULT -1, -- -1 means unlimited
    has_analytics BOOLEAN NOT NULL DEFAULT false,
    has_custom_branding BOOLEAN NOT NULL DEFAULT false,
    has_priority_support BOOLEAN NOT NULL DEFAULT false,
    has_advanced_reporting BOOLEAN NOT NULL DEFAULT false,
    team_member_limit INTEGER NOT NULL DEFAULT 1, -- -1 means unlimited
    features JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_popular BOOLEAN NOT NULL DEFAULT false,
    stripe_product_id TEXT,
    stripe_price_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create vendor_subscriptions table
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

-- Insert predefined subscription plans (skip if already exist)
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
ON CONFLICT (id) DO NOTHING;

-- Create indexes (IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_vendor_subscriptions_vendor_id ON vendor_subscriptions(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_subscriptions_status ON vendor_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_vendor_subscriptions_stripe_subscription_id ON vendor_subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_vendor_subscriptions_current_period_end ON vendor_subscriptions(current_period_end);

-- Create trigger function (replace if exists)
CREATE OR REPLACE FUNCTION update_subscription_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate triggers to avoid "already exists" errors
DROP TRIGGER IF EXISTS trigger_vendor_subscriptions_updated_at ON vendor_subscriptions;
CREATE TRIGGER trigger_vendor_subscriptions_updated_at
    BEFORE UPDATE ON vendor_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_subscription_updated_at();

DROP TRIGGER IF EXISTS trigger_subscription_plans_updated_at ON subscription_plans;
CREATE TRIGGER trigger_subscription_plans_updated_at
    BEFORE UPDATE ON subscription_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_subscription_updated_at();

-- Add comments
COMMENT ON TABLE subscription_plans IS 'Available subscription plans for vendors';
COMMENT ON TABLE vendor_subscriptions IS 'Active and historical subscriptions for vendors';
COMMENT ON COLUMN vendor_subscriptions.cancel_at_period_end IS 'If true, subscription will be cancelled at the end of current period';
