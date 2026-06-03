# Supabase Edge Functions

This directory contains all Supabase Edge Functions for the Bottles Up Vendor app.

## Functions Overview

### Payment Functions

#### `create-checkout-session`
Creates a Stripe checkout session for subscription upgrades.

**Endpoint:** `https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/create-checkout-session`

**Request Body:**
```json
{
  "vendor_id": "uuid",
  "plan_id": "starter|professional|enterprise",
  "success_url": "myapp://subscription/success",
  "cancel_url": "myapp://subscription/cancel"
}
```

**Response:**
```json
{
  "url": "https://checkout.stripe.com/..."
}
```

---

#### `create-portal-session`
Creates a Stripe Customer Portal session for managing subscriptions.

**Endpoint:** `https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/create-portal-session`

**Request Body:**
```json
{
  "customer_id": "cus_...",
  "return_url": "myapp://subscription"
}
```

**Response:**
```json
{
  "url": "https://billing.stripe.com/..."
}
```

---

### Payout Functions

#### `create-connect-account`
Creates a Stripe Connect Express account for vendor payouts.

**Endpoint:** `https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/create-connect-account`

**Request Body:**
```json
{
  "vendor_id": "uuid",
  "email": "vendor@example.com",
  "business_name": "Vendor Business Name",
  "return_url": "myapp://earnings/return",
  "refresh_url": "myapp://earnings/refresh"
}
```

**Response:**
```json
{
  "account_id": "acct_...",
  "url": "https://connect.stripe.com/..."
}
```

**Side Effects:**
- Creates entry in `stripe_accounts` table

---

#### `create-connect-login-link`
Creates a login link to Stripe Connect Express dashboard.

**Endpoint:** `https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/create-connect-login-link`

**Request Body:**
```json
{
  "account_id": "acct_..."
}
```

**Response:**
```json
{
  "url": "https://connect.stripe.com/express/..."
}
```

---

#### `create-payout`
Creates a payout to vendor's connected bank account.

**Endpoint:** `https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/create-payout`

**Request Body:**
```json
{
  "vendor_id": "uuid",
  "account_id": "acct_...",
  "amount": 5000,
  "currency": "usd"
}
```

**Response:**
```json
{
  "payout_id": "po_...",
  "amount": 5000,
  "status": "pending",
  "arrival_date": 1234567890
}
```

**Side Effects:**
- Creates entry in `payout_records` table

---

#### `get-balance`
Gets available and pending balance from Stripe Connect account.

**Endpoint:** `https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/get-balance`

**Request Body:**
```json
{
  "account_id": "acct_..."
}
```

**Response:**
```json
{
  "available": 5000,
  "pending": 2500,
  "currency": "usd"
}
```

---

## Deployment

### Prerequisites
1. Install Supabase CLI:
   ```bash
   npm install -g supabase
   ```

2. Login to Supabase:
   ```bash
   supabase login
   ```

### Deploy All Functions

Run the deployment script:
```bash
./deploy-functions.sh
```

Or deploy individually:
```bash
supabase functions deploy create-portal-session
supabase functions deploy create-connect-account
supabase functions deploy create-connect-login-link
supabase functions deploy create-payout
supabase functions deploy get-balance
```

### Set Environment Variables

Set your Stripe secret key:
```bash
supabase secrets set STRIPE_SECRET_KEY=sk_live_...
```

Set Supabase service role key (for database access):
```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...
```

Set Supabase URL:
```bash
supabase secrets set SUPABASE_URL=https://hwmynlghrmtoufyrcihp.supabase.co
```

### View Secrets
```bash
supabase secrets list
```

---

## Testing Functions

### Using curl

Test portal session:
```bash
curl -X POST \
  https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/create-portal-session \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cus_...",
    "return_url": "https://yourapp.com/return"
  }'
```

Test connect account:
```bash
curl -X POST \
  https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/create-connect-account \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "vendor_id": "uuid",
    "email": "test@example.com",
    "business_name": "Test Business",
    "return_url": "https://yourapp.com/return",
    "refresh_url": "https://yourapp.com/refresh"
  }'
```

---

## Error Handling

All functions return errors in this format:
```json
{
  "error": "Error message here"
}
```

HTTP status codes:
- `200` - Success
- `400` - Bad request (missing parameters, validation error)
- `500` - Server error

---

## Database Tables Used

### `stripe_accounts`
Stores vendor Stripe Connect account information.

**Columns:**
- `id` - Primary key
- `vendor_id` - FK to vendors table
- `account_id` - Stripe account ID
- `account_type` - Account type (express)
- `charges_enabled` - Boolean
- `payouts_enabled` - Boolean
- `details_submitted` - Boolean
- `created_at` - Timestamp
- `updated_at` - Timestamp

### `payout_records`
Stores payout history.

**Columns:**
- `id` - Primary key
- `vendor_id` - FK to vendors table
- `stripe_payout_id` - Stripe payout ID
- `amount` - Amount in dollars
- `currency` - Currency code
- `status` - Status (pending, paid, failed)
- `arrival_date` - Expected arrival date
- `created_at` - Timestamp

---

## Security Notes

1. All functions validate required parameters
2. CORS is configured for all origins (adjust for production)
3. Stripe API keys are stored as secrets
4. Functions use Supabase service role key for database access
5. Consider adding rate limiting for production

---

## Monitoring

View function logs:
```bash
supabase functions logs create-portal-session
supabase functions logs create-connect-account
```

View all function logs:
```bash
supabase functions logs
```

---

## Support

For issues with:
- **Edge Functions**: Check Supabase logs
- **Stripe Integration**: Check Stripe dashboard logs
- **Database**: Check Supabase database logs
