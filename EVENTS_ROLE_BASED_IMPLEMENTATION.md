# Events - Role-Based Implementation Plan

**Date:** 2025-12-19
**Status:** 🚧 IN PROGRESS

---

## 📋 Overview

This document outlines the complete role-based implementation for the Events feature in the Bottles Up Vendor App, aligned with the PROJECT_PLAN.md specifications.

---

## 🎯 Role-Based Access Rules

### 1. Venue Owner (`venue_owner`)
**Can See:**
- All events at venues they own
- Events at multiple venues if they own multiple venues

**Can Do:**
- Create events at their venues
- Edit events at their venues
- Delete events at their venues
- View all bookings, RSVPs, and orders for their venue events
- Manage bottle inventory for their venues
- Assign staff to events at their venues

**Example Query:**
```sql
SELECT * FROM events e
INNER JOIN clubs c ON e.club_id = c.id
WHERE c.owner_id = auth.uid()
```

---

### 2. Event Organizer (`organizer`)
**Can See:**
- Events they created (where user_id = their ID)
- Can create events at any venue (with venue permission)

**Can Do:**
- Create new events
- Edit their own events
- Delete their own events
- View bookings/RSVPs for their events
- Manage event details, pricing, capacity
- Create promo codes for their events

**Example Query:**
```sql
SELECT * FROM events
WHERE user_id = auth.uid()
```

---

### 3. Promoter (`promoter`)
**Can See:**
- Events they have promo codes for
- Events they're promoting

**Can Do (LIMITED):**
- View event details (READ ONLY)
- View their promo code performance
- See bookings made with their promo codes
- View earnings from their promotions

**Cannot Do:**
- Create/Edit/Delete events
- Manage inventory
- Access full financial data

**Example Query:**
```sql
SELECT e.* FROM events e
INNER JOIN promo_codes pc ON e.id = pc.event_id
WHERE pc.promoter_id = auth.uid()
```

---

### 4. Staff (`staff`)
**Can See:**
- Events they're assigned to via shifts
- Only events where they have an active shift

**Can Do (VERY LIMITED):**
- View event details (READ ONLY)
- View their shift schedule
- Mark bottle orders as delivered (if bottle service role)
- Check in guests (if door role)

**Cannot Do:**
- Create/Edit/Delete events
- View financial data
- Manage anything

**Example Query:**
```sql
SELECT e.* FROM events e
INNER JOIN shifts s ON e.id = s.event_id
WHERE s.staff_id = auth.uid()
```

---

## 🗄️ Database Schema (Already Exists)

### Events Table
```sql
events (
  id UUID PRIMARY KEY,
  name VARCHAR NOT NULL,
  description TEXT,
  category_id UUID REFERENCES categories(id),
  club_id UUID REFERENCES clubs(id),
  zone_id UUID REFERENCES zones(id),
  event_date DATE NOT NULL,
  start_time TIME,
  end_time TIME,
  ticket_price NUMERIC DEFAULT 0,
  max_capacity INT CHECK (max_capacity > 0),
  current_bookings INT DEFAULT 0,
  rsvp_count INT DEFAULT 0,
  table_booking_count INT DEFAULT 0,
  revenue NUMERIC DEFAULT 0,
  sales_count INT DEFAULT 0,
  images TEXT[],
  flyer_image_url TEXT,
  table_arrangement_image_url TEXT,
  status VARCHAR CHECK (status IN ('draft', 'published', 'upcoming', 'live', 'ongoing', 'completed', 'cancelled')),
  is_featured BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  is_private BOOLEAN DEFAULT FALSE,
  location_hidden BOOLEAN DEFAULT FALSE,
  invitation_code VARCHAR UNIQUE,
  city VARCHAR,
  dress_code TEXT,
  terms_and_conditions TEXT,
  special_instructions TEXT,
  user_id UUID NOT NULL REFERENCES auth.users(id), -- Event organizer
  template_id UUID REFERENCES event_templates(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
)
```

**Key Points:**
- `user_id` = Event organizer (creator)
- `club_id` = Venue where event happens (nullable for standalone events)
- `status` = Event lifecycle state

---

## 🔐 Row Level Security (RLS) Policies Needed

