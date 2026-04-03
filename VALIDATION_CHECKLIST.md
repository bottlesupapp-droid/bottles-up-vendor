# Feature Validation Checklist

## Pre-Validation Setup

### 1. Environment Setup
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] Run `flutter analyze` (ensure no errors)
- [ ] Run `flutter doctor` (ensure all platforms are ready)

### 2. Database Setup
- [ ] Verify Supabase connection is working
- [ ] Confirm the following database views exist:
  - `v_organizer_analytics`
  - `v_event_performance`
- [ ] Verify database tables exist:
  - `vendors`
  - `events`
  - `bookings`
  - `inquiries`
  - `scheduled_ticket_releases`
  - `guest_list`
  - `venue_boosts`

### 3. Test Data Setup
- [ ] Create at least 2 test events
- [ ] Create at least 5 test bookings with different statuses
- [ ] Create test inquiries (pending, accepted, rejected)
- [ ] Have test guest list data ready (CSV file)

---

## Feature Validation

## 1. Organizer Analytics (Inquiries & Bookings)

**Files to Review:**
- [analytics_dashboard_screen.dart](lib/features/analytics/screens/analytics_dashboard_screen.dart)
- [analytics_provider.dart](lib/features/analytics/providers/analytics_provider.dart)
- [analytics_models.dart](lib/shared/models/analytics_models.dart)

### Test Cases:

#### 1.1 Analytics Dashboard Access
- [ ] Navigate to Analytics section from bottom navigation
- [ ] Verify dashboard loads without errors
- [ ] Confirm 4 tabs are visible: Overview, Revenue, Events, Inquiries

#### 1.2 Overview Tab
- [ ] Verify 4 metric cards display correctly:
  - [ ] Total Bookings (number matches database)
  - [ ] Total Revenue ($ amount is correct)
  - [ ] Pending Inquiries (count is accurate)
  - [ ] Confirmed Bookings (count is accurate)
- [ ] Check booking trends chart:
  - [ ] Chart displays data for the selected period
  - [ ] X-axis shows dates correctly
  - [ ] Y-axis shows booking counts
  - [ ] Chart is interactive (touch to see values)
- [ ] Verify Quick Statistics section:
  - [ ] Conversion rate displays correctly
  - [ ] Average booking value shows
  - [ ] Top performing event displays

#### 1.3 Inquiries Tab
- [ ] View list of recent inquiries
- [ ] Verify inquiry cards show:
  - [ ] Customer name
  - [ ] Event name
  - [ ] Inquiry date
  - [ ] Status badge (Pending/Accepted/Rejected)
  - [ ] Inquiry details
- [ ] Filter inquiries by status:
  - [ ] All
  - [ ] Pending
  - [ ] Accepted
  - [ ] Rejected
- [ ] Tap on an inquiry to view details
- [ ] Verify inquiry response actions work (if implemented)

#### 1.4 Data Accuracy
- [ ] Cross-reference analytics numbers with database
- [ ] Verify calculations are correct (revenue totals, percentages)
- [ ] Test with empty state (no bookings/inquiries)
- [ ] Test with large datasets (100+ bookings)

#### 1.5 Error Handling
- [ ] Test offline mode behavior
- [ ] Test with network errors
- [ ] Verify loading states display correctly
- [ ] Verify error messages are user-friendly

---

## 2. Local Service Ads / Boosted Visibility for Venues

**Files to Review:**
- [venue_boost_screen.dart](lib/features/venues/screens/venue_boost_screen.dart)
- [analytics_models.dart](lib/shared/models/analytics_models.dart)

### Test Cases:

#### 2.1 Boost Package Display
- [ ] Navigate to a venue detail screen
- [ ] Access "Boost Venue" option
- [ ] Verify 3 package tiers display:
  - [ ] **Basic**: 7 days, $49.99
  - [ ] **Premium**: 14 days, $89.99
  - [ ] **Elite**: 30 days, $149.99
- [ ] Verify each package shows features included
- [ ] Confirm pricing displays correctly

#### 2.2 Active Boost Display
- [ ] If venue has active boost, verify it displays:
  - [ ] Package type
  - [ ] Start and end dates
  - [ ] Days remaining
  - [ ] Impressions count
  - [ ] Clicks count
  - [ ] CTR (Click-Through Rate) percentage
