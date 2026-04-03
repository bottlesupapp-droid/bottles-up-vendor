# TestFlight Testing Guide - Bottles Up Vendor

## Overview
This guide will help you test all 9 new features on the TestFlight build. All features are now integrated with Supabase and ready for production testing.

---

## Pre-Testing Setup

### 1. Ensure Database Schema is Applied

**CRITICAL**: Before testing, verify the database schema has been applied to your Supabase instance.

**Check via Supabase Dashboard**:
1. Go to https://supabase.com/dashboard
2. Select project: `bottles-up-2d907`
3. Navigate to **Table Editor**
4. Verify these tables exist:
   - ✅ `inquiries`
   - ✅ `guest_list`
   - ✅ `scheduled_releases`
   - ✅ `venue_boosts`
   - ✅ `bookings` (with new columns: `ticket_code`, `qr_code`, `checked_in`)

**If tables don't exist**: Run `supabase_schema.sql` in SQL Editor first.

### 2. Install TestFlight Build

1. Open TestFlight app on your iOS device
2. Accept the invitation for "Bottles Up Vendor"
3. Install the latest build
4. Launch the app

### 3. Login as Vendor

1. Open the app
2. Login with your vendor credentials
3. Verify you reach the dashboard

---

## Feature Testing Checklist

## ✅ Feature 1: Analytics Dashboard

### Test Steps:

1. **Navigate to Analytics**
   - Tap the **Analytics** tab in bottom navigation
   - Expected: Dashboard loads with 4 tabs (Overview, Revenue, Events, Inquiries)

2. **Test Overview Tab**
   - View inquiry statistics (total, pending, accepted, rejected)
   - View booking statistics (total, confirmed, pending, cancelled)
   - View revenue totals
   - Check booking trends chart (last 7 days)
   - Expected: All data loads from Supabase database

3. **Test Revenue Tab**
   - View revenue breakdown by type (Tickets, Tables, Bottles, Other)
   - Check revenue by event list
   - View revenue by month chart
   - Expected: Revenue calculations match database records

4. **Test Events Tab**
   - View list of events with performance metrics
   - Check conversion rates and attendance rates
   - Tap on individual events for details
   - Expected: Metrics calculated from real booking data

5. **Test Inquiries Tab**
   - View recent customer inquiries
   - Check inquiry status badges (Pending/Accepted/Rejected)
   - Verify customer contact information displays
   - Expected: Shows last 10 inquiries from database

### Success Criteria:
- ✅ All 4 tabs load without errors
- ✅ Data reflects actual database records
- ✅ Charts render correctly
- ✅ Pull-to-refresh updates data

### What to Screenshot:
- Overview tab showing stats
- Revenue breakdown chart
- Event performance list
- Inquiries list

---

## ✅ Feature 2: QR Code Ticket Scanner

### Test Steps:

1. **Navigate to Scanner**
   - Go to **Events** tab
   - Tap on any event
   - Tap the **QR Scanner** icon (top-right or in event actions)
   - Expected: Camera permission prompt appears

2. **Grant Camera Permission**
   - Tap **Allow** when prompted
   - Expected: Camera view opens with scanning overlay

3. **Test Scanner UI**
   - View scan statistics at top (Total, Checked In, Pending)
   - Check flash toggle button works
   - Verify scanning frame displays (orange border)
   - Expected: Live camera feed visible

4. **Test QR Scanning** (Requires test QR code)
   - Point camera at QR code containing a valid ticket code
   - Wait for auto-scan
   - Expected: Success dialog shows booking details

5. **Test Check-In Flow**
   - After successful scan, verify booking details shown:
     - Customer name
     - Ticket code
     - Booking type
     - Amount paid
   - Tap **Confirm Check-In**
   - Expected: Database updated, ticket marked as checked in

6. **Test Already Checked-In**
   - Scan the same QR code again
   - Expected: Error message "Ticket already checked in"

7. **Test Invalid Ticket**
   - Scan QR code with non-existent ticket code
   - Expected: Error message shown

### Success Criteria:
- ✅ Camera opens successfully
- ✅ QR codes scan automatically
- ✅ Check-in updates database
- ✅ Stats update after check-in
- ✅ Duplicate scan prevented

### What to Screenshot:
- Scanner screen with camera view
- Successful check-in dialog
- Updated scan statistics
- Already checked-in error

### Test Data Setup:
If you don't have test QR codes:
1. Go to Supabase dashboard
2. Table Editor → `bookings`
3. Find a booking record
4. Copy the `ticket_code` value
5. Generate QR code at https://www.qr-code-generator.com/
6. Enter the ticket code as QR content
7. Print or display on another device

