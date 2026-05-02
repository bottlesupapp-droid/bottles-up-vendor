# ✅ Quick Validation Checklist

Print this and check off each item as you validate.

---

## 🗄️ DATABASE SETUP (30 minutes)

### Run Migrations
```bash
cd /Users/abdulrazak/Downloads/bottles-up-vendor-main
```

- [ ] Run migration 001: `supabase db execute --file database/migrations/001_add_event_fields.sql`
- [ ] Run migration 002: `supabase db execute --file database/migrations/002_create_subscription_tables.sql`
- [ ] Run migration 003: `supabase db execute --file database/migrations/003_create_stripe_accounts_table.sql`
- [ ] Run migration 004: `supabase db execute --file database/migrations/004_update_ticket_types_table.sql`
- [ ] Run migration 005: `supabase db execute --file database/migrations/005_update_event_team_members_table.sql`

### Verify Database
```sql
-- Copy/paste into Supabase SQL Editor
SELECT 'events' AS table_check, COUNT(*) FROM information_schema.columns WHERE table_name = 'events' AND column_name IN ('dress_code', 'min_age');
SELECT 'plans' AS table_check, COUNT(*) FROM subscription_plans;
SELECT 'tables' AS table_check, COUNT(*) FROM information_schema.tables WHERE table_name IN ('stripe_accounts', 'payout_records', 'ticket_types', 'event_team_members');
```

**Expected Results:**
- [ ] events: 2 (dress_code, min_age columns)
- [ ] plans: 4 (Free, Starter, Professional, Enterprise)
- [ ] tables: 4 (all new tables exist)

---

## 🔨 CODE VALIDATION (5 minutes)

```bash
flutter clean
flutter pub get
flutter analyze
```

- [ ] No errors from `flutter pub get`
- [ ] No issues from `flutter analyze`

---

## 📱 FEATURE TESTING (60 minutes)

### Test 1: Event Creation (10 min)
```bash
flutter run
```

- [ ] Navigate to Create Event
- [ ] Enter dress code: "Smart Casual"
- [ ] Enter min age: "21"
- [ ] Upload flyer image (see preview)
- [ ] Enter description
- [ ] Create event successfully
- [ ] Check database: `SELECT dress_code, min_age FROM events ORDER BY created_at DESC LIMIT 1;`

### Test 2: Ticket Tiers (15 min)

Navigate to event → Manage Ticket Tiers:
- [ ] Add "Early Bird" - $19.99 - 50 capacity
- [ ] Add "General" - $29.99 - 100 capacity
- [ ] Add "VIP" - $59.99 - 25 capacity
- [ ] Edit Early Bird price to $24.99
- [ ] Toggle General Admission to inactive
- [ ] Delete a test tier
- [ ] Verify summary shows correct totals
- [ ] Check database: `SELECT name, price FROM ticket_types WHERE event_id = 'YOUR_EVENT_ID';`

### Test 3: DJ/Lineup (15 min)

Navigate to event → Manage Lineup:
- [ ] Add DJ: "DJ Shadow" - djshadow@test.com
- [ ] Add DJ: "DJ Tiesto"
- [ ] Add Security: "John Doe"
- [ ] Add Bartender: "Jane Smith"
- [ ] Verify DJs in separate section
- [ ] Verify role icons/colors correct
- [ ] Edit DJ Shadow phone number
- [ ] Remove one team member
- [ ] Check database: `SELECT name, role FROM event_team_members WHERE event_id = 'YOUR_EVENT_ID';`

### Test 4: Subscriptions (10 min)

Navigate to Profile → Subscription:
- [ ] Screen loads, shows "Free" plan
- [ ] Usage stats display
- [ ] Tap "Upgrade Plan"
- [ ] See all 4 plans
- [ ] Starter marked as "POPULAR"
- [ ] Select plan shows Stripe message
- [ ] Features list displays
- [ ] Check database: `SELECT * FROM subscription_plans;`

### Test 5: Integration Test (10 min)

Complete end-to-end flow:
- [ ] Create new event with ALL fields
- [ ] Add 3 ticket tiers
- [ ] Add 2 DJs + 2 other team members
- [ ] Verify everything saved correctly
- [ ] Query database to verify complete data

---

## 🧪 VALIDATION QUERIES

Run these in Supabase SQL Editor to verify everything:

```sql
-- 1. Check event has new fields
SELECT id, name, dress_code, min_age, images
FROM events
WHERE dress_code IS NOT NULL OR min_age IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check subscription plans
SELECT id, name, price, max_events
FROM subscription_plans
ORDER BY price;

-- 3. Check ticket tiers exist
SELECT COUNT(*) as tier_count
FROM ticket_types;

-- 4. Check team members exist
SELECT COUNT(*) as team_count
FROM event_team_members;

-- 5. Check all tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
    'subscription_plans',
    'vendor_subscriptions',
    'stripe_accounts',
    'payout_records',
    'ticket_types',
    'event_team_members'
)
ORDER BY table_name;
```

**Expected:**
- [ ] At least 1 event with dress_code or min_age
- [ ] Exactly 4 subscription plans
- [ ] At least 1 ticket tier
- [ ] At least 1 team member
- [ ] All 6 tables exist

---

## 🎯 FINAL CHECKS

### Code Quality
- [ ] `flutter analyze` → No issues
- [ ] No runtime errors in console
- [ ] No memory leaks (check DevTools)

### Data Integrity
- [ ] All created data appears in database
- [ ] Foreign keys work correctly
- [ ] Constraints prevent invalid data
- [ ] Indexes improve query performance

### User Experience
- [ ] All screens load quickly (<2 seconds)
- [ ] Forms validate properly
- [ ] Error messages are clear
- [ ] Success messages appear
- [ ] Images upload and display correctly

---

## 📊 COMPLETION STATUS

**Database Setup:**        ☐ Not Started  ☐ In Progress  ☐ Complete
**Code Validation:**       ☐ Not Started  ☐ In Progress  ☐ Complete
**Feature Testing:**       ☐ Not Started  ☐ In Progress  ☐ Complete
**Validation Queries:**    ☐ Not Started  ☐ In Progress  ☐ Complete
**Final Checks:**          ☐ Not Started  ☐ In Progress  ☐ Complete

---

## 🚀 READY FOR PRODUCTION?

**YES** - All checkboxes marked ✅
- [ ] Deploy migrations to production
- [ ] Build release APK/IPA
- [ ] Submit to app stores

**NO** - Some items failed
- [ ] Document issues in VALIDATION_TESTING_GUIDE.md
- [ ] Fix issues
- [ ] Re-run failed tests

---

## 📞 QUICK REFERENCE

**Migration files:** `database/migrations/`
**New screens:**
- `lib/features/events/screens/manage_ticket_tiers_screen.dart`
- `lib/features/events/screens/manage_lineup_screen.dart`
- `lib/features/profile/screens/subscription_screen.dart`

**Full guide:** `VALIDATION_TESTING_GUIDE.md`
**Setup guide:** `IMPLEMENTATION_GUIDE.md`

**Support:** Check migration README for rollback scripts if needed

---

**Total Validation Time: ~90 minutes**

✅ **CURRENT STATUS: Ready to validate - Start with Database Setup above!**
