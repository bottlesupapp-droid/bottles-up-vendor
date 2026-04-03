# Analytics Dashboard Fixes

**Date:** April 3, 2026
**Issues Fixed:** Events tab showing no data + Overview tab not responsive

---

## Problems Identified

### 1. **Events Tab - No Data Showing**
**Root Cause:** The `v_event_performance` database view was missing the `user_id` column, but the provider was trying to filter by `user_id`.

**Error Location:**
- File: [lib/features/analytics/providers/analytics_provider.dart:210](lib/features/analytics/providers/analytics_provider.dart#L210)
- Code: `.eq('user_id', userId)` tried to filter on a non-existent column

### 2. **Overview Tab - Not Responsive**
**Root Cause:** The entire `TabBarView` was wrapped inside `analyticsData.when()`. If the analytics provider had an error, the TabBarView body would not render at all, making tabs appear clickable but non-functional.

**Error Location:**
- File: [lib/features/analytics/screens/analytics_dashboard_screen.dart:63](lib/features/analytics/screens/analytics_dashboard_screen.dart#L63)

### 3. **Provider Crash on Empty Data**
**Root Cause:** Using `.single()` instead of `.maybeSingle()` caused the provider to throw an error when no analytics data existed.

**Error Location:**
- File: [lib/features/analytics/providers/analytics_provider.dart:21](lib/features/analytics/providers/analytics_provider.dart#L21)

---

## Fixes Applied

### ✅ Fix 1: Updated Database View
**File:** [supabase_schema.sql:404-417](supabase_schema.sql#L404-L417)

Added `e.user_id` to the SELECT clause and GROUP BY clause:

```sql
CREATE OR REPLACE VIEW v_event_performance AS
SELECT
  e.id as event_id,
  e.name as event_name,
  e.user_id,  -- ✅ ADDED
  e.max_capacity as total_tickets,
  ...
FROM events e
LEFT JOIN bookings b ON e.id = b.event_id
GROUP BY e.id, e.name, e.user_id, ...;  -- ✅ ADDED user_id
```

### ✅ Fix 2: Handle Empty Analytics Data
**File:** [lib/features/analytics/providers/analytics_provider.dart:17-26](lib/features/analytics/providers/analytics_provider.dart#L17-L26)

Changed from `.single()` to `.maybeSingle()` and added null check:

```dart
final analyticsData = await supabase
    .from('v_organizer_analytics')
    .select()
    .eq('organizer_id', userId)
    .maybeSingle();  // ✅ CHANGED from .single()

// ✅ ADDED: Handle no data case
if (analyticsData == null) {
  return const OrganizerAnalytics();
}
```

### ✅ Fix 3: Restructured Dashboard Layout
**File:** [lib/features/analytics/screens/analytics_dashboard_screen.dart:39-141](lib/features/analytics/screens/analytics_dashboard_screen.dart#L39-L141)

**Before:**
```dart
body: analyticsData.when(
  data: (data) => TabBarView(...),  // ❌ Entire TabBarView inside .when()
)
```

**After:**
```dart
body: TabBarView(  // ✅ TabBarView always renders
  children: [
    _buildOverviewTabWithState(context),  // Individual tabs handle state
    _buildRevenueTab(context),
    _buildEventsTab(context),
    _buildInquiriesTabWithState(context),
  ],
)
```

Created new wrapper methods:
- `_buildOverviewTabWithState()` - Wraps the overview tab with state handling
- `_buildInquiriesTabWithState()` - Wraps the inquiries tab with state handling

---

## Database Migration Required

You need to run the migration on your Supabase database:

### Option 1: Using Supabase Dashboard
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Run this migration:

```sql
-- Migration: Fix v_event_performance view to include user_id
CREATE OR REPLACE VIEW v_event_performance AS
SELECT
  e.id as event_id,
  e.name as event_name,
  e.user_id,
  e.max_capacity as total_tickets,
  e.current_bookings as sold_tickets,
  e.rsvp_count,
  COUNT(b.id) FILTER (WHERE b.checked_in = true) as checked_in_count,
  ROUND((e.current_bookings::NUMERIC / NULLIF(e.max_capacity, 0) * 100), 2) as conversion_rate,
  ROUND((COUNT(b.id) FILTER (WHERE b.checked_in = true)::NUMERIC / NULLIF(e.current_bookings, 0) * 100), 2) as attendance_rate,
  ROUND((e.revenue::NUMERIC / NULLIF(e.current_bookings, 0)), 2) as revenue_per_ticket
FROM events e
LEFT JOIN bookings b ON e.id = b.event_id
GROUP BY e.id, e.name, e.user_id, e.max_capacity, e.current_bookings, e.rsvp_count, e.revenue;
```

### Option 2: Using Supabase CLI
```bash
supabase migration up
```

The migration file has been created at: [supabase/migrations/fix_event_performance_view.sql](supabase/migrations/fix_event_performance_view.sql)

---

## Testing the Fixes

After applying the database migration, test the following:

### ✅ Events Tab
1. Navigate to Analytics Dashboard
2. Click on the **Events** tab
3. **Expected:** You should now see your 2 events with performance metrics:
   - Event name
   - Sold/Total tickets
   - RSVP count
   - Checked-in count
   - Conversion rate %
   - Attendance rate %

### ✅ Overview Tab Responsiveness
1. Click on the **Overview** tab
2. **Expected:** The tab should switch immediately and show:
   - 4 metric cards (Total Bookings, Total Revenue, Pending Inquiries, Confirmed Bookings)
   - Booking trends chart
   - Quick statistics section

### ✅ All Tabs Navigation
1. Try clicking all tabs in sequence: Overview → Revenue → Events → Inquiries
2. **Expected:** All tabs should respond and switch content smoothly

### ✅ Error Handling
1. If any tab has an error, it should show an error message with a "Retry" button
2. Other tabs should still be accessible and functional

---

## What Changed - Summary

| Component | Before | After |
|-----------|--------|-------|
| **Database View** | Missing `user_id` column | ✅ Includes `user_id` for filtering |
| **Provider** | Used `.single()`, crashed on empty data | ✅ Uses `.maybeSingle()`, returns empty analytics |
| **UI Structure** | TabBarView inside `.when()` | ✅ TabBarView always renders, tabs handle state individually |
| **Tab Responsiveness** | Tabs appeared clickable but didn't work | ✅ All tabs fully functional |
| **Events Tab** | Empty (database query failed) | ✅ Shows event list with metrics |

---

## Additional Notes

- The code still has deprecated `.withOpacity()` calls that should be updated to `.withValues()` for future Flutter compatibility
- An unused `theme` variable exists at line 123 that can be removed
- All other features (Revenue tab, Inquiries tab) should continue working as before

---

## Next Steps

1. **Apply the database migration** (see instructions above)
2. **Hot restart the app** (`r` in terminal or restart from IDE)
3. **Test all 4 tabs** to ensure they're working
4. **Verify event data** appears correctly in the Events tab

If you encounter any issues, check the Flutter console for error messages and let me know!
