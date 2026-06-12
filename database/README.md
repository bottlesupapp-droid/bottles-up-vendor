# Database Documentation

**Last Audit:** 2026-06-12
**Status:** 🔴 CRITICAL ISSUES FOUND - See [SECURITY_ISSUES.md](SECURITY_ISSUES.md)

---

## 📁 What's in This Folder

| File/Folder | Purpose | Read This If... |
|-------------|---------|-----------------|
| **[ACTION_PLAN.md](ACTION_PLAN.md)** 🎯 | Step-by-step guide to fix issues | You need to fix the database NOW |
| **[SECURITY_ISSUES.md](SECURITY_ISSUES.md)** 🔴 | Critical security vulnerabilities | You're deploying to production |
| **[verify_rls.sql](verify_rls.sql)** 🔍 | SQL script to audit RLS | You want to check security status |
| **[MIGRATION_CONSOLIDATION_REPORT.md](MIGRATION_CONSOLIDATION_REPORT.md)** 📊 | Migration analysis | You're confused about migrations |
| **[archive/](archive/)** 🗄️ | Obsolete migration files | You're looking for old fix scripts |
| **[migrations/](migrations/)** 📝 | Active migration files | You need to understand current schema |

---

## ⚡ QUICK START

### If you're deploying to production:

```bash
# 1. Check current security status
# Open Supabase SQL Editor and run:
cat verify_rls.sql

# 2. Read the critical issues
cat SECURITY_ISSUES.md

# 3. Follow the action plan
cat ACTION_PLAN.md
```

### If you just want to understand the database:

```bash
# 1. See all tables and their purpose
cat MIGRATION_CONSOLIDATION_REPORT.md

# 2. Check which migrations exist
ls migrations/
```

---

## 🔴 CRITICAL FINDINGS

During the Supabase audit on 2026-06-12, we found:

1. **Financial data exposed** - Stripe accounts, payouts accessible to all users
2. **Venue boosts vulnerable** - ANY authenticated user can read/write
3. **Onboarding tables locked** - RLS enabled but no policies (tables invisible)
4. **Missing RLS** - Team and ticket tables have no access controls
5. **Schema inconsistencies** - Multiple duplicate/conflicting migration files

**Result:** Database is **NOT production-ready** until these are fixed.

See [SECURITY_ISSUES.md](SECURITY_ISSUES.md) for full details.

---

## 📋 PRIORITY ACTIONS

### 🔥 IMMEDIATE (Do Today)

1. Read [SECURITY_ISSUES.md](SECURITY_ISSUES.md) - **10 minutes**
2. Run [verify_rls.sql](verify_rls.sql) in Supabase - **5 minutes**
3. Follow **IMMEDIATE ACTIONS** in [ACTION_PLAN.md](ACTION_PLAN.md) - **4 hours**
4. Re-run verify_rls.sql to confirm fixes - **5 minutes**

### 📅 SHORT TERM (This Week)

1. Fix table naming issues (bookings vs events_bookings)
2. Create missing tables referenced by app
3. Test all app functionality with multiple users

### 🗓️ MEDIUM TERM (Next 2 Weeks)

1. Consolidate migrations into clean numbered set
2. Create comprehensive RLS policy documentation
3. Set up security monitoring

---

## 🧭 NAVIGATION GUIDE

### I want to...

**Fix critical security issues NOW:**
→ Go to [ACTION_PLAN.md](ACTION_PLAN.md) → **IMMEDIATE ACTIONS** section

**Understand what's wrong:**
→ Read [SECURITY_ISSUES.md](SECURITY_ISSUES.md) → **Executive Summary**

**Check current database security:**
→ Run [verify_rls.sql](verify_rls.sql) in Supabase SQL Editor

**Understand migration history:**
→ Read [MIGRATION_CONSOLIDATION_REPORT.md](MIGRATION_CONSOLIDATION_REPORT.md)

