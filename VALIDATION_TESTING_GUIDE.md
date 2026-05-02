# 🧪 Complete Validation & Testing Guide

This guide provides step-by-step instructions to validate and test all 14 implemented features.

---

## 📋 **Pre-Validation Checklist**

Before testing, ensure:
- [ ] Flutter environment is set up (`flutter doctor`)
- [ ] All dependencies are installed (`flutter pub get`)
- [ ] Supabase project is configured
- [ ] Database migrations are ready to run

---

## 🗄️ **STEP 1: Database Migration Validation**

### 1.1 Connect to Your Database

**Option A: Using Supabase Dashboard**
```
1. Go to https://app.supabase.com
2. Select your project
3. Navigate to SQL Editor
```

**Option B: Using Supabase CLI**
```bash
# Install Supabase CLI if not installed
brew install supabase/tap/supabase  # macOS
# or
npm install -g supabase              # npm

# Login
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF
```

### 1.2 Run Migrations in Order

Execute each migration file one by one:

```bash
# Migration 1: Event Fields
supabase db execute --file database/migrations/001_add_event_fields.sql

# Expected output: Migration completed successfully
# Verify:
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'events'
AND column_name IN ('dress_code', 'min_age');

# Should return 2 rows:
# dress_code | text
# min_age    | integer
```

```bash
# Migration 2: Subscription Tables
supabase db execute --file database/migrations/002_create_subscription_tables.sql

# Verify:
SELECT id, name, price FROM subscription_plans ORDER BY price;

# Should return 4 rows:
# free         | Free          | 0.00
# starter      | Starter       | 29.99
# professional | Professional  | 79.99
# enterprise   | Enterprise    | 199.99
```

```bash
# Migration 3: Stripe Accounts
supabase db execute --file database/migrations/003_create_stripe_accounts_table.sql

# Verify:
SELECT table_name FROM information_schema.tables
WHERE table_name IN ('stripe_accounts', 'payout_records');

# Should return 2 rows
```

```bash
# Migration 4: Ticket Types
supabase db execute --file database/migrations/004_update_ticket_types_table.sql

# Verify:
SELECT table_name FROM information_schema.tables
WHERE table_name = 'ticket_types';

# Should return 1 row
```

```bash
# Migration 5: Event Team Members
supabase db execute --file database/migrations/005_update_event_team_members_table.sql

# Verify:
SELECT table_name FROM information_schema.tables
WHERE table_name = 'event_team_members';

# Should return 1 row
```

### 1.3 Verify All Indexes Are Created

```sql
-- Run this query to check all indexes
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN (
    'events',
    'subscription_plans',
    'vendor_subscriptions',
    'stripe_accounts',
    'payout_records',
    'ticket_types',
    'event_team_members'
)
ORDER BY tablename, indexname;

-- Expected: Multiple indexes per table
```

### 1.4 Verify Constraints Are Active

```sql
-- Check constraints
SELECT
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid::regclass::text IN (
    'events',
    'ticket_types',
    'vendor_subscriptions',
    'stripe_accounts'
)
ORDER BY table_name, constraint_name;

-- Expected: Check constraints on min_age, ticket capacities, etc.
```

### ✅ Migration Validation Checklist

- [ ] All 5 migrations executed without errors
- [ ] `events` table has `dress_code` and `min_age` columns
- [ ] 4 subscription plans inserted (Free, Starter, Professional, Enterprise)
- [ ] `stripe_accounts` and `payout_records` tables exist
- [ ] `ticket_types` table exists with constraints
- [ ] `event_team_members` table exists
- [ ] All indexes created successfully
- [ ] All constraints are active

---

## 🔨 **STEP 2: Code Compilation Validation**

### 2.1 Clean Build

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Analyze code for errors
flutter analyze

# Expected: No issues found!
```

### 2.2 Check for Import Errors

```bash
# Run a dry build to check for compile errors
flutter build apk --debug --dry-run

# Or for iOS
flutter build ios --debug --dry-run --no-codesign

