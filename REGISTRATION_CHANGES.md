# Registration Screen Updates - Summary

## Changes Made (2025-12-19)

### 1. Updated VendorUser Model ✅
**File:** `lib/shared/models/user_model.dart`

**Changed Fields:**
- ❌ Removed: `name`, `phoneNumber`, `profileImageUrl`, `isVerified`, `lastLoginAt`, `permissions`
- ✅ Added: `phone`, `logoUrl`, `stripeAccountId`, `onboardingCompleted`, `twoFaEnabled`, `updatedAt`

**New Schema (Aligned with PROJECT_PLAN.md):**
```dart
class VendorUser {
  final String id;
  final String email;
  final String? phone;
  final String? businessName;
  final String? logoUrl;
  final String? stripeAccountId;
  final bool onboardingCompleted;
  final bool twoFaEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String role; // venue_owner, organizer, promoter, staff
}
```

**Helper Getters Added:**
```dart
bool get isVenueOwner => role == 'venue_owner';
bool get isOrganizer => role == 'organizer';
bool get isPromoter => role == 'promoter';
bool get isStaff => role == 'staff';
```

---

### 2. Updated Register Screen ✅
**File:** `lib/features/auth/screens/register_screen.dart`

#### 2.1 Role Selection Update
**Before:**
- Generic "Vendor Type" dropdown
- Values: Organizers, Promoters, Bottle Girls, Venues, Other

**After:**
- Specific "Your Role" dropdown aligned with schema
- Values match database enum: `venue_owner`, `organizer`, `promoter`, `staff`
- Added descriptive text for each role
- Variable renamed: `_selectedVendorType` → `_selectedRole`

**New Role Options:**
1. **Venue Owner** - "I own or manage a venue/club"
2. **Event Organizer** - "I organize and host events"
3. **Promoter** - "I promote events and sell tickets"
4. **Staff** - "I work for a venue or event"

#### 2.2 Navigation Logic Update
**Smart Onboarding Redirect:**
```dart
// After successful registration
if (!vendorUser.onboardingCompleted) {
  // Redirect to role-specific onboarding
  switch (vendorUser.role) {
    case 'venue_owner':
      context.go('/onboarding/venue');
    case 'organizer':
      context.go('/onboarding/organizer');
    case 'promoter':
      context.go('/onboarding/promoter');
    case 'staff':
      context.go('/onboarding/staff');
  }
} else {
  context.go('/dashboard');
}
```

---

## Next Steps (From IMPLEMENTATION_ROADMAP.md)

### ⚠️ Required Before Testing:

#### 1. Update Supabase Database Schema (Task 0.2)
**Migration needed:** `supabase/migrations/001_core_tables_part1.sql`

```sql
CREATE TABLE vendors (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  role TEXT NOT NULL CHECK (role IN ('venue_owner', 'organizer', 'promoter', 'staff')),
  business_name TEXT,
  logo_url TEXT,
  stripe_account_id TEXT,
  onboarding_completed BOOLEAN DEFAULT FALSE,
  two_fa_enabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own vendor data" ON vendors
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own vendor data" ON vendors
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own vendor data" ON vendors
  FOR INSERT WITH CHECK (auth.uid() = id);
```

#### 2. Update Auth Service (Task 1.1)
**File:** `lib/features/auth/services/supabase_auth_service.dart`

Update the `register` method to:
- Store `role` instead of `vendorType`
- Initialize `onboarding_completed` as `false`
- Set `created_at` and `updated_at` timestamps

#### 3. Create Onboarding Routes (Task 2.1)
**File:** `lib/core/router/app_router.dart`

Add routes:
```dart
GoRoute(
  path: '/onboarding/venue',
  builder: (context, state) => const VenueOnboardingScreen(),
),
GoRoute(
  path: '/onboarding/organizer',
  builder: (context, state) => const OrganizerOnboardingScreen(),
),
GoRoute(
  path: '/onboarding/promoter',
  builder: (context, state) => const PromoterOnboardingScreen(),
),
GoRoute(
  path: '/onboarding/staff',
  builder: (context, state) => const StaffOnboardingScreen(),
),
```

#### 4. Create Onboarding Screens (Task 1.3-1.6)
**Files to create:**
- `lib/features/auth/screens/onboarding/venue_onboarding_screen.dart`
- `lib/features/auth/screens/onboarding/organizer_onboarding_screen.dart`
- `lib/features/auth/screens/onboarding/promoter_onboarding_screen.dart`
- `lib/features/auth/screens/onboarding/staff_onboarding_screen.dart`

---

## Testing Checklist

### Before Testing:
- [ ] Run Supabase migration to create/update vendors table
- [ ] Update auth service to use new schema
- [ ] Create onboarding routes
- [ ] Create placeholder onboarding screens (can be simple for now)

### Registration Flow Tests:
- [ ] Register as Venue Owner → Should redirect to `/onboarding/venue`
- [ ] Register as Organizer → Should redirect to `/onboarding/organizer`
- [ ] Register as Promoter → Should redirect to `/onboarding/promoter`
- [ ] Register as Staff → Should redirect to `/onboarding/staff`
- [ ] Verify role is saved correctly in database
- [ ] Verify `onboarding_completed` is set to `false` on registration
- [ ] After completing onboarding, verify redirect to dashboard

### Field Validation Tests:
- [ ] Test role selection is required
- [ ] Test email validation
- [ ] Test phone number validation
- [ ] Test password strength requirements
- [ ] Test password confirmation matching

---

## Benefits of These Changes

✅ **Aligned with PROJECT_PLAN.md**
- Role types match the database schema exactly
- VendorUser model matches planned structure
- Onboarding flow follows the strategic roadmap

✅ **Better User Experience**
- Clear role descriptions help users choose correctly
- Role-specific onboarding provides relevant setup steps
- Prevents incomplete user profiles

✅ **Scalability**
- Easy to add new roles in the future
- Role-based permissions ready to implement
- Clean separation of onboarding flows

✅ **Security**
- Row Level Security ready to implement
- Role validation at database level
- Onboarding completion tracking

---

## Related Files Modified

1. `lib/shared/models/user_model.dart` - VendorUser model update
2. `lib/features/auth/screens/register_screen.dart` - Registration UI and logic
3. `REGISTRATION_CHANGES.md` (this file) - Documentation

---

## Commands to Run

After making database changes:
```bash
# Generate code for updated models
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Check for errors
flutter analyze
```

---

**Last Updated:** 2025-12-19
**Status:** ✅ Code Changes Complete - Database Migration Pending
**Next Task:** Task 0.2 - Create Supabase migration for vendors table
