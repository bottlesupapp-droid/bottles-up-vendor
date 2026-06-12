# Security Guidelines

## Environment Variables & Secrets Management

This application uses multiple layers of secret management to ensure security in production.

### Client-Side Configuration (Flutter App)

**File**: `env.json` (gitignored)

The Flutter app requires Supabase credentials passed via `--dart-define-from-file`:

```json
{
  "SUPABASE_URL": "https://your-project-ref.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key-here"
}
```

**How to use**:
```bash
flutter run --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
```

### Server-Side Secrets (Supabase Edge Functions)

**Configured via Supabase CLI**:

```bash
# Set Stripe secret key (used by all payment-related edge functions)
supabase secrets set STRIPE_SECRET_KEY=sk_live_...

# View configured secrets (hashed values only)
supabase secrets list
```

**Required secrets**:
- `STRIPE_SECRET_KEY` - Your Stripe secret key for API calls
- `SUPABASE_SERVICE_ROLE_KEY` - Auto-configured by Supabase
- `SUPABASE_URL` - Auto-configured by Supabase

## Security Best Practices

### ✅ DO

1. **Use env.example.json as template**
   - Copy to `env.json` and fill with actual values
   - Never commit `env.json` to git

2. **Keep secrets in Supabase dashboard or CLI**
   - Set via `supabase secrets set KEY=value`
   - Secrets are encrypted at rest

3. **Use Row Level Security (RLS)**
   - All Supabase tables should have RLS policies
   - Users can only access their own data

4. **Use Edge Functions for sensitive operations**
   - Never expose Stripe secret keys in client code
   - All payment operations go through edge functions

5. **Rotate keys regularly**
   - Update Stripe keys periodically
   - Regenerate Supabase anon keys if compromised

### ❌ DON'T

1. **Never commit secrets to git**
   - No API keys in source code
   - No credentials in config files
   - Use .gitignore properly

2. **Never use production keys in development**
   - Use Stripe test keys (sk_test_...)
   - Use separate Supabase projects for dev/prod

3. **Never log secrets**
   - Don't print API keys to console
   - Sanitize error messages

4. **Never expose service role key to client**
   - Service role bypasses RLS
   - Only use in edge functions

## File Security Checklist

- [ ] `env.json` - Gitignored, contains Supabase URL and anon key
- [ ] `env.example.json` - Committed, contains placeholder values only
- [ ] `firebase.env` - Gitignored, contains Firebase config
- [ ] `firebase.env.example` - Committed, contains placeholder values only
- [ ] Supabase secrets - Set via CLI, never committed
- [ ] `.gitignore` - Updated to exclude all sensitive files

## What's Safe to Commit

✅ **Public/Safe**:
- `SUPABASE_URL` - Public URL, safe to expose
- `SUPABASE_ANON_KEY` - Public anon key, safe to expose (protected by RLS)
- Firebase project ID - Public identifier
- App configuration (ports, regions, etc.)

⚠️ **Keep Secret**:
- `STRIPE_SECRET_KEY` - Never expose (use edge functions)
- Supabase service role key - Never expose to client
- Database passwords - Never expose
- API keys with write access - Keep server-side only

## Incident Response

If a secret is accidentally committed:

1. **Immediately rotate the compromised key**
   - Generate new Stripe secret key
   - Regenerate Supabase keys if needed

2. **Remove from git history**
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/secret" \
     --prune-empty --tag-name-filter cat -- --all
   ```

3. **Force push to remote** (if necessary)
   ```bash
   git push origin --force --all
   ```

4. **Update all environments** with new keys

## Verification Commands

```bash
# Check for accidentally committed secrets
git log -p | grep -i "sk_live_\|sk_test_\|eyJ"

# Verify .gitignore is working
git status --ignored

# Check for sensitive file patterns
grep -r "sk_live" lib/ src/
grep -r "service_role" lib/ src/

# Verify edge function secrets are set
supabase secrets list
```

## Production Deployment Checklist

- [ ] All `env.json` values use production Supabase credentials
- [ ] Stripe secret key is set to `sk_live_...` (not test key)
- [ ] Row Level Security policies enabled on all tables
- [ ] Edge functions deployed and tested
- [ ] No hardcoded secrets in source code
- [ ] `.gitignore` includes all sensitive files
- [ ] Firebase config uses production project
- [ ] SSL/TLS enabled for all API calls
- [ ] Error messages don't leak sensitive information

## Contact

If you discover a security vulnerability, please email: security@bottlesup.app