---

## ✅ Feature 3: Bulk Guest List Upload

### Test Steps:

1. **Navigate to Guest List**
   - Go to **Events** tab
   - Tap on any event
   - Tap **Guest List** option
   - Expected: Guest list screen loads

2. **Test Manual Guest Add**
   - Tap **+ Add Guest** floating button
   - Fill in guest details:
     - Name: "Test Guest"
     - Email: "test@example.com"
     - Phone: "+1234567890"
     - Ticket Type: "VIP"
     - Notes: "Table 5"
   - Tap **Save**
   - Expected: Guest appears in list immediately

3. **Test Search Functionality**
   - Type guest name in search bar
   - Expected: List filters in real-time

4. **Test Guest Check-In**
   - Find unchecked guest in list
   - Tap **Check In** button
   - Expected:
     - Check-in time appears
     - Button changes to "Checked In" (disabled)
     - Database updated

5. **Test CSV Upload**
   - Tap **Upload CSV** button
   - Select test CSV file from device
   - Expected: Upload progress shown, then guests added

6. **Test Pull-to-Refresh**
   - Pull down on guest list
   - Expected: List refreshes from database

### Success Criteria:
- ✅ Manual add works instantly
- ✅ Search filters correctly
- ✅ Check-in updates database
- ✅ CSV upload processes all rows
- ✅ Guest count updates

### CSV Test File Format:
Create `test_guests.csv`:
```csv
Name,Email,Phone,Ticket Type,Notes
John Doe,john@example.com,+1234567890,VIP,Table 5
Jane Smith,jane@example.com,+0987654321,General,
Mike Johnson,mike@example.com,+1122334455,VIP,Table 8
Sarah Williams,sarah@example.com,,General,Group booking
```

### What to Screenshot:
- Empty guest list
- Add guest form
- Guest list with entries
- CSV upload success
- Checked-in guest with timestamp

---

## ✅ Feature 4: Scheduled Ticket Releases

### Test Steps:

1. **Navigate to Scheduled Releases**
   - Go to **Events** tab
   - Tap on any event
   - Tap **Scheduled Releases** option
   - Expected: List of scheduled releases or empty state

2. **Test Add Release**
   - Tap **+ Add Release** button
   - Fill in release details:
     - Name: "Early Bird Special"
     - Release Date: [Select future date]
     - Release Time: [Select time]
     - Ticket Quantity: 100
     - Price: $45.00
   - Tap **Save**
   - Expected: Release added to list

3. **Test Release Display**
   - View release card showing:
     - Release name
     - Countdown timer (e.g., "in 7 days")
     - Ticket quantity
     - Price
   - Expected: All details visible

4. **Test Multiple Releases**
   - Add another release:
     - Name: "General Sale"
     - Release Date: [Later date than first]
     - Ticket Quantity: 200
     - Price: $60.00
   - Expected: Both releases shown in chronological order

5. **Test Delete Release**
   - Tap delete icon on a release
   - Confirm deletion
   - Expected: Release removed from list and database

6. **Test Countdown Timer**
   - Check countdown format for different timeframes:
     - More than 24h: "in X days"
     - Less than 24h: "in X hours"
     - Less than 1h: "in X minutes"
   - Expected: Countdown updates correctly

### Success Criteria:
- ✅ Releases save to database
- ✅ Countdown timers accurate
- ✅ Releases sorted by date
- ✅ Delete removes from database
- ✅ Price formatting correct ($XX.XX)

### What to Screenshot:
- Empty state
- Add release form with date picker
- Release card with countdown
- Multiple releases listed
- Delete confirmation

---

## ✅ Feature 5: Revenue Breakdown Reports

### Test Steps:

1. **Navigate to Analytics → Revenue Tab**
   - Open Analytics from bottom nav
   - Tap **Revenue** tab
   - Expected: Revenue breakdown screen loads

2. **Test Category Breakdown**
   - View revenue by category:
     - Ticket Sales
     - Table Sales
     - Bottle Sales
     - Other Sales
   - Check total revenue sum
   - Expected: Categories sum to total

3. **Test Revenue by Event**
   - Scroll to "Revenue by Event" section
   - View list of events with:
     - Event name
     - Total revenue
     - Number of bookings
   - Expected: All events with bookings shown

4. **Test Revenue by Month**
   - Scroll to "Revenue by Month" section
   - View monthly breakdown (last 3 months)
   - Check month names and amounts
   - Expected: Months in chronological order

