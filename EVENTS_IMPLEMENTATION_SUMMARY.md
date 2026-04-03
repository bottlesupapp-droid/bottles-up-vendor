# Events Feature - Role-Based Implementation Summary

**Date:** 2025-12-19
**Status:** ✅ **Backend Complete** | ⏳ **Frontend Pending**

---

## 🎉 What's Been Completed

### 1. ✅ Event Model (`lib/shared/models/event_model.dart`)
- Complete rewrite to match Supabase database schema (34 fields)
- Status enum: `draft`, `published`, `upcoming`, `live`, `ongoing`, `completed`, `cancelled`
- Helper methods: `isDraft`, `isPast`, `occupancyRate`, `availableCapacity`
- Full JSON serialization/deserialization

### 2. ✅ Events Service (`lib/features/events/services/events_service.dart`)
Complete role-based business logic:

**Methods:**
- `getEventsByRole()` - Returns events based on user role with filtering
- `getEventById()` - Fetch single event with access verification
- `createEvent()` - Create new event (venue_owner & organizer only)
- `updateEvent()` - Update event with ownership check
- `deleteEvent()` - Delete event with ownership check
- `getEventStats()` - Dashboard statistics
- `_checkEventAccess()` - Internal access verification helper

**Role Logic:**
- **Venue Owner**: Events at their venues
- **Organizer**: Events they created
- **Promoter**: Events with their promo codes (read-only)
- **Staff**: Events with their shifts (read-only)

### 3. ✅ RLS Policies (`supabase/migrations/003_events_rls_policies.sql`)
Complete database security policies:

**7 Policies Created:**
1. Venue owners can view events at their venues (SELECT)
2. Organizers can view their events (SELECT)
3. Promoters can view events they promote (SELECT)
4. Staff can view events they're assigned to (SELECT)
5. Only venue owners and organizers can create events (INSERT)
6. Event creators and venue owners can update events (UPDATE)
7. Event creators and venue owners can delete events (DELETE)

**2 Helper Functions:**
- `can_manage_event(event_id)` - Returns boolean if user can manage event
- `get_event_access_level(event_id)` - Returns user's access level ('organizer', 'venue_owner', 'promoter', 'staff', 'none')

### 4. ✅ Documentation (`EVENTS_ROLE_BASED_IMPLEMENTATION.md`)
Comprehensive 400+ line document covering:
- Role-based access rules
- Database schema
- RLS policies
- Implementation checklist
- UI mockups
- Testing scenarios

---

## 🎯 What You See in the App (Screenshot)

Based on the screenshot you shared, the Events screen shows:
- ✅ Tab navigation: Active, Drafts, Past, Templates
- ✅ Empty state: "No Active Events"
- ✅ "Create Event" button
- ✅ Filter icon
- ✅ Bottom navigation

---

## 🚀 Next Steps (Implementation Order)

### **STEP 1: Apply RLS Policies to Database** ⚠️ **CRITICAL**

Go to Supabase Dashboard and run the migration:

```bash
# Option A: Via Supabase Dashboard
1. Open https://supabase.com/dashboard
2. Go to your project → SQL Editor
3. Copy contents of: supabase/migrations/003_events_rls_policies.sql
4. Paste and run
5. Verify "Query executed successfully"

# Option B: Via Supabase CLI (if installed)
cd "/Users/arbazkudekar/Downloads/flutter projects/bottles up/vendor app"
supabase db push
```

**Verification:**
```sql
-- Run this to verify policies are active:
SELECT tablename, policyname, roles, cmd
FROM pg_policies
WHERE tablename = 'events';
```

---

### **STEP 2: Update Events Provider**

**File:** `lib/features/events/providers/events_provider.dart`

Current code probably has mock data. Replace with:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/models/event_model.dart';
import '../services/events_service.dart';
import '../../auth/providers/supabase_auth_provider.dart';

part 'events_provider.g.dart';

// Events service provider
@riverpod
EventsService eventsService(EventsServiceRef ref) {
  return EventsService();
}