**Find old fix scripts:**
→ Look in [archive/](archive/) folder (don't run them!)

**Create a new migration:**
→ See [migrations/](migrations/) folder for examples

---

## 📊 AUDIT RESULTS SUMMARY

### Tables Audited: 40+

| Category | Status | Count |
|----------|--------|-------|
| ✅ Properly secured | Good | 2 (vendors, events*) |
| ⚠️  Has RLS but weak/broken policies | Needs fixing | 6 |
| 🔴 No RLS at all | CRITICAL | 12 |
| 📋 Needs verification | Unknown | 20 |

*events table has RLS but column name mismatches in policies

### Critical Security Gaps

- 💰 Financial tables (Stripe, payouts, subscriptions): **EXPOSED**
- 👤 User profiles (staff, promoter, organizer): **LOCKED (no policies)**
- 📊 Business data (team, tickets): **EXPOSED**
- 🏢 Venue data (boosts, requests): **WEAK ACCESS CONTROL**

---

## 🛠️ TOOLS PROVIDED

### 1. verify_rls.sql - Security Audit Script

**What it does:**
- Lists all tables and their RLS status
- Shows policy count for each table
- Flags critical security issues
- Checks storage bucket policies
- Provides recommendations

**How to use:**
```sql
-- Copy entire file contents
-- Paste into Supabase SQL Editor
-- Run (read-only, safe)
-- Review each section output
```

**Output sections:**
1. RLS enabled status (✅/❌ for each table)
2. Policy count (0 = problem!)
3. Detailed policy listing
4. 🔴 Critical issues (FIX THESE FIRST)
5. Storage bucket audit
6. Financial/user table specific checks
7. Overall recommendation

---

## 📝 MIGRATION HISTORY

### Current State (Fragmented)

- **Root folder:** 3 SQL files (base schema + fixes)
- **supabase/migrations/:** 6 files (003-006 + ad-hoc fixes)
- **database/migrations/:** 8 files (001-008)
- **Total:** 17 files across 3 locations ❌

### Archived Files (As of 2026-06-12)

Moved to [archive/](archive/):
- 00_diagnostic.sql
- 00_quick_fix.sql
- 01_actual_fix.sql
- 02_final_fix.sql
- fix_event_performance_view.sql
- FINAL_FIX_ALL_ISSUES.sql

These files contained duplicate/ad-hoc fixes. Functionality has been preserved in consolidated migrations (future).

### Recommended State (Future)

Single location with clean numbered migrations:
```
supabase/migrations/
├── 001_base_schema.sql
├── 002_add_event_fields.sql
├── 003_subscription_system.sql
├── ...
└── 014_fix_event_status.sql
```

See [MIGRATION_CONSOLIDATION_REPORT.md](MIGRATION_CONSOLIDATION_REPORT.md) for detailed plan.

---

## 🔗 RELATED DOCUMENTATION

### In This Repo

- [/CLAUDE.md](../CLAUDE.md) - Development commands and architecture
- [/supabase/migrations/](../supabase/migrations/) - Active migration files
- [/lib/shared/services/](../lib/shared/services/) - Dart code that uses these tables

### External Resources

- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Supabase Best Practices](https://supabase.com/docs/guides/database/best-practices)

---

## 🆘 TROUBLESHOOTING

### "Table doesn't exist" errors in app

**Cause:** Code references table that wasn't created
**Fix:** See [MIGRATION_CONSOLIDATION_REPORT.md](MIGRATION_CONSOLIDATION_REPORT.md) → **Tables Referenced But May Not Exist**

### "Row-level security policy violated" errors

**Cause:** RLS enabled but no policies allow access
**Fix:** Run [verify_rls.sql](verify_rls.sql) to find tables with RLS but no policies

### Users can see other users' data

**Cause:** Missing or incorrect RLS policies
**Fix:** See [SECURITY_ISSUES.md](SECURITY_ISSUES.md) → Critical Issues

### Onboarding screens don't save data

**Cause:** RLS policies blocking inserts
**Fix:** See [ACTION_PLAN.md](ACTION_PLAN.md) → Fix 3: Onboarding Profile Access

### Migration conflicts

**Cause:** Duplicate migrations in multiple folders
**Fix:** See [MIGRATION_CONSOLIDATION_REPORT.md](MIGRATION_CONSOLIDATION_REPORT.md) → Consolidation Plan

---

## 📧 QUESTIONS?

1. **About security issues:** See [SECURITY_ISSUES.md](SECURITY_ISSUES.md)
2. **About how to fix:** See [ACTION_PLAN.md](ACTION_PLAN.md)
3. **About migrations:** See [MIGRATION_CONSOLIDATION_REPORT.md](MIGRATION_CONSOLIDATION_REPORT.md)
4. **About RLS status:** Run [verify_rls.sql](verify_rls.sql)

---

**Created:** 2026-06-12
**Audit Status:** Complete
**Production Status:** 🔴 NOT READY (critical issues found)
**Next Step:** Read [ACTION_PLAN.md](ACTION_PLAN.md) and start fixing
