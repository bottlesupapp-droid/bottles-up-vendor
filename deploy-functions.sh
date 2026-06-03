#!/bin/bash

# Deployment script for Supabase Edge Functions
# Make sure you have Supabase CLI installed: npm install -g supabase

echo "🚀 Deploying Supabase Edge Functions..."
echo ""

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed!"
    echo "Install it with: npm install -g supabase"
    exit 1
fi

# Link to your project (you only need to do this once)
echo "📡 Linking to Supabase project..."
supabase link --project-ref hwmynlghrmtoufyrcihp

# Deploy the new functions
echo ""
echo "📦 Deploying create-portal-session..."
supabase functions deploy create-portal-session

echo ""
echo "📦 Deploying create-connect-account..."
supabase functions deploy create-connect-account

echo ""
echo "📦 Deploying create-connect-login-link..."
supabase functions deploy create-connect-login-link

echo ""
echo "📦 Deploying create-payout..."
supabase functions deploy create-payout

echo ""
echo "📦 Deploying get-balance..."
supabase functions deploy get-balance

echo ""
echo "✅ All functions deployed successfully!"
echo ""
echo "⚠️  IMPORTANT: Set your Stripe secret key:"
echo "supabase secrets set STRIPE_SECRET_KEY=sk_live_..."
echo ""
echo "📋 Deployed functions:"
echo "  - create-portal-session"
echo "  - create-connect-account"
echo "  - create-connect-login-link"
echo "  - create-payout"
echo "  - get-balance"