# Expected: Build configuration completed successfully
```

### 2.3 Verify New Files Exist

```bash
# Check all new files are present
ls -la lib/features/events/screens/manage_ticket_tiers_screen.dart
ls -la lib/features/events/screens/manage_lineup_screen.dart
ls -la lib/features/profile/screens/subscription_screen.dart
ls -la lib/shared/models/subscription_plan.dart
ls -la lib/shared/models/stripe_account.dart
ls -la lib/shared/services/subscription_service.dart

# All should exist (no "No such file" errors)
```

### ✅ Compilation Validation Checklist

- [ ] `flutter clean` completed
- [ ] `flutter pub get` successful
- [ ] `flutter analyze` shows no errors
- [ ] Dry-run build successful
- [ ] All 6 new files exist

---

## 📱 **STEP 3: Feature Testing**

### 3.1 Test Feature 1-4: Event Creation with New Fields

**Start the app:**
```bash
flutter run
```

**Test Steps:**

1. **Navigate to Create Event Screen**
   - [ ] Open the app
   - [ ] Go to Events section
   - [ ] Tap "Create Event" button

2. **Test Dress Code Field**
   - [ ] Locate "Dress Code" input field
   - [ ] Enter value: "Smart Casual"
   - [ ] Verify text is accepted
   - [ ] Clear field (should allow empty)

3. **Test Minimum Age Field**
   - [ ] Locate "Minimum Age" input field
   - [ ] Enter value: "18"
   - [ ] Try entering "150" (should show validation error)
   - [ ] Try entering "-5" (should show validation error)
   - [ ] Enter valid value: "21"
   - [ ] Clear field (should allow empty)

4. **Test Flyer Upload**
   - [ ] Tap "Upload Flyer" button
   - [ ] Select image from gallery
   - [ ] Verify image preview appears
   - [ ] Verify "Change Flyer" button appears
   - [ ] Tap "Remove Flyer" button
   - [ ] Verify preview is removed

5. **Test Description Field**
   - [ ] Locate "Description" field
   - [ ] Enter multi-line text
   - [ ] Verify text wraps correctly

6. **Submit Event**
   - [ ] Fill all required fields
   - [ ] Add dress code: "Formal"
   - [ ] Add min age: "21"
   - [ ] Upload flyer image
   - [ ] Add description
   - [ ] Tap "Create Event"
   - [ ] Wait for success message

7. **Verify in Database**
```sql
-- Check the created event
SELECT
    id,
    name,
    dress_code,
    min_age,
    description,
    images
FROM events
ORDER BY created_at DESC
LIMIT 1;

-- Expected: Your event with dress_code = 'Formal', min_age = 21
```

### ✅ Event Creation Checklist

- [ ] Create Event screen loads
- [ ] Dress code field accepts input
- [ ] Min age validates correctly (0-100)
- [ ] Flyer upload works (select, preview, remove)
- [ ] Description field works
- [ ] Event creates successfully
- [ ] Database contains dress_code and min_age values

---

### 3.2 Test Feature 9: Ticket Tier Management

**Test Steps:**

1. **Navigate to Ticket Tiers Screen**
   ```dart
   // For now, navigate programmatically or add a button
   // In your event details screen, add:
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => ManageTicketTiersScreen(
         eventId: 'YOUR_EVENT_ID',
         eventName: 'Test Event',
       ),
     ),
   );
   ```

2. **Test Add Ticket Tier**
   - [ ] Tap "Add Tier" button
   - [ ] Enter name: "Early Bird"
   - [ ] Enter description: "Limited time offer"
   - [ ] Enter price: "19.99"
   - [ ] Enter capacity: "50"
   - [ ] Tap "Add"
   - [ ] Verify tier appears in list

3. **Test Multiple Tiers**
   - [ ] Add tier: "General Admission" - $29.99 - 100 capacity
   - [ ] Add tier: "VIP" - $59.99 - 25 capacity
   - [ ] Verify all 3 tiers display correctly

4. **Test Edit Tier**
   - [ ] Tap menu (•••) on Early Bird tier
   - [ ] Select "Edit"
   - [ ] Change price to "24.99"
   - [ ] Change capacity to "75"
   - [ ] Save
   - [ ] Verify changes appear

5. **Test Tier Validation**
   - [ ] Edit VIP tier
   - [ ] Try to set capacity to "-10" (should fail)
   - [ ] Try to set price to "-5" (should fail)
   - [ ] Verify validation messages

6. **Test Toggle Active/Inactive**
   - [ ] Tap menu on General Admission
   - [ ] Select "Deactivate"
   - [ ] Verify status changes to "Inactive"
   - [ ] Tap menu → "Activate"
   - [ ] Verify status returns to active

7. **Test Delete Tier**
   - [ ] Add a new tier "Test Tier"
   - [ ] Tap menu → "Delete"
   - [ ] Confirm deletion
   - [ ] Verify tier is removed

8. **Test Sales Summary**
   - [ ] Verify summary card shows:
     - Total Capacity
     - Sold (should be 0)
     - Available
     - Revenue (should be $0.00)

9. **Verify in Database**
```sql
-- Check ticket tiers
SELECT
    name,
    price,
    capacity,
    sold_count,
    is_active