### Policy 1: Venue Owners Can View Their Venue Events
```sql
CREATE POLICY "Venue owners can view events at their venues"
ON events FOR SELECT
USING (
  club_id IN (
    SELECT id FROM clubs WHERE owner_id = auth.uid()
  )
);
```

### Policy 2: Organizers Can View Their Events
```sql
CREATE POLICY "Organizers can view their events"
ON events FOR SELECT
USING (user_id = auth.uid());
```

### Policy 3: Promoters Can View Events They Promote
```sql
CREATE POLICY "Promoters can view events they promote"
ON events FOR SELECT
USING (
  id IN (
    SELECT event_id FROM promo_codes WHERE promoter_id = auth.uid()
  )
);
```

### Policy 4: Staff Can View Events They're Assigned To
```sql
CREATE POLICY "Staff can view events they're assigned to"
ON events FOR SELECT
USING (
  id IN (
    SELECT event_id FROM shifts WHERE staff_id = auth.uid()
  )
);
```

### Policy 5: Only Venue Owners and Organizers Can Create Events
```sql
CREATE POLICY "Venue owners and organizers can create events"
ON events FOR INSERT
WITH CHECK (
  user_id = auth.uid() AND
  EXISTS (
    SELECT 1 FROM vendors
    WHERE id = auth.uid()
    AND role IN ('venue_owner', 'organizer')
  )
);
```

### Policy 6: Only Event Creators/Venue Owners Can Update Events
```sql
CREATE POLICY "Event creators and venue owners can update events"
ON events FOR UPDATE
USING (
  user_id = auth.uid() OR
  club_id IN (SELECT id FROM clubs WHERE owner_id = auth.uid())
);
```

### Policy 7: Only Event Creators/Venue Owners Can Delete Events
```sql
CREATE POLICY "Event creators and venue owners can delete events"
ON events FOR DELETE
USING (
  user_id = auth.uid() OR
  club_id IN (SELECT id FROM clubs WHERE owner_id = auth.uid())
);
```

---

## 📁 Files Created/Modified

### ✅ COMPLETED

#### 1. Event Model
**File:** `lib/shared/models/event_model.dart`

**Changes:**
- Complete rewrite to match Supabase schema
- Added all 30+ fields from database
- Added helper getters: `isDraft`, `isPublished`, `isPast`, etc.
- Added `occupancyRate` and `availableCapacity` calculations
- Status enum: `draft`, `published`, `upcoming`, `live`, `ongoing`, `completed`, `cancelled`

**Key Methods:**
```dart
EventModel.fromJson(Map<String, dynamic> json)
Map<String, dynamic> toJson()
EventModel copyWith({...})
bool get isDraft
bool get isPast
double get occupancyRate
```

#### 2. Events Service
**File:** `lib/features/events/services/events_service.dart`

**Methods Implemented:**

##### `getEventsByRole()`
- Returns events based on user role
- Venue Owner → events at their venues
- Organizer → events they created
- Promoter → events with their promo codes
- Staff → events they're assigned to via shifts

##### `getEventById()`
- Fetches single event with role-based access check
- Throws error if user doesn't have access

##### `_checkEventAccess()`
- Private helper to verify user has access to specific event
- Used before updates/deletes

##### `createEvent()`
- Only for `venue_owner` and `organizer` roles
- Creates event with proper defaults
- Links to user_id as organizer

##### `updateEvent()`
- Verifies ownership before allowing update
- Checks if user is creator OR venue owner

##### `deleteEvent()`
- Verifies ownership before allowing delete
- Only creator or venue owner can delete

##### `getEventStats()`
- Returns dashboard statistics:
  - Total events
  - Active events
  - Draft events
  - Completed events
  - Total revenue
  - Total bookings

---

### ⏳ PENDING

#### 3. Events Provider (Riverpod)
**File:** `lib/features/events/providers/events_provider.dart`