5. **Test Data Accuracy**
   - Pick one event from list
   - Note its revenue amount
   - Verify against Supabase dashboard:
     - Table Editor → `bookings`
     - Filter by event_id
     - Sum `total_amount` column
   - Expected: Amounts match

### Success Criteria:
- ✅ Category totals add up correctly
- ✅ Event revenue accurate
- ✅ Monthly breakdown shows 3 months
- ✅ Currency formatting correct
- ✅ Zero revenue shows $0.00

### What to Screenshot:
- Category breakdown
- Revenue by event list
- Monthly revenue chart

---

## ✅ Feature 6: Sales Analytics Dashboard

### Test Steps:

1. **Navigate to Analytics → Overview Tab**
   - Open Analytics from bottom nav
   - Stay on **Overview** tab
   - Expected: Dashboard with charts and stats

2. **Test Booking Trends Chart**
   - View 7-day line chart
   - Check data points for each day
   - Tap on chart points (if interactive)
   - Expected: Chart shows last 7 days of bookings

3. **Test Metric Cards**
   - View summary cards:
     - Total Inquiries
     - Total Bookings
     - Total Revenue
     - Confirmed Bookings
   - Expected: Large numbers with icons

4. **Test Inquiry Breakdown**
   - View inquiry status counts:
     - Pending (yellow badge)
     - Accepted (green badge)
     - Rejected (red badge)
   - Expected: Color-coded status badges

5. **Test Booking Status Breakdown**
   - View booking status counts:
     - Confirmed
     - Pending
     - Cancelled
   - Expected: Status counts match database

### Success Criteria:
- ✅ Chart renders with data points
- ✅ Metrics calculate correctly
- ✅ Status badges color-coded
- ✅ Pull-to-refresh updates all data

### What to Screenshot:
- Full overview dashboard
- Booking trends chart
- Metric cards
- Status breakdowns

---

## ✅ Feature 7: Event Performance Insights

### Test Steps:

1. **Navigate to Analytics → Events Tab**
   - Open Analytics from bottom nav
   - Tap **Events** tab
   - Expected: List of events with performance metrics

2. **Test Event Metrics**
   - View each event card showing:
     - Event name
     - Total tickets
     - Sold tickets
     - Conversion rate (%)
     - Attendance rate (%)
     - Revenue per ticket
   - Expected: All metrics calculated from database

3. **Test Conversion Rate**
   - Formula: (Sold Tickets / Total Tickets) × 100
   - Verify calculation:
     - Find event with 100 total, 85 sold
     - Expected: 85% conversion rate

4. **Test Attendance Rate**
   - Formula: (Checked In / Sold Tickets) × 100
   - Verify calculation:
     - Find event with 85 sold, 72 checked in
     - Expected: 84.7% attendance rate

5. **Test Revenue Per Ticket**
   - Formula: Total Revenue / Sold Tickets
   - Verify calculation:
     - Event with $5,000 revenue, 100 tickets
     - Expected: $50.00 per ticket

6. **Test Event Sorting**
   - Check if events sorted by date or performance
   - Expected: Most recent or best performing first

### Success Criteria:
- ✅ All metrics accurate
- ✅ Percentages formatted correctly
- ✅ Currency formatted correctly
- ✅ Zero-booking events handled gracefully

### What to Screenshot:
- Event list with metrics
- Individual event card
- High-performing event
- Low-performing event

---

## ✅ Feature 8: Organizer Inquiries & Bookings Analytics

### Test Steps:

1. **Navigate to Analytics → Inquiries Tab**
   - Open Analytics from bottom nav
   - Tap **Inquiries** tab
   - Expected: List of recent customer inquiries

2. **Test Inquiry Cards**
   - View each inquiry showing:
     - Customer name
     - Event name
     - Message preview
     - Status badge (Pending/Accepted/Rejected)
     - Timestamp
   - Expected: Last 10 inquiries shown

3. **Test Inquiry Status**
   - Find pending inquiry (yellow badge)
   - Find accepted inquiry (green badge)
   - Find rejected inquiry (red badge)
   - Expected: Color-coded correctly

4. **Test Inquiry Details**
   - Tap on an inquiry card
   - Expected: Full inquiry details shown (if implemented)

5. **Test Empty State**
   - If no inquiries exist:
     - Expected: "No inquiries yet" message

6. **Test Booking Connection**
   - Note inquiry's event name
   - Go to Events tab → Find that event
   - Check if inquiry's event matches
   - Expected: Data consistency across screens

### Success Criteria:
- ✅ Inquiries load from database
- ✅ Status badges accurate
- ✅ Timestamps formatted correctly
- ✅ Customer info displays
- ✅ Event names link correctly