FROM ticket_types
WHERE event_id = 'YOUR_EVENT_ID'
ORDER BY created_at;

-- Expected: All 3 tiers (Early Bird, General, VIP)
```

### ✅ Ticket Tier Checklist

- [ ] Ticket tier screen loads
- [ ] Can add new tier
- [ ] Can add multiple tiers
- [ ] Can edit existing tier
- [ ] Price/capacity validation works
- [ ] Can toggle active/inactive
- [ ] Can delete tier (with no sales)
- [ ] Summary displays correctly
- [ ] Database records all tiers

---

### 3.3 Test Feature 6: DJ/Lineup Management

**Test Steps:**

1. **Navigate to Lineup Screen**
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => ManageLineupScreen(
         eventId: 'YOUR_EVENT_ID',
         eventName: 'Test Event',
       ),
     ),
   );
   ```

2. **Test Add DJ**
   - [ ] Tap "Add Team Member" (+ icon)
   - [ ] Enter name: "DJ Shadow"
   - [ ] Select role: "DJ"
   - [ ] Enter email: "djshadow@example.com"
   - [ ] Enter phone: "+1 555-0100"
   - [ ] Tap "Add"
   - [ ] Verify DJ appears in "DJs & Performers" section
   - [ ] Verify purple music icon displays

3. **Test Add Multiple DJs**
   - [ ] Add DJ: "DJ Tiesto"
   - [ ] Add DJ: "DJ Marshmello"
   - [ ] Verify count shows "DJs & Performers (3)"

4. **Test Add Other Team Members**
   - [ ] Add Security: "John Doe" - security@example.com
   - [ ] Add Bartender: "Jane Smith" - jane@bar.com
   - [ ] Add Host: "Mike Host"
   - [ ] Verify they appear in "Other Team Members" section
   - [ ] Verify different icons for each role

5. **Test Role Icons & Colors**
   - [ ] DJ: Purple music note icon
   - [ ] Security: Orange shield icon
   - [ ] Bartender: Teal beer icon
   - [ ] Host: Pink megaphone icon
   - [ ] Verify colors match roles

6. **Test Edit Team Member**
   - [ ] Tap menu on "DJ Shadow"
   - [ ] Select "Edit"
   - [ ] Change phone to "+1 555-0200"
   - [ ] Save
   - [ ] Verify updated

7. **Test Email Validation**
   - [ ] Edit a team member
   - [ ] Enter invalid email: "notanemail"
   - [ ] Try to save
   - [ ] Verify validation error appears

8. **Test Remove Team Member**
   - [ ] Tap menu on "Mike Host"
   - [ ] Select "Remove"
   - [ ] Confirm
   - [ ] Verify removed from list

9. **Test Empty State**
   - [ ] Remove all team members
   - [ ] Verify empty state message appears
   - [ ] Verify "Add Team Member" button shows

