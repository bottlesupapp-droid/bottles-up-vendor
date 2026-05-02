-- Migration: Create Stripe Connect accounts table
-- Date: 2026-04-29
-- Description: Creates table for Stripe Connect account management and payout tracking

-- Create stripe_accounts table
CREATE TABLE IF NOT EXISTS stripe_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL UNIQUE REFERENCES vendors(id) ON DELETE CASCADE,
    stripe_account_id TEXT UNIQUE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'restricted', 'enabled', 'disabled')),
    charges_enabled BOOLEAN NOT NULL DEFAULT false,
    payouts_enabled BOOLEAN NOT NULL DEFAULT false,
    details_submitted BOOLEAN NOT NULL DEFAULT false,
    requirements_currently_due JSONB DEFAULT '[]'::jsonb,
    requirements_eventually_due JSONB DEFAULT '[]'::jsonb,
    requirements_past_due JSONB DEFAULT '[]'::jsonb,
    account_type TEXT CHECK (account_type IN ('standard', 'express', 'custom')),
    country TEXT,
    currency TEXT DEFAULT 'usd',
    email TEXT,
    business_name TEXT,
    business_url TEXT,
    payout_schedule TEXT DEFAULT 'weekly' CHECK (payout_schedule IN ('daily', 'weekly', 'monthly', 'manual')),
    payout_delay_days INTEGER DEFAULT 2,
    onboarding_completed_at TIMESTAMP WITH TIME ZONE,
    last_payout_at TIMESTAMP WITH TIME ZONE,
    total_payouts DECIMAL(12, 2) DEFAULT 0,
    pending_balance DECIMAL(12, 2) DEFAULT 0,
    available_balance DECIMAL(12, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create payout_records table
CREATE TABLE IF NOT EXISTS payout_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    stripe_payout_id TEXT UNIQUE,
    amount DECIMAL(12, 2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'usd',
    status TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'failed', 'canceled')),
    arrival_date TIMESTAMP WITH TIME ZONE,
    bank_account TEXT, -- Last 4 digits
    failure_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_stripe_accounts_vendor_id ON stripe_accounts(vendor_id);
CREATE INDEX IF NOT EXISTS idx_stripe_accounts_stripe_account_id ON stripe_accounts(stripe_account_id);
CREATE INDEX IF NOT EXISTS idx_stripe_accounts_status ON stripe_accounts(status);
CREATE INDEX IF NOT EXISTS idx_payout_records_vendor_id ON payout_records(vendor_id);
CREATE INDEX IF NOT EXISTS idx_payout_records_status ON payout_records(status);
CREATE INDEX IF NOT EXISTS idx_payout_records_arrival_date ON payout_records(arrival_date);
CREATE INDEX IF NOT EXISTS idx_payout_records_created_at ON payout_records(created_at DESC);

-- Create trigger for updated_at
CREATE TRIGGER trigger_stripe_accounts_updated_at
    BEFORE UPDATE ON stripe_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_subscription_updated_at(); -- Reuse existing function

-- Add comments
COMMENT ON TABLE stripe_accounts IS 'Stripe Connect account information for vendor payouts';
COMMENT ON TABLE payout_records IS 'Historical record of all payouts to vendors';
COMMENT ON COLUMN stripe_accounts.requirements_currently_due IS 'Array of verification requirements that must be completed now';
COMMENT ON COLUMN stripe_accounts.requirements_past_due IS 'Array of overdue verification requirements';
COMMENT ON COLUMN payout_records.bank_account IS 'Last 4 digits of bank account for reference';