// Get events by status (role-based)
@riverpod
Future<List<EventModel>> eventsList(
  EventsListRef ref,
  String status,
) async {
  final user = ref.watch(currentVendorUserProvider);
  if (user == null) throw Exception('Not authenticated');

  final service = ref.watch(eventsServiceProvider);
  return service.getEventsByRole(user: user, status: status);
}

// Get single event by ID
@riverpod
Future<EventModel?> eventById(
  EventByIdRef ref,
  String eventId,
) async {
  final user = ref.watch(currentVendorUserProvider);
  if (user == null) throw Exception('Not authenticated');

  final service = ref.watch(eventsServiceProvider);
  return service.getEventById(eventId, user);
}

// Get event statistics
@riverpod
Future<Map<String, dynamic>> eventStats(EventStatsRef ref) async {
  final user = ref.watch(currentVendorUserProvider);
  if (user == null) throw Exception('Not authenticated');

  final service = ref.watch(eventsServiceProvider);
  return service.getEventStats(user);
}
```

Then run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

### **STEP 3: Update Events List Screen**

**File:** `lib/features/events/screens/events_list_screen.dart`

**Changes Needed:**

#### A. Update Tab Content to Use New Provider
```dart
Widget _buildTabContent(String tab) {
  final eventsAsync = ref.watch(eventsListProvider(tab));

  return eventsAsync.when(
    data: (events) => _buildEventsContent(events, tab),
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, stack) => _buildErrorState(error, tab),
  );
}
```

#### B. Role-Based "Create Event" Button
```dart
actions: [
  IconButton(
    icon: const Icon(Ionicons.filter_outline),
    onPressed: () => _showFilterSheet(context),
  ),
  // Only show for venue_owner and organizer
  Consumer(
    builder: (context, ref, _) {
      final user = ref.watch(currentVendorUserProvider);
      if (user != null && (user.isVenueOwner || user.isOrganizer)) {
        return IconButton(
          icon: const Icon(Ionicons.add_outline),
          onPressed: () => context.push('/events/create'),
          tooltip: 'Create Event',
        );
      }
      return const SizedBox.shrink();
    },
  ),
],
```

#### C. Role-Based Empty State Messages
```dart
Widget _buildEmptyState(String tab) {
  final user = ref.watch(currentVendorUserProvider);

  String title;
  String subtitle;
  bool showCreateButton;

  switch (tab) {
    case 'active':
      if (user?.isVenueOwner ?? false) {
        title = 'No Active Events at Your Venues';
        subtitle = 'Host an event at your venue to start managing bookings';
        showCreateButton = true;
      } else if (user?.isOrganizer ?? false) {
        title = 'No Active Events';
        subtitle = 'Create your first event to start managing bookings';
        showCreateButton = true;
      } else if (user?.isPromoter ?? false) {
        title = 'No Events to Promote';
        subtitle = 'You haven\'t been assigned to any events yet\nContact an organizer to get promo codes';
        showCreateButton = false;
      } else if (user?.isStaff ?? false) {
        title = 'No Upcoming Shifts';
        subtitle = 'You haven\'t been assigned to any events yet\nCheck with your manager for shift assignments';
        showCreateButton = false;
      } else {
        title = 'No Active Events';
        subtitle = 'Create your first event';
        showCreateButton = true;
      }
      break;

    // ... handle other tabs
  }

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Ionicons.calendar_outline, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center),
        if (showCreateButton) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.push('/events/create'),
            child: const Text('Create Event'),
          ),
        ],
      ],
    ),
  );
}
```

---

### **STEP 4: Test the Implementation**

**Test Plan:**

1. **As Venue Owner:**
   ```
   - Create a test venue in `clubs` table with your vendor ID as owner_id
   - Create an event for that club
   - Verify you can see it in Events list
   - Verify you can edit it
   ```

2. **As Organizer:**
   ```
   - Change your vendor role to 'organizer' in database
   - Create an event (user_id = your ID)
   - Verify you can see your events
   - Verify you cannot see other organizers' events
   ```

3. **As Promoter:**
   ```
   - Change role to 'promoter'
   - Create a promo code for an existing event
   - Verify you can see that event (read-only)
   - Verify "Create Event" button is hidden
   ```

4. **As Staff:**
   ```
   - Change role to 'staff'
   - Create a shift for an existing event
   - Verify you can see that event (read-only)
   - Verify "Create Event" button is hidden
   ```

---

## 📊 Database Setup Checklist

Before testing, ensure these tables exist and have data:

### ✅ Already Exist (Verified via Supabase MCP)
- `events` - 9 events
- `clubs` - Multiple venues
- `promo_codes` - For promoter testing
- `shifts` - For staff testing
- `vendors` - Your user account

### ⚠️ Need to Verify
Run this to check `clubs` table has `owner_id`:

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'clubs'
AND column_name = 'owner_id';
```