10. **Verify in Database**
```sql
-- Check team members
SELECT
    name,
    role,
    email,
    phone
FROM event_team_members
WHERE event_id = 'YOUR_EVENT_ID'
ORDER BY
    CASE role
        WHEN 'DJ' THEN 1
        ELSE 2
    END,
    created_at;

-- Expected: All added team members
```

### ✅ DJ/Lineup Management Checklist

- [ ] Lineup screen loads
- [ ] Can add DJ
- [ ] Can add multiple DJs
- [ ] Can add other team roles
- [ ] Role icons display correctly
- [ ] Role colors are correct
- [ ] Can edit team member
- [ ] Email validation works
- [ ] Can remove team member
- [ ] Empty state displays
- [ ] Database records all members

---

### 3.4 Test Feature 11: Subscription Management

**Test Steps:**

1. **Navigate to Subscription Screen**
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => const SubscriptionScreen(),
     ),
   );
   ```

2. **Test Current Plan Display**
   - [ ] Screen loads successfully
   - [ ] Current plan shows "Free" (default)
   - [ ] Plan description displays
   - [ ] Features list shows

3. **Test Usage Stats**
   - [ ] "Current Usage" section displays
   - [ ] Shows "Events This Month: X / 3"
   - [ ] Progress bar displays
   - [ ] Percentage is correct

4. **Test View Plans Dialog**
   - [ ] Tap "Upgrade Plan" button
   - [ ] Modal dialog opens
   - [ ] All 4 plans display:
     - Free ($0)
     - Starter ($29.99) - marked "POPULAR"
     - Professional ($79.99)
     - Enterprise ($199.99)

5. **Test Plan Cards**
   - [ ] Each plan shows price
   - [ ] Each plan shows billing period
   - [ ] Current plan marked "Current Plan"
   - [ ] Popular plan has orange badge

6. **Test Upgrade Attempt**
   - [ ] Select "Starter" plan
   - [ ] Tap "Select" button
   - [ ] Verify Stripe integration message appears
   - [ ] (Expected: "Stripe integration required" message)

7. **Test Plan Features**
   - [ ] View Free plan features (4 items)
   - [ ] View Starter plan features (6 items)
   - [ ] View Professional plan features (8 items)
   - [ ] View Enterprise plan features (10 items)
   - [ ] Verify checkmark icons display

8. **Test Subscription Service**
   ```dart
   // In a test file or debug console
   final service = SubscriptionService();

   // Test get plans
   final plans = await service.getAvailablePlans();
   print('Plans: ${plans.length}'); // Should be 4

   // Test get plan by ID
   final starter = await service.getPlanById('starter');
   print('Starter: ${starter?.price}'); // Should be 29.99

   // Test usage (replace with real vendor ID)
   final usage = await service.getSubscriptionUsage('vendor-id');
   print('Usage: $usage');
   ```

9. **Verify in Database**
```sql
-- Check subscription plans exist
SELECT id, name, price, max_events
FROM subscription_plans
ORDER BY price;

-- Expected: 4 plans
-- free | Free | 0 | 3
-- starter | Starter | 29.99 | 10
-- professional | Professional | 79.99 | 50
-- enterprise | Enterprise | 199.99 | -1
```

### ✅ Subscription Management Checklist

- [ ] Subscription screen loads
- [ ] Current plan displays (Free)
- [ ] Usage stats display correctly
- [ ] Can view all plans
- [ ] Plan cards render correctly
- [ ] Starter plan marked as popular
- [ ] Features list displays
- [ ] Upgrade shows Stripe message
- [ ] Database has all 4 plans
- [ ] Service methods work

---

### 3.5 Test Feature 13: Stripe Connect (Framework)

**Test Steps:**

1. **Test Stripe Account Model**
   ```dart
   // In a test file
   final account = StripeAccount(
     id: 'test-id',
     vendorId: 'vendor-123',
     status: StripeAccountStatus.pending,
     createdAt: DateTime.now(),
     updatedAt: DateTime.now(),
   );

   print('Is fully onboarded: ${account.isFullyOnboarded}'); // false
   print('Can accept payments: ${account.canAcceptPayments}'); // false

   // Test JSON serialization
   final json = account.toJson();
   final decoded = StripeAccount.fromJson(json);
   print('Serialization works: ${decoded.id == account.id}'); // true
   ```

2. **Verify Database Table**
```sql
-- Check stripe_accounts table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'stripe_accounts'
ORDER BY ordinal_position;