- [ ] Verify statistics update in real-time
- [ ] Check progress indicators work correctly

#### 2.3 Boost Purchase Flow
- [ ] Select a boost package
- [ ] Tap "Purchase" button
- [ ] Verify confirmation dialog appears
- [ ] Confirm purchase details are correct
- [ ] Complete purchase
- [ ] Verify boost activates immediately
- [ ] Confirm database entry created

#### 2.4 Boost Management
- [ ] View all active boosts for a vendor
- [ ] Check boost expiration handling
- [ ] Verify expired boosts are marked correctly
- [ ] Test boost renewal process
- [ ] Verify multiple venues can have boosts

#### 2.5 Analytics Tracking
- [ ] Verify impressions increment correctly
- [ ] Verify clicks are tracked
- [ ] Confirm CTR calculation is accurate
- [ ] Test with zero impressions/clicks

---

## 3. Bulk Upload Guest List

**Files to Review:**
- [guest_list_screen.dart](lib/features/events/screens/guest_list_screen.dart)
- [guest_list_provider.dart](lib/features/events/providers/guest_list_provider.dart)

### Test Cases:

#### 3.1 Guest List Screen Access
- [ ] Navigate to event details
- [ ] Tap "Guest List" button
- [ ] Verify screen loads with current guest list
- [ ] Confirm search bar is visible
- [ ] Verify "Upload CSV" and "Add Guest" buttons present

#### 3.2 CSV Bulk Upload
- [ ] Tap "Upload CSV" button
- [ ] Select a CSV file with guest data
- [ ] Verify CSV format help is available
- [ ] Required CSV columns:
  - [ ] Name
  - [ ] Email
  - [ ] Phone
  - [ ] Ticket Type
  - [ ] Notes (optional)
- [ ] Upload CSV with 10+ guests
- [ ] Verify all guests are added to the list
- [ ] Confirm database entries created
- [ ] Check for duplicate handling

#### 3.3 CSV Validation
- [ ] Upload CSV with missing required fields
- [ ] Verify error message displays
- [ ] Upload CSV with invalid email format
- [ ] Upload CSV with duplicate entries
- [ ] Upload empty CSV file
- [ ] Upload very large CSV (1000+ rows)
- [ ] Test with special characters in names

#### 3.4 Manual Guest Addition
- [ ] Tap "Add Guest" button
- [ ] Fill in guest details:
  - [ ] Name (required)
  - [ ] Email (required)
  - [ ] Phone (required)
  - [ ] Ticket Type (dropdown)
  - [ ] Notes (optional)
- [ ] Submit form
- [ ] Verify guest appears in list immediately
- [ ] Confirm validation works (required fields)

#### 3.5 Guest List Management
- [ ] Search for guests by name
- [ ] Search by email
- [ ] Search by phone number
- [ ] Verify search is case-insensitive
- [ ] View guest details card:
  - [ ] Name displays correctly
  - [ ] Email displays
  - [ ] Phone displays
  - [ ] Ticket type badge shows
  - [ ] Check-in status indicator
- [ ] Test with 100+ guests (performance)

#### 3.6 Guest Check-In
- [ ] Tap on a guest card
- [ ] Verify check-in button appears
- [ ] Mark guest as checked in
- [ ] Confirm status updates immediately
- [ ] Verify check-in timestamp recorded
- [ ] Test un-checking in (if supported)

---

## 4. Revenue Breakdown Reports

**Files to Review:**
- [analytics_dashboard_screen.dart](lib/features/analytics/screens/analytics_dashboard_screen.dart) (Revenue tab)
- [analytics_provider.dart](lib/features/analytics/providers/analytics_provider.dart)

### Test Cases:

#### 4.1 Revenue Tab Access
- [ ] Navigate to Analytics Dashboard
- [ ] Switch to "Revenue" tab
- [ ] Verify revenue breakdown loads

#### 4.2 Revenue Breakdown Display
- [ ] Verify total revenue displays at top
- [ ] Confirm breakdown by type:
  - [ ] Ticket Sales (with $ amount)
  - [ ] Table Sales (with $ amount)
  - [ ] Bottle Sales (with $ amount)
  - [ ] VIP/Other Sales (with $ amount)
- [ ] Check color-coded indicators for each type
- [ ] Verify percentages add up to 100%