If `owner_id` doesn't exist, add it:

```sql
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);

-- Assign existing clubs to your vendor account for testing
UPDATE clubs
SET owner_id = 'your-vendor-id-here'
WHERE owner_id IS NULL
LIMIT 1;
```

---

## 🐛 Troubleshooting

### Issue: "No events showing up"

**Check 1: RLS Policies Applied?**
```sql
SELECT * FROM pg_policies WHERE tablename = 'events';
-- Should return 7 policies
```

**Check 2: User has correct role?**
```sql
SELECT id, email, role FROM vendors WHERE id = auth.uid();
```

**Check 3: Events exist in database?**
```sql
SELECT COUNT(*) FROM events;
```

**Check 4: User owns venues/events/promo codes/shifts?**
```sql
-- For venue owner:
SELECT c.id, c.name, e.name as event_name
FROM clubs c
LEFT JOIN events e ON e.club_id = c.id
WHERE c.owner_id = auth.uid();

-- For organizer:
SELECT id, name, status FROM events WHERE user_id = auth.uid();

-- For promoter:
SELECT e.name, pc.code
FROM events e
INNER JOIN promo_codes pc ON e.id = pc.event_id
WHERE pc.promoter_id = auth.uid();

-- For staff:
SELECT e.name, s.role, s.start_time
FROM events e
INNER JOIN shifts s ON e.id = s.event_id
WHERE s.staff_id = auth.uid();
```

---

## 📁 Files Reference

### Created Files:
1. ✅ `lib/shared/models/event_model.dart` - Event data model
2. ✅ `lib/features/events/services/events_service.dart` - Business logic
3. ✅ `supabase/migrations/003_events_rls_policies.sql` - Database security
4. ✅ `EVENTS_ROLE_BASED_IMPLEMENTATION.md` - Full documentation
5. ✅ `EVENTS_IMPLEMENTATION_SUMMARY.md` - This file

### Files to Modify:
1. ⏳ `lib/features/events/providers/events_provider.dart` - Connect to service
2. ⏳ `lib/features/events/screens/events_list_screen.dart` - UI updates
3. ⏳ `lib/features/events/screens/create_event_screen.dart` - Role checks
4. ⏳ `lib/features/events/screens/event_details_screen.dart` - Role-based actions

---

## 🎯 Success Criteria

You'll know it's working when:

- ✅ RLS policies are active (no errors when querying events)
- ✅ Venue owners see only their venue events
- ✅ Organizers see only their created events
- ✅ Promoters see only events they promote (read-only)
- ✅ Staff see only events with their shifts (read-only)
- ✅ "Create Event" button shows/hides based on role
- ✅ Empty states show role-appropriate messaging
- ✅ Event creation works for venue_owner and organizer
- ✅ Event creation blocked for promoter and staff

---

## 💡 Quick Start Command

To see current events in your database:

```bash
# Open Supabase SQL Editor and run:
SELECT
  e.id,
  e.name,
  e.status,
  e.event_date,
  e.user_id as organizer_id,
  e.club_id as venue_id,
  c.name as venue_name,
  e.current_bookings,
  e.revenue
FROM events e
LEFT JOIN clubs c ON e.club_id = c.id
ORDER BY e.event_date DESC;
```

---

**Ready to proceed? Start with STEP 1: Apply RLS Policies!**

After applying the policies, the Events screen will automatically filter based on the logged-in user's role. 🎉