### What to Screenshot:
- Inquiries list
- Inquiry card detail
- Different status badges
- Empty state (if applicable)

---

## ✅ Feature 9: Venue Boost Packages

### Test Steps:

1. **Navigate to Venue Boost**
   - Go to **Profile/Settings** or **Venues** section
   - Find your venue
   - Tap **Boost Visibility** option
   - Expected: Boost packages screen loads

2. **Test Package Display**
   - View 3 boost packages:
     - **Basic Boost** ($49.99 / 7 days)
     - **Premium Boost** ($89.99 / 14 days)
     - **Elite Boost** ($149.99 / 30 days)
   - Expected: All packages shown with features

3. **Test Package Features**
   - Basic package features:
     - Featured in search results
     - Priority placement
     - Highlighted listing
   - Premium package features:
     - Everything in Basic
     - Top of category
     - Featured badge
     - Homepage feature
   - Elite package features:
     - Everything in Premium
     - Dedicated account manager
     - Analytics dashboard
     - Custom promotion

4. **Test Active Boost Display**
   - If boost is active:
     - View performance metrics:
       - Impressions
       - Clicks
       - Click-through rate (CTR)
     - Check remaining days
   - Expected: Metrics displayed correctly

5. **Test Purchase Flow** (UI Only - Payment Not Implemented)
   - Tap **Purchase Boost** on any package
   - Expected: Payment screen or coming soon message

### Success Criteria:
- ✅ All 3 packages display
- ✅ Pricing correct
- ✅ Features listed for each tier
- ✅ Active boost metrics shown (if any)
- ✅ UI responsive and attractive

### What to Screenshot:
- All 3 boost packages
- Package features expanded
- Active boost metrics (if applicable)

---

## Database Verification Tests

### Test 1: Check-In Persistence

1. Check in a guest via Guest List
2. Close the app completely
3. Reopen the app
4. Navigate back to Guest List
5. Expected: Guest still shows as checked in

### Test 2: Real-Time Data Sync

1. Open Supabase dashboard on computer
2. Table Editor → `guest_list`
3. Add a new guest manually
4. In TestFlight app, pull-to-refresh guest list
5. Expected: New guest appears in app

### Test 3: Cross-Feature Data Consistency

1. Note total bookings from Analytics → Overview
2. Go to Events → [Event] → Scanner
3. Check scan stats total count
4. Expected: Numbers should align

### Test 4: RLS Security Test

1. Login as Vendor A
2. Note Vendor A's event IDs
3. Logout and login as Vendor B
4. Navigate to Analytics
5. Expected: Only Vendor B's data visible (not Vendor A's)

---

## Performance Testing

### Load Time Tests

| Screen | Expected Load Time | Pass/Fail |
|--------|-------------------|-----------|
| Analytics Dashboard | < 2 seconds | ⬜ |
| QR Scanner | < 1 second | ⬜ |
| Guest List (100 guests) | < 3 seconds | ⬜ |
| Scheduled Releases | < 2 seconds | ⬜ |

### Stress Tests

1. **Large Guest List**
   - Upload CSV with 500+ guests
   - Expected: App handles without crash

2. **Rapid QR Scanning**
   - Scan 10 different QR codes in quick succession
   - Expected: All scan correctly, no lag

3. **Analytics with Large Dataset**
   - View analytics with 1000+ bookings
   - Expected: Charts render correctly

---

## Error Handling Tests

### Network Error Tests

1. **Test Offline Mode**
   - Enable Airplane Mode
   - Try to load Analytics
   - Expected: Error message "No internet connection"

2. **Test Slow Connection**
   - Use slow network (enable in Settings → Developer)
   - Load Analytics dashboard
   - Expected: Loading indicators shown

### Authentication Tests

1. **Test Session Expiry**
   - Let app sit idle for 30+ minutes
   - Try to perform action
   - Expected: Re-login prompt or automatic refresh

### Invalid Data Tests

1. **Test Invalid QR Code**
   - Scan QR code with random text
   - Expected: "Invalid ticket code" error

2. **Test Empty CSV Upload**
   - Upload CSV with only headers (no data rows)
   - Expected: "No guests found in file" message

3. **Test Malformed CSV**
   - Upload CSV with missing columns
   - Expected: Validation error message

---

## Camera Permission Tests (iOS Specific)

### First Launch

1. Fresh install from TestFlight
2. Navigate to QR Scanner
3. Expected: Camera permission alert appears

### Permission Denied