#### 4.3 Revenue by Event
- [ ] View "Revenue by Event" section
- [ ] Verify each event shows:
  - [ ] Event name
  - [ ] Total revenue
  - [ ] Booking count
  - [ ] Revenue date/period
- [ ] Sort events by revenue (if available)
- [ ] Check events with $0 revenue display correctly

#### 4.4 Time Period Filtering
- [ ] Filter by "This Week"
- [ ] Filter by "This Month"
- [ ] Filter by "Last 30 Days"
- [ ] Filter by custom date range (if available)
- [ ] Verify data updates correctly for each filter

#### 4.5 Revenue Analytics
- [ ] Check revenue trends chart (if available)
- [ ] Verify month-over-month comparison
- [ ] Test with different revenue scenarios:
  - [ ] Only ticket sales
  - [ ] Mixed revenue types
  - [ ] Zero revenue events
  - [ ] High volume events (100+ bookings)

#### 4.6 Export Functionality (if implemented)
- [ ] Export revenue report as PDF
- [ ] Export as CSV
- [ ] Verify exported data matches screen display

---

## 5. QR Code Ticket Scanning

**Files to Review:**
- [qr_scanner_screen.dart](lib/features/scanner/screens/qr_scanner_screen.dart)
- [scanner_provider.dart](lib/features/scanner/providers/scanner_provider.dart)
- [booking_model.dart](lib/shared/models/booking_model.dart)

### Test Cases:

#### 5.1 Scanner Screen Access
- [ ] Navigate to event details
- [ ] Tap "Scan Tickets" or QR scanner button
- [ ] Verify camera permission requested
- [ ] Grant camera permission
- [ ] Confirm scanner screen loads with camera preview

#### 5.2 Scanner UI Elements
- [ ] Verify custom QR overlay displays
- [ ] Check scanning statistics at top:
  - [ ] Total tickets
  - [ ] Checked-in count
  - [ ] Pending count
- [ ] Confirm flash toggle button works
- [ ] Verify branded colors (orange accents) display
- [ ] Check "Cancel" or "Back" button present

#### 5.3 QR Code Scanning
- [ ] Generate test QR codes for valid tickets
- [ ] Scan a valid, unscanned ticket:
  - [ ] QR code detected within 2 seconds
  - [ ] Processing indicator displays
  - [ ] Success dialog appears with ticket details
  - [ ] Ticket details show:
    - [ ] Guest name
    - [ ] Ticket type
    - [ ] Booking reference
    - [ ] Check-in timestamp
  - [ ] Statistics update immediately
- [ ] Scan same ticket again:
  - [ ] Verify "Already checked in" message
  - [ ] Show original check-in time
  - [ ] Prevent duplicate check-in

#### 5.4 Error Scenarios
- [ ] Scan invalid QR code:
  - [ ] Verify error message displays
  - [ ] Message is user-friendly
- [ ] Scan QR code for different event:
  - [ ] Verify "Wrong event" error
- [ ] Scan expired ticket:
  - [ ] Verify appropriate error message
- [ ] Scan cancelled booking:
  - [ ] Verify rejection with reason
- [ ] Test in low light conditions
- [ ] Test with damaged/blurry QR codes

#### 5.5 Performance Testing
- [ ] Scan 10 tickets in rapid succession
- [ ] Verify no lag or crashes
- [ ] Check database updates are immediate
- [ ] Test with poor network connection
- [ ] Test offline scanning (if supported)
- [ ] Verify scan queue handling

#### 5.6 Flash and Camera Controls
- [ ] Toggle flash on
- [ ] Verify flash activates
- [ ] Toggle flash off
- [ ] Test camera focus
- [ ] Test on different devices/screen sizes

---

## 6. Sales Analytics Dashboard

**Files to Review:**
- [analytics_dashboard_screen.dart](lib/features/analytics/screens/analytics_dashboard_screen.dart)
- [analytics_provider.dart](lib/features/analytics/providers/analytics_provider.dart)

### Test Cases:

#### 6.1 Dashboard Overview
- [ ] Navigate to Analytics Dashboard
- [ ] View "Overview" tab
- [ ] Verify all KPI cards display:
  - [ ] Total sales ($)
  - [ ] Total bookings (#)
  - [ ] Average order value ($)
  - [ ] Conversion rate (%)

#### 6.2 Booking Trends Visualization
- [ ] View booking trends chart
- [ ] Verify chart displays:
  - [ ] X-axis: Time period (days/weeks)
  - [ ] Y-axis: Booking count or revenue
  - [ ] Line or bar chart rendering
- [ ] Touch chart to see data points
- [ ] Verify tooltips show accurate values
- [ ] Check chart legend is clear

#### 6.3 Quick Statistics
- [ ] View quick stats section
- [ ] Verify metrics display:
  - [ ] Top performing event
  - [ ] Best selling ticket type
  - [ ] Peak sales time
  - [ ] Growth percentage
- [ ] Check calculations are accurate

#### 6.4 Sales Progress Indicators
- [ ] View sales goals (if set)
- [ ] Verify progress bars show correctly
- [ ] Check percentage calculations
- [ ] Test with different goal amounts

#### 6.5 Time-Based Filtering
- [ ] Filter by "Today"
- [ ] Filter by "This Week"
- [ ] Filter by "This Month"
- [ ] Filter by "All Time"
- [ ] Verify all metrics update accordingly
- [ ] Check chart re-renders with new data

#### 6.6 Data Refresh
- [ ] Pull to refresh dashboard
- [ ] Verify data updates from database
- [ ] Check loading indicator displays
- [ ] Test auto-refresh (if enabled)

---

## 7. Scheduled Ticket Releases

**Files to Review:**
- [scheduled_releases_screen.dart](lib/features/events/screens/scheduled_releases_screen.dart)
- [scheduled_releases_provider.dart](lib/features/events/providers/scheduled_releases_provider.dart)

### Test Cases:

#### 7.1 Scheduled Releases Screen Access
- [ ] Navigate to event details
- [ ] Tap "Scheduled Releases" button
- [ ] Verify screen loads with existing releases
- [ ] Confirm "Add Release" button is visible

#### 7.2 Add New Scheduled Release
- [ ] Tap "Add Release" button
- [ ] Verify dialog/form appears with fields:
  - [ ] Release Name (required)
  - [ ] Release Date (date picker)
  - [ ] Release Time (time picker)
  - [ ] Ticket Quantity (number input)
  - [ ] Ticket Price (currency input)
- [ ] Fill all fields
- [ ] Submit form
- [ ] Verify new release appears in list
- [ ] Confirm database entry created

#### 7.3 Release Card Display
- [ ] View release card
- [ ] Verify it shows:
  - [ ] Release name
  - [ ] Release date and time
  - [ ] Ticket quantity
  - [ ] Ticket price
  - [ ] Status badge (Upcoming/Active/Released)
  - [ ] Countdown timer ("Time until release")
- [ ] Check visual styling is consistent

#### 7.4 Countdown Timer
- [ ] Create release for near future (5 minutes)
- [ ] Verify countdown updates in real-time
- [ ] Check format: "2h 30m" or "5m 10s"
- [ ] Verify when time passes:
  - [ ] Status changes to "Released"
  - [ ] Tickets become available
  - [ ] Timer disappears

#### 7.5 Edit Scheduled Release
- [ ] Tap edit icon on a release card
- [ ] Verify form pre-fills with existing data
- [ ] Modify fields:
  - [ ] Change quantity
  - [ ] Adjust price
  - [ ] Update time
- [ ] Save changes
- [ ] Verify updates appear immediately
- [ ] Confirm database updated

#### 7.6 Delete Scheduled Release
- [ ] Tap delete icon on a release card
- [ ] Verify confirmation dialog appears
- [ ] Confirm deletion
- [ ] Verify release removed from list
- [ ] Confirm database entry deleted

#### 7.7 Release Automation
- [ ] Create release scheduled for 1 minute from now
- [ ] Wait for release time to pass
- [ ] Verify tickets automatically become available
- [ ] Check event capacity updates
- [ ] Confirm booking system recognizes new tickets

#### 7.8 Multiple Releases
- [ ] Create 3+ scheduled releases for same event
- [ ] Verify all display correctly
- [ ] Check releases are sorted by date
- [ ] Test overlapping release times
- [ ] Verify each release is independent

---

## 8. Event Performance Insights

**Files to Review:**
- [analytics_dashboard_screen.dart](lib/features/analytics/screens/analytics_dashboard_screen.dart) (Events tab)
- [analytics_provider.dart](lib/features/analytics/providers/analytics_provider.dart)

### Test Cases:

#### 8.1 Event Performance Tab
- [ ] Navigate to Analytics Dashboard
- [ ] Switch to "Events" tab
- [ ] Verify list of events loads

#### 8.2 Performance Metrics Card
- [ ] View performance card for each event
- [ ] Verify metrics display:
  - [ ] Event name and date
  - [ ] Total tickets available
  - [ ] Tickets sold
  - [ ] RSVP count
  - [ ] Checked-in count
  - [ ] Conversion rate (%)
  - [ ] Attendance rate (%)
  - [ ] Revenue per ticket ($)
- [ ] Check metric cards have proper spacing
- [ ] Verify color coding for metrics

#### 8.3 Progress Indicators
- [ ] View conversion rate progress bar:
  - [ ] Shows percentage filled
  - [ ] Color changes based on performance
  - [ ] Label shows exact percentage
- [ ] View attendance rate progress bar:
  - [ ] Accurate percentage
  - [ ] Visual indicator matches value

#### 8.4 Performance Calculations
- [ ] Verify conversion rate formula:
  - [ ] (Sold tickets / Total tickets) × 100
- [ ] Verify attendance rate formula:
  - [ ] (Checked-in / Sold tickets) × 100
- [ ] Check revenue per ticket:
  - [ ] Total revenue / Sold tickets
- [ ] Test edge cases:
  - [ ] Zero sold tickets
  - [ ] Zero checked-in
  - [ ] 100% sold out

#### 8.5 Sales Breakdown
- [ ] View "Sales by Hour" (if available)
- [ ] View "Sales by Day" (if available)
- [ ] Verify charts display correctly
- [ ] Check peak sales times highlighted
- [ ] Verify time zone handling

#### 8.6 Event Comparison
- [ ] Compare performance across multiple events
- [ ] Sort events by:
  - [ ] Conversion rate (highest to lowest)
  - [ ] Revenue (highest to lowest)
  - [ ] Attendance rate (highest to lowest)
- [ ] Identify top and bottom performers
- [ ] Verify sorting is accurate

---

## 9. QR Scanner Mode

**Files to Review:**
- [qr_scanner_screen.dart](lib/features/scanner/screens/qr_scanner_screen.dart)
- [scanner_provider.dart](lib/features/scanner/providers/scanner_provider.dart)

### Test Cases:

#### 9.1 Scanner Mode Activation
- [ ] Access QR Scanner from event details
- [ ] Verify full-screen scanner mode activates
- [ ] Confirm camera preview is full screen
- [ ] Check UI elements are minimal (focused on scanning)

#### 9.2 Scanning Interface
- [ ] View custom QR code overlay:
  - [ ] Square scanning frame
  - [ ] Branded orange corners
  - [ ] "Scan QR Code" instruction text
- [ ] Verify camera is focused and clear
- [ ] Check scanning area is well-lit

#### 9.3 Real-Time Feedback
- [ ] Scan a QR code
- [ ] Verify immediate visual feedback:
  - [ ] Haptic vibration (if supported)
  - [ ] Sound feedback (if enabled)
  - [ ] Visual highlight of scanned code
- [ ] Check result dialog appears within 1 second
- [ ] Verify smooth animations

#### 9.4 Scan Result Display
- [ ] After successful scan, verify dialog shows:
  - [ ] Success icon (checkmark)
  - [ ] Guest name
  - [ ] Ticket type
  - [ ] Booking reference
  - [ ] Check-in timestamp
  - [ ] "Close" or "Scan Next" button
- [ ] Tap "Scan Next" to continue scanning
- [ ] Verify scanner reactivates immediately

#### 9.5 Error Display in Scanner Mode
- [ ] Scan invalid QR code
- [ ] Verify error dialog shows:
  - [ ] Error icon (X or warning)
  - [ ] Clear error message
  - [ ] "Try Again" button
- [ ] Tap "Try Again"
- [ ] Verify scanner reactivates

#### 9.6 Statistics in Scanner Mode
- [ ] View real-time statistics overlay:
  - [ ] Total scans
  - [ ] Successful check-ins
  - [ ] Pending/remaining
- [ ] Verify statistics update after each scan
- [ ] Check statistics are readable over camera preview

#### 9.7 Scanner Controls
- [ ] Toggle flash on/off
- [ ] Verify flash indicator shows status
- [ ] Exit scanner mode
- [ ] Verify camera properly released
- [ ] Re-enter scanner mode
- [ ] Confirm camera reinitializes correctly

#### 9.8 Performance in Scanner Mode
- [ ] Scan 20+ tickets continuously
- [ ] Verify no performance degradation
- [ ] Check memory usage remains stable
- [ ] Test for 30+ minutes of continuous use
- [ ] Verify battery usage is reasonable

---

## Integration Testing

### Cross-Feature Integration

#### Analytics + Scanning Integration
- [ ] Check in guests via QR scanner
- [ ] Verify analytics dashboard updates:
  - [ ] Checked-in count increases
  - [ ] Attendance rate recalculates
  - [ ] Event performance updates
- [ ] Confirm updates are real-time or near real-time

#### Guest List + Scanning Integration
- [ ] Add guest via bulk upload
- [ ] Generate QR code for guest (if system generates)
- [ ] Scan guest's QR code
- [ ] Verify guest list shows "Checked In" status
- [ ] Confirm check-in timestamp matches

#### Scheduled Releases + Sales Analytics Integration
- [ ] Create scheduled ticket release
- [ ] Wait for release to activate
- [ ] Make test purchases of released tickets
- [ ] Verify sales analytics updates:
  - [ ] Booking count increases
  - [ ] Revenue updates
  - [ ] Sales trends chart updates

#### Revenue Reports + Event Performance Integration
- [ ] View revenue breakdown for specific event
- [ ] Compare with event performance metrics
- [ ] Verify revenue per ticket matches
- [ ] Confirm all calculations align

#### Venue Boost + Analytics Integration
- [ ] Activate venue boost
- [ ] Track impressions and clicks
- [ ] Check if boosted venues show in analytics
- [ ] Verify boost impact on bookings (if tracked)

### Navigation Flow Testing
- [ ] Navigate between all features smoothly
- [ ] Verify deep links work:
  - [ ] Direct link to scanner
  - [ ] Direct link to guest list
  - [ ] Direct link to analytics
- [ ] Check back button behavior
- [ ] Test app state preservation
- [ ] Verify bottom navigation maintains state

---

## Performance Testing

### Load Testing
- [ ] Test with 1000+ bookings
- [ ] Test with 500+ guests in guest list
- [ ] Test with 50+ scheduled releases
- [ ] Test with 100+ events in analytics
- [ ] Measure load times for each screen
- [ ] Verify pagination or lazy loading works

### Memory Testing
- [ ] Monitor memory usage during:
  - [ ] CSV upload (large file)
  - [ ] Continuous QR scanning
  - [ ] Analytics chart rendering
  - [ ] Image loading in venue boosts
- [ ] Check for memory leaks
- [ ] Verify app doesn't crash with low memory

### Network Testing
- [ ] Test on 4G connection
- [ ] Test on slow 3G connection
- [ ] Test on WiFi
- [ ] Test offline mode:
  - [ ] Analytics caching
  - [ ] Guest list offline access
  - [ ] Scanner offline queue
- [ ] Test network interruption during:
  - [ ] CSV upload
  - [ ] QR code check-in
  - [ ] Data synchronization

### Battery Testing
- [ ] Monitor battery drain during:
  - [ ] 1 hour of continuous scanning
  - [ ] 30 minutes of analytics viewing
  - [ ] Background data sync
- [ ] Verify power consumption is reasonable

---

## Security Testing

### Authentication & Authorization
- [ ] Verify only authenticated vendors can access features
- [ ] Test role-based access (if implemented)
- [ ] Check event ownership validation:
  - [ ] Can't access other vendors' events
  - [ ] Can't scan tickets for other events
  - [ ] Can't view other vendors' analytics

### Data Validation
- [ ] Test SQL injection attempts in:
  - [ ] Guest list search
  - [ ] Event filters
  - [ ] CSV upload
- [ ] Test XSS attempts in:
  - [ ] Guest names
  - [ ] Event names
  - [ ] Notes fields
- [ ] Verify input sanitization works

### QR Code Security
- [ ] Test QR code forgery detection
- [ ] Verify ticket codes are unique
- [ ] Check if expired codes are rejected
- [ ] Test duplicate QR code handling
- [ ] Verify secure QR code generation (if applicable)

### File Upload Security
- [ ] Upload CSV with malicious content
- [ ] Upload non-CSV file as CSV
- [ ] Upload extremely large file (>10MB)
- [ ] Test file type validation
- [ ] Verify virus scanning (if implemented)

---

## Edge Cases & Error Handling

### Empty States
- [ ] Analytics with no bookings
- [ ] Guest list with no guests
- [ ] No scheduled releases
- [ ] No active venue boosts
- [ ] No inquiries
- [ ] Test appropriate empty state messages display

### Boundary Conditions
- [ ] Event with 0 tickets
- [ ] Event with 10,000+ tickets
- [ ] Price of $0.00
- [ ] Price of $999,999.99
- [ ] Release scheduled 1 year in future
- [ ] Release scheduled for past date (should error)

### Concurrent Operations
- [ ] Two scanners checking in same ticket simultaneously
- [ ] Multiple CSVs uploaded at once
- [ ] Editing release while it's activating
- [ ] Deleting event with active scanner

### Data Consistency
- [ ] Verify database transactions are atomic
- [ ] Check for race conditions in check-ins
- [ ] Test data synchronization across devices
- [ ] Verify optimistic UI updates rollback on error

---

## Platform-Specific Testing

### iOS Testing
- [ ] Test on iPhone (various models)
- [ ] Test on iPad
- [ ] Verify camera permissions work
- [ ] Check file picker integration
- [ ] Test dark mode
- [ ] Verify safe area handling
- [ ] Test haptic feedback

### Android Testing
- [ ] Test on Android phones (various manufacturers)
- [ ] Test on Android tablets
- [ ] Verify camera permissions
- [ ] Check file picker integration
- [ ] Test different Android versions (10, 11, 12, 13+)
- [ ] Verify back button behavior
- [ ] Test with different screen sizes

### Web Testing (if applicable)
- [ ] Test on Chrome
- [ ] Test on Firefox
- [ ] Test on Safari
- [ ] Verify responsive design
- [ ] Test file upload in browser
- [ ] Check camera access in browser

---

## Accessibility Testing

### Screen Reader
- [ ] Test with TalkBack (Android)
- [ ] Test with VoiceOver (iOS)
- [ ] Verify all elements are labeled
- [ ] Check navigation is logical

### Visual Accessibility
- [ ] Test with large font sizes
- [ ] Verify color contrast ratios (WCAG AA)
- [ ] Check with color blindness simulator
- [ ] Test with display zoom enabled

### Interaction Accessibility
- [ ] Verify touch targets are adequate (44x44pt minimum)
- [ ] Test keyboard navigation (web)
- [ ] Check focus indicators are visible

---

## Final Checklist

### Documentation
- [ ] All features documented in code
- [ ] README updated with new features
- [ ] API documentation current
- [ ] User guide updated (if applicable)

### Code Quality
- [ ] `flutter analyze` shows no errors
- [ ] `dart format .` applied
- [ ] No TODO comments left in production code
- [ ] Code follows Flutter best practices

### Build Verification
- [ ] `flutter build apk` succeeds
- [ ] `flutter build appbundle` succeeds
- [ ] `flutter build ios` succeeds (if on macOS)
- [ ] `flutter build web` succeeds (if applicable)
- [ ] APK/IPA file sizes are reasonable

### Deployment Readiness
- [ ] Environment variables configured
- [ ] Firebase configuration verified
- [ ] Supabase connection tested
- [ ] API keys secured
- [ ] Analytics tracking configured
- [ ] Error reporting configured (Crashlytics/Sentry)

### User Acceptance
- [ ] Demo to stakeholders completed
- [ ] Feedback collected and addressed
- [ ] User testing completed
- [ ] Sign-off obtained

---

## Known Issues Log

Document any issues found during validation:

| Issue # | Feature | Description | Severity | Status | Notes |
|---------|---------|-------------|----------|--------|-------|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |

---

## Sign-Off

- [ ] All critical features validated
- [ ] All high-priority bugs fixed
- [ ] Performance is acceptable
- [ ] Security review passed
- [ ] Ready for production deployment

**Validated by:** ___________________
**Date:** ___________________
**Version:** ___________________