**Needs Updates:**
```dart
@riverpod
Future<List<EventModel>> eventsList(EventsListRef ref, String status) async {
  final user = ref.watch(currentVendorUserProvider);
  if (user == null) throw Exception('Not authenticated');

  final eventsService = EventsService();
  return eventsService.getEventsByRole(
    user: user,
    status: status,
  );
}

@riverpod
Future<EventModel?> eventById(EventByIdRef ref, String eventId) async {
  final user = ref.watch(currentVendorUserProvider);
  if (user == null) throw Exception('Not authenticated');

  final eventsService = EventsService();
  return eventsService.getEventById(eventId, user);
}

@riverpod
Future<Map<String, dynamic>> eventStats(EventStatsRef ref) async {
  final user = ref.watch(currentVendorUserProvider);
  if (user == null) throw Exception('Not authenticated');

  final eventsService = EventsService();
  return eventsService.getEventStats(user);
}
```

#### 4. Events List Screen
**File:** `lib/features/events/screens/events_list_screen.dart`

**Current State:**
- Has tabs: Active, Drafts, Past, Templates
- Uses `filteredEventsProvider`
- Shows empty state

**Needs Updates:**
1. Update to use new `eventsListProvider` with role parameter
2. Show role-specific messaging:
   - Venue Owner: "Events at your venues"
   - Organizer: "Events you created"
   - Promoter: "Events you're promoting" (read-only notice)
   - Staff: "Events you're working" (read-only notice)
3. Conditional "Create Event" button:
   - Show for `venue_owner` and `organizer`
   - Hide for `promoter` and `staff`
4. Update event cards to show role-relevant info
5. Add pull-to-refresh

#### 5. Event Details Screen
**File:** `lib/features/events/screens/event_details_screen.dart`

**Needs:**
1. Role-based action buttons:
   ```dart
   // Venue Owner & Organizer:
   - Edit Event
   - Delete Event
   - Manage Bookings
   - View Analytics

   // Promoter:
   - View Promo Performance (read-only)
   - No edit buttons

   // Staff:
   - View Schedule (read-only)
   - No edit buttons
   ```

2. Role-based sections visibility:
   ```dart
   if (user.isVenueOwner || user.isOrganizer) {
     // Show financial data
     // Show management options
   } else if (user.isPromoter) {
     // Show only promo-related data
   } else if (user.isStaff) {
     // Show only schedule/shift data
   }
   ```

#### 6. Create Event Screen
**File:** `lib/features/events/screens/create_event_screen.dart`

**Needs Updates:**
1. Check user role on entry:
   ```dart
   if (!user.isVenueOwner && !user.isOrganizer) {
     // Redirect with error message
     return AccessDeniedScreen();
   }
   ```

2. For Venue Owners:
   - Dropdown to select which venue
   - Auto-populate club_id

3. For Organizers:
   - Optional venue selection
   - Can create standalone events

4. Use new `EventsService().createEvent()`

---

## 🎨 UI Changes Needed

### Empty State Messages

#### Venue Owner
```
No Active Events at Your Venues
Host an event at your venue to start managing bookings
[Create Event Button]
```

#### Organizer
```
No Active Events
Create your first event to start managing bookings
[Create Event Button]
```

#### Promoter (Read-Only)
```
No Events to Promote
You haven't been assigned to any events yet
Contact an event organizer to get promo codes
[No Button - Read Only]
```

#### Staff (Read-Only)
```
No Upcoming Shifts
You haven't been assigned to any events yet
Check with your manager for shift assignments
[No Button - Read Only]
```

### Event Card Badges

Add role indicator badges:
- Venue Owner: "Your Venue" badge
- Organizer: "Organizer" badge
- Promoter: "Promoting" badge (with promo code count)
- Staff: "Working" badge (with shift time)

---

## 🧪 Testing Checklist

### Test as Venue Owner
- [ ] See events at owned venues only
- [ ] Can create event at owned venue
- [ ] Can edit events at owned venues
- [ ] Can delete events at owned venues
- [ ] Cannot see events at other venues
- [ ] Can view full financial data

### Test as Organizer
- [ ] See only events they created
- [ ] Can create new events
- [ ] Can edit their own events
- [ ] Can delete their own events
- [ ] Cannot edit others' events
- [ ] Can view financial data for their events

### Test as Promoter
- [ ] See only events with their promo codes
- [ ] Cannot create events
- [ ] Cannot edit any events
- [ ] Cannot delete any events
- [ ] Can view promo performance
- [ ] Cannot see full financial data