1. If previously denied, go to:
   - Settings → Bottles Up Vendor
2. Toggle Camera OFF
3. Navigate to QR Scanner
4. Expected: "Camera permission required" message with Settings button

### Permission Granted

1. Settings → Bottles Up Vendor → Camera ON
2. Navigate to QR Scanner
3. Expected: Camera opens immediately

---

## UI/UX Tests

### Visual Tests

- ✅ Dark theme applied throughout
- ✅ Orange accent color (#FF6B35) used correctly
- ✅ Cards have rounded corners
- ✅ Text readable on dark backgrounds
- ✅ Icons consistent (Ionicons)
- ✅ Loading states show spinners
- ✅ Error states show messages

### Navigation Tests

- ✅ Bottom nav switches between tabs
- ✅ Back button returns to previous screen
- ✅ Deep links work (if implemented)
- ✅ Gesture navigation works
- ✅ Pull-to-refresh on all list screens

### Accessibility Tests

- ✅ Font sizes readable
- ✅ Touch targets minimum 44×44 pts
- ✅ Color contrast meets standards
- ✅ VoiceOver support (if enabled)

---

## Bug Report Template

If you find issues, report using this format:

```
**Bug Title**: [Short description]

**Feature**: [Which of 9 features]

**Steps to Reproduce**:
1.
2.
3.

**Expected Behavior**:

**Actual Behavior**:

**Screenshot**: [Attach if applicable]

**Device Info**:
- Device: [e.g., iPhone 14 Pro]
- iOS Version: [e.g., 17.2]
- Build Number: [from TestFlight]

**Severity**: [Critical / High / Medium / Low]
```

---

## Known Limitations (Not Bugs)

1. **Venue Boost Payment**: Purchase flow shows UI only - payment integration pending
2. **QR Scanner on Simulator**: Requires physical device with camera
3. **Analytics Views**: Requires database views to be created first (see setup)
4. **Test Data**: If database is empty, most screens will show empty states

---

## Success Metrics

### Feature Adoption
- ✅ All 9 features accessible
- ✅ No crashes during testing
- ✅ All database operations succeed

### Data Accuracy
- ✅ Analytics numbers match database
- ✅ Real-time updates work
- ✅ No data leakage between vendors

### User Experience
- ✅ Intuitive navigation
- ✅ Fast load times
- ✅ Clear error messages
- ✅ Helpful empty states

---

## Post-Testing Checklist

After completing all tests:

- [ ] Screenshot all features working
- [ ] Document any bugs found
- [ ] Verify database has test data
- [ ] Test on multiple iOS versions (if available)
- [ ] Test on different device sizes (iPhone SE vs Pro Max)
- [ ] Confirm camera permissions work correctly
- [ ] Verify all CSV uploads successful
- [ ] Check analytics calculations accurate
- [ ] Test guest check-in flow end-to-end
- [ ] Confirm QR scanner detects codes reliably

---

## Test Data Cleanup

After testing, clean up test data:

### Option 1: Supabase Dashboard
1. Go to Table Editor
2. Delete test entries from:
   - `guest_list` (test guests)
   - `scheduled_releases` (test releases)
   - `inquiries` (test inquiries)

### Option 2: SQL Query
```sql
-- Delete test data (use with caution!)
DELETE FROM guest_list WHERE name LIKE 'Test%';
DELETE FROM scheduled_releases WHERE name LIKE 'Test%';
```

---

## Support & Questions

If you encounter issues:

1. **Check Database First**: Verify schema applied via Supabase dashboard
2. **Check Logs**: View Supabase logs for API errors
3. **Review Documentation**:
   - `SUPABASE_INTEGRATION.md` - Integration details
   - `IMPLEMENTATION_SUMMARY.md` - Feature specs
   - `TESTING_GUIDE.md` - Detailed testing steps

---

## Summary

### What You're Testing:
✅ **9 New Features** - All integrated with Supabase
✅ **Real-Time Data** - Live database operations
✅ **QR Scanning** - Physical device camera integration
✅ **CSV Upload** - Bulk data import
✅ **Analytics** - Complex queries and calculations
✅ **Security** - Row Level Security policies

### Time Estimate:
- **Quick Test** (all features): 30-45 minutes
- **Thorough Test** (with edge cases): 2-3 hours
- **Full Test** (including stress tests): 4-5 hours

### Critical Tests:
1. Database schema applied ✅
2. Analytics loads real data ✅
3. QR scanner checks in tickets ✅
4. Guest list CSV uploads ✅
5. Scheduled releases save to DB ✅

**Happy Testing! 🎉**