-- Expected: Multiple columns including:
-- stripe_account_id, status, charges_enabled, payouts_enabled, etc.
```

3. **Verify Payout Records Table**
```sql
-- Check payout_records table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'payout_records'
ORDER BY ordinal_position;

-- Expected: id, vendor_id, stripe_payout_id, amount, status, etc.
```

### ✅ Stripe Connect Checklist

- [ ] StripeAccount model compiles
- [ ] Model serialization works
- [ ] Helper methods work (isFullyOnboarded, etc.)
- [ ] stripe_accounts table exists
- [ ] payout_records table exists
- [ ] All columns present

---

## 🔍 **STEP 4: Integration Testing**

### 4.1 End-to-End Event Creation Flow

**Complete Flow Test:**

1. [ ] Launch app
2. [ ] Navigate to Events
3. [ ] Tap "Create Event"
4. [ ] Fill basic info (name, category, club, zone, date, time)
5. [ ] Add dress code: "Business Casual"
6. [ ] Add min age: "18"
7. [ ] Upload flyer image
8. [ ] Add description
9. [ ] Set pricing & capacity
10. [ ] Add terms & special instructions
11. [ ] Submit event
12. [ ] Verify success message
13. [ ] Navigate to event details
14. [ ] Go to "Manage Ticket Tiers"
15. [ ] Add 3 tiers (Early Bird, General, VIP)
16. [ ] Go back to event details
17. [ ] Go to "Manage Lineup"
18. [ ] Add 2 DJs
19. [ ] Add security and bartender
20. [ ] Verify all data persisted

**Verify Everything in Database:**
```sql
-- Get the complete event
SELECT * FROM events WHERE name = 'YOUR_TEST_EVENT_NAME';

-- Get ticket tiers
SELECT * FROM ticket_types WHERE event_id = 'YOUR_EVENT_ID';

-- Get team members
SELECT * FROM event_team_members WHERE event_id = 'YOUR_EVENT_ID';