### Test as Staff
- [ ] See only events with their shifts
- [ ] Cannot create events
- [ ] Cannot edit any events
- [ ] Cannot delete any events
- [ ] Can view shift schedule
- [ ] Cannot see financial data

### Cross-Role Tests
- [ ] Venue owner cannot see organizer's events at other venues
- [ ] Organizer cannot edit venue owner's events
- [ ] Promoter cannot access events without promo codes
- [ ] Staff cannot access events without shifts
- [ ] All roles see correct empty states

---

## 📊 Database Migration Script

Create this migration in Supabase:

```sql
-- Enable RLS on events table
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Venue owners can view events at their venues" ON events;
DROP POLICY IF EXISTS "Organizers can view their events" ON events;
DROP POLICY IF EXISTS "Promoters can view events they promote" ON events;
DROP POLICY IF EXISTS "Staff can view events they're assigned to" ON events;
DROP POLICY IF EXISTS "Venue owners and organizers can create events" ON events;
DROP POLICY IF EXISTS "Event creators and venue owners can update events" ON events;
DROP POLICY IF EXISTS "Event creators and venue owners can delete events" ON events;

-- SELECT policies
CREATE POLICY "Venue owners can view events at their venues"
ON events FOR SELECT
USING (
  club_id IN (
    SELECT id FROM clubs WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "Organizers can view their events"
ON events FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY "Promoters can view events they promote"
ON events FOR SELECT
USING (
  id IN (
    SELECT event_id FROM promo_codes
    WHERE promoter_id = auth.uid() AND event_id IS NOT NULL
  )
);

CREATE POLICY "Staff can view events they're assigned to"
ON events FOR SELECT
USING (
  id IN (
    SELECT event_id FROM shifts WHERE staff_id = auth.uid()
  )
);

-- INSERT policy
CREATE POLICY "Venue owners and organizers can create events"
ON events FOR INSERT
WITH CHECK (
  user_id = auth.uid() AND
  EXISTS (
    SELECT 1 FROM vendors
    WHERE id = auth.uid()
    AND role IN ('venue_owner', 'organizer')
  )
);

-- UPDATE policy
CREATE POLICY "Event creators and venue owners can update events"
ON events FOR UPDATE
USING (
  user_id = auth.uid() OR
  club_id IN (SELECT id FROM clubs WHERE owner_id = auth.uid())
);

-- DELETE policy
CREATE POLICY "Event creators and venue owners can delete events"
ON events FOR DELETE
USING (
  user_id = auth.uid() OR
  club_id IN (SELECT id FROM clubs WHERE owner_id = auth.uid())
);
```

---

## 🚀 Implementation Steps

### Step 1: Apply RLS Policies ✅
- Go to Supabase Dashboard → SQL Editor
- Run the migration script above
- Verify policies are active

### Step 2: Update Events Provider
- Modify `lib/features/events/providers/events_provider.dart`
- Replace mock data with `EventsService` calls
- Add error handling

### Step 3: Update Events List Screen
- Add role-based messaging
- Conditional "Create" button
- Update empty states
- Use new provider

### Step 4: Update/Create Event Details Screen
- Role-based action buttons
- Conditional sections
- Proper access checks

### Step 5: Update Create Event Screen
- Role check on entry
- Venue selection for venue owners
- Integration with EventsService

### Step 6: Testing
- Test all 4 roles
- Verify RLS policies work
- Check edge cases
- Performance testing

---

## 📝 Next Actions

**IMMEDIATE (High Priority):**
1. ✅ Create Event model matching Supabase schema
2. ✅ Create EventsService with role-based methods
3. 🚧 Apply RLS policies in Supabase
4. ⏳ Update events providers
5. ⏳ Update Events List Screen

**NEXT (Medium Priority):**
6. Create/Update Event Details Screen
7. Update Create Event Screen
8. Add role-based action buttons

**LATER (Low Priority):**
9. Add analytics per role
10. Add real-time subscriptions
11. Performance optimization

---

**Last Updated:** 2025-12-19
**Status:** Event Model & Service Complete | RLS Policies Ready | UI Updates Pending
