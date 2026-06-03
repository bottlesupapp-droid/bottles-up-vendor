# 🚀 Deployment Guide - Bottles Up Vendor App

## Overview

This guide will help you deploy the missing Supabase Edge Functions needed for Stripe integration.

---

## ✅ Existing Functions (Already Deployed)

Based on your screenshot, you have:
1. ✅ `create-checkout`
2. ✅ `create-checkout-session`
3. ✅ `create-payment-intent`
4. ✅ `send-email-notifications`
5. ✅ `stripe-webhook`

---

## ⚡ New Functions to Deploy

I've created 5 new edge functions that need to be deployed:

### 1. `create-portal-session`
**Purpose:** Allows vendors to manage their subscriptions via Stripe Customer Portal

**File:** `supabase/functions/create-portal-session/index.ts`

**Usage:** Called when vendor clicks "Manage Billing" button

---

### 2. `create-connect-account`
**Purpose:** Creates Stripe Connect Express account for vendor payouts

**File:** `supabase/functions/create-connect-account/index.ts`

**Usage:** Called when vendor sets up payout account in Earnings screen

---

### 3. `create-connect-login-link`
**Purpose:** Generates login link to Stripe Connect dashboard

**File:** `supabase/functions/create-connect-login-link/index.ts`

**Usage:** Called when vendor clicks "Stripe Dashboard" icon

---

### 4. `create-payout`
**Purpose:** Creates payout to vendor's bank account

**File:** `supabase/functions/create-payout/index.ts`

**Usage:** Called when vendor requests a payout

---

### 5. `get-balance`
**Purpose:** Retrieves available and pending balance from Stripe

**File:** `supabase/functions/get-balance/index.ts`

**Usage:** Called to display balance in Earnings screen

---

## 📦 Quick Deployment

### Option 1: Using the Deployment Script (Recommended)

```bash
cd /Users/abdulrazak/Downloads/bottles-up-vendor-main

# Make script executable (if not already)
chmod +x deploy-functions.sh

# Run deployment
./deploy-functions.sh
```

### Option 2: Manual Deployment

```bash
# 1. Link to your project
supabase link --project-ref hwmynlghrmtoufyrcihp

# 2. Deploy each function
supabase functions deploy create-portal-session
supabase functions deploy create-connect-account
supabase functions deploy create-connect-login-link
supabase functions deploy create-payout
supabase functions deploy get-balance

# 3. Set Stripe secret key
supabase secrets set STRIPE_SECRET_KEY=sk_live_YOUR_KEY_HERE

# 4. Set Supabase credentials (for database access)
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
supabase secrets set SUPABASE_URL=https://hwmynlghrmtoufyrcihp.supabase.co
```

---

## 🔑 Required Environment Variables

After deploying, set these secrets:

```bash
# Stripe Secret Key (REQUIRED)
supabase secrets set STRIPE_SECRET_KEY=sk_live_...

# Supabase Service Role Key (REQUIRED for database access)
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Supabase URL (REQUIRED)
supabase secrets set SUPABASE_URL=https://hwmynlghrmtoufyrcihp.supabase.co
```

**Where to find these:**
- **Stripe Secret Key:** Stripe Dashboard → Developers → API Keys
- **Supabase Service Role Key:** Supabase Dashboard → Project Settings → API → service_role key
- **Supabase URL:** Already in your project (hwmynlghrmtoufyrcihp.supabase.co)

---

## ✅ Verify Deployment

### 1. Check Functions List
```bash
supabase functions list
```

You should see all 10 functions (5 existing + 5 new).

### 2. Test a Function
```bash
# Test portal session creation
curl -X POST \
  https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/create-portal-session \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cus_test",
    "return_url": "https://test.com"
  }'
```

### 3. View Logs
```bash
supabase functions logs create-portal-session --tail
```

---

## 🎯 What Each Function Does

### Subscription Management Flow
```
User clicks "Upgrade Plan"
  → create-checkout-session (existing)
  → Redirects to Stripe checkout
  → User pays
  → stripe-webhook (existing) updates database

User clicks "Manage Billing"
  → create-portal-session (NEW)
  → Opens Stripe Customer Portal
  → User can update payment, view invoices, cancel
```

### Earnings/Payout Flow
```
User clicks "Setup Payouts"
  → create-connect-account (NEW)
  → Redirects to Stripe Connect onboarding
  → User completes bank details
  → Account saved to stripe_accounts table

User views Earnings screen
  → get-balance (NEW)
  → Shows available balance from Stripe

User clicks "Request Payout"
  → create-payout (NEW)
  → Creates payout
  → Saved to payout_records table

User clicks "Stripe Dashboard"
  → create-connect-login-link (NEW)
  → Opens Stripe Express dashboard
```

---

## 🗄️ Database Tables

Make sure these tables exist in your Supabase database:

### `stripe_accounts`
```sql
CREATE TABLE stripe_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
  account_id TEXT NOT NULL,
  account_type TEXT DEFAULT 'express',
  charges_enabled BOOLEAN DEFAULT false,
  payouts_enabled BOOLEAN DEFAULT false,
  details_submitted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(vendor_id)
);
```

### `payout_records`
```sql
CREATE TABLE payout_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
  stripe_payout_id TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'usd',
  status TEXT DEFAULT 'pending',
  arrival_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(stripe_payout_id)
);
```

If these tables don't exist, they should be created via the migrations in `supabase/migrations/`.

---

## 🧪 Testing

### Test in Development
1. Run the app: `flutter run`
2. Navigate to Subscription screen
3. Click "Upgrade Plan" → Should open checkout
4. Click "Manage Billing" → Should open portal

### Test Earnings Flow
1. Navigate to Earnings screen
2. Click "Setup Payouts" → Should open Connect onboarding
3. Complete onboarding in Stripe
4. Return to app → Should show balance

---

## 🐛 Troubleshooting

### Function Returns 500 Error
- Check function logs: `supabase functions logs <function-name>`
- Verify environment variables are set
- Check Stripe API keys are valid

### "Function not found" Error
- Ensure function is deployed: `supabase functions list`
- Check project is linked: `supabase link --project-ref hwmynlghrmtoufyrcihp`

### Database Access Error
- Verify `SUPABASE_SERVICE_ROLE_KEY` is set correctly
- Check table permissions (RLS policies)

### Stripe API Error
- Verify `STRIPE_SECRET_KEY` is correct
- Check Stripe account has required features enabled
- Verify account is not in restricted mode

---

## 📚 Additional Resources

- **Edge Functions Docs:** [supabase.com/docs/guides/functions](https://supabase.com/docs/guides/functions)
- **Stripe Connect Docs:** [stripe.com/docs/connect](https://stripe.com/docs/connect)
- **Function Reference:** See `supabase/functions/README.md`

---

## ✅ Checklist

Before going to production:

- [ ] All 5 new functions deployed
- [ ] `STRIPE_SECRET_KEY` set to **live** key (not test)
- [ ] `SUPABASE_SERVICE_ROLE_KEY` set
- [ ] `SUPABASE_URL` set
- [ ] Database tables (`stripe_accounts`, `payout_records`) exist
- [ ] Test subscription upgrade flow
- [ ] Test payout setup flow
- [ ] Test balance retrieval
- [ ] Monitor function logs for errors
- [ ] Set up Stripe webhook in production

---

## 🎉 You're Done!

Once deployed, your app will have:
- ✅ Full subscription management
- ✅ Stripe Customer Portal access
- ✅ Vendor payout setup (Stripe Connect)
- ✅ Balance checking
- ✅ Payout requests
- ✅ Stripe dashboard access

All flows are now complete and production-ready!