-- All should return correct data
```

### ✅ Integration Test Checklist

- [ ] Complete event creation flow works
- [ ] All data persists correctly
- [ ] Can navigate between screens
- [ ] No crashes or errors
- [ ] Database has complete event data

---

## 📊 **STEP 5: Performance & Error Testing**

### 5.1 Test Error Handling

1. **Network Errors**
   - [ ] Turn off internet
   - [ ] Try to create event
   - [ ] Verify error message displays
   - [ ] Turn on internet
   - [ ] Verify recovery

2. **Validation Errors**
   - [ ] Try to create event without required fields
   - [ ] Verify validation messages
   - [ ] Enter invalid age (e.g., 200)
   - [ ] Verify error message

3. **Database Constraints**
   ```sql
   -- Try to violate constraints
   INSERT INTO ticket_types (event_id, name, price, capacity, sold_count)
   VALUES ('valid-event-id', 'Test', 10, 100, 150);

   -- Expected: Error (sold_count exceeds capacity)
   ```

### 5.2 Test Performance

1. **Large Data Sets**
   - [ ] Create event with 10 ticket tiers
   - [ ] Add 20 team members
   - [ ] Verify UI remains responsive

2. **Image Upload**
   - [ ] Upload large image (5MB+)
   - [ ] Verify compression/resize works
   - [ ] Check upload time

### ✅ Error & Performance Checklist

- [ ] Network errors handled gracefully
- [ ] Validation errors display correctly
- [ ] Database constraints work
- [ ] UI responsive with large datasets
- [ ] Image upload handles large files

---

## ✅ **FINAL VALIDATION CHECKLIST**

### Database
- [ ] All 5 migrations executed successfully
- [ ] All tables created
- [ ] All indexes created
- [ ] All constraints active
- [ ] Sample data inserted (subscription plans)

### Code
- [ ] No compilation errors
- [ ] `flutter analyze` passes
- [ ] All new files present
- [ ] No import errors

### Features (14/14)
- [ ] ✅ Feature 1: Ticket limits - Working
- [ ] ✅ Feature 2: Create event - Working
- [ ] ✅ Feature 3: Set dress code - Working
- [ ] ✅ Feature 4: Set description - Working
- [ ] ✅ Feature 5: Edit event - Backend ready
- [ ] ✅ Feature 6: Add DJs - Working
- [ ] ✅ Feature 7: Set age restriction - Working
- [ ] ✅ Feature 8: Staff roles & permissions - Working
- [ ] ✅ Feature 9: Ticket tier creation - Working
- [ ] ✅ Feature 10: Upload flyer - Working
- [ ] ✅ Feature 11: Subscription management - Working*
- [ ] ✅ Feature 12: Business registration - Existing
- [ ] ✅ Feature 13: Bank payout setup - Framework ready*
- [ ] ✅ Feature 14: Identity verification - Existing

*Requires Stripe API integration for full functionality

### Testing
- [ ] Event creation with all new fields tested
- [ ] Ticket tier management tested
- [ ] DJ/lineup management tested
- [ ] Subscription screen tested
- [ ] Database records verified
- [ ] Error handling tested
- [ ] Performance acceptable

---

## 🎯 **Success Criteria**

**You are DONE and ready for production when:**

✅ All 5 database migrations run without errors
✅ All 14 features validated and working
✅ No compilation or analysis errors
✅ All test scenarios pass
✅ Database contains correct data
✅ No crashes during normal usage

---

## 📝 **Testing Report Template**

After completing all tests, document results:

```markdown
# Testing Report - [Date]

## Database Migrations
- Migration 001: ✅ Success / ❌ Failed - [Notes]
- Migration 002: ✅ Success / ❌ Failed - [Notes]
- Migration 003: ✅ Success / ❌ Failed - [Notes]
- Migration 004: ✅ Success / ❌ Failed - [Notes]
- Migration 005: ✅ Success / ❌ Failed - [Notes]

## Feature Testing Results
1. Ticket limits: ✅ / ❌ - [Notes]
2. Create event: ✅ / ❌ - [Notes]
3. Set dress code: ✅ / ❌ - [Notes]
4. Set description: ✅ / ❌ - [Notes]
5. Edit event: ✅ / ❌ - [Notes]
6. Add DJs: ✅ / ❌ - [Notes]
7. Set age restriction: ✅ / ❌ - [Notes]
8. Staff roles: ✅ / ❌ - [Notes]
9. Ticket tiers: ✅ / ❌ - [Notes]
10. Upload flyer: ✅ / ❌ - [Notes]
11. Subscriptions: ✅ / ❌ - [Notes]
12. Business registration: ✅ / ❌ - [Notes]
13. Bank payout: ✅ / ❌ - [Notes]
14. Identity verification: ✅ / ❌ - [Notes]

## Issues Found
- [List any issues]

## Overall Status
✅ READY FOR PRODUCTION / ⚠️ NEEDS FIXES / ❌ BLOCKED

## Next Steps
- [List next steps if any]
```

---

## 🚀 **Post-Validation: Production Deployment**

Once all tests pass:

1. **Deploy Database Migrations to Production**
   ```bash
   # Run migrations on production database
   supabase db execute --project-ref PROD_PROJECT_REF --file database/migrations/001_add_event_fields.sql
   # ... repeat for all migrations
   ```

2. **Build Production App**
   ```bash
   # Android
   flutter build appbundle --release

   # iOS
   flutter build ios --release
   ```

3. **Monitor First Users**
   - Watch error logs
   - Monitor database for issues
   - Track feature usage

---

**🎊 You're now ready to validate everything is working correctly! Start with Step 1 and work through each section systematically.**
