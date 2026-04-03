# Bottles Up - Strategic Implementation Roadmap

## 🎯 Strategic Execution Plan

This document breaks down the PROJECT_PLAN.md into actionable, bite-sized tasks organized by priority, dependencies, and logical workflow.

---

## 📋 Task Categories

### 🔴 **CRITICAL PATH** - Core functionality required for MVP
### 🟡 **HIGH PRIORITY** - Essential features needed for launch
### 🟢 **MEDIUM PRIORITY** - Important but can be deferred
### 🔵 **LOW PRIORITY** - Nice-to-have features

---

## Phase 0: Infrastructure Setup (Week 1)

### Task 0.1: Supabase Project Initialization 🔴
**Duration:** 2-3 hours
**Dependencies:** None
**Deliverables:**
- [ ] Create Supabase project
- [ ] Configure project settings
- [ ] Set up database connection
- [ ] Create `.env` file with Supabase credentials
- [ ] Update `lib/main.dart` with Supabase initialization

**Files to Create/Update:**
- `.env`
- `lib/core/config/supabase_config.dart`
- `lib/main.dart`

---

### Task 0.2: Database Schema - Core Tables (Part 1) 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 0.1
**Deliverables:**
- [ ] Create `vendors` table with RLS policies
- [ ] Create `venues` table with RLS policies
- [ ] Create `events` table with RLS policies
- [ ] Create `bookings` table with RLS policies
- [ ] Set up authentication trigger to create vendor profile

**SQL Migration File:** `supabase/migrations/001_core_tables_part1.sql`

**RLS Policies:**
```sql
-- vendors table
- SELECT: auth.uid() = id
- UPDATE: auth.uid() = id
- INSERT: authenticated users only

-- venues table
- SELECT: owner_id = auth.uid() OR public venues
- UPDATE/DELETE: owner_id = auth.uid()

-- events table
- SELECT: organizer_id = auth.uid() OR venue owner
- UPDATE/DELETE: organizer_id = auth.uid()

-- bookings table
- SELECT: event organizer OR venue owner
- INSERT: authenticated users
```

---

### Task 0.3: Database Schema - Core Tables (Part 2) 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 0.2
**Deliverables:**
- [ ] Create `bottles` table with RLS policies
- [ ] Create `bottle_orders` table with RLS policies
- [ ] Create `team_members` table with RLS policies
- [ ] Create `transactions` table with RLS policies
- [ ] Create `notifications` table with RLS policies

**SQL Migration File:** `supabase/migrations/002_core_tables_part2.sql`

---

### Task 0.4: Database Schema - Supporting Tables 🟡
**Duration:** 2-3 hours
**Dependencies:** Task 0.3
**Deliverables:**
- [ ] Create `promo_codes` table with RLS policies
- [ ] Create `collaborations` table with RLS policies
- [ ] Create `payouts` table with RLS policies
- [ ] Create `shifts` table with RLS policies
- [ ] Create `venue_requests` table with RLS policies
- [ ] Create `reviews` table with RLS policies
- [ ] Create `analytics_events` table

**SQL Migration File:** `supabase/migrations/003_supporting_tables.sql`

---

### Task 0.5: Database Views & Functions 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 0.3, Task 0.4
**Deliverables:**
- [ ] Create `dashboard_metrics` view
- [ ] Create `event_sales_summary` view
- [ ] Create `promoter_performance` view
- [ ] Create `low_stock_bottles` view
- [ ] Create `calculate_revenue_split()` function
- [ ] Create `check_promo_code()` function
- [ ] Create `update_bottle_stock()` function

**SQL Migration File:** `supabase/migrations/004_views_and_functions.sql`

---

### Task 0.6: Supabase Storage Buckets 🔴
**Duration:** 1 hour
**Dependencies:** Task 0.1
**Deliverables:**
- [ ] Create `flyers` bucket (public)
- [ ] Create `venue-photos` bucket (public)
- [ ] Create `license-documents` bucket (private)
- [ ] Create `vendor-logos` bucket (public)
- [ ] Set up storage policies

---

### Task 0.7: Core Services Setup 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 0.1
**Deliverables:**
- [ ] Create `SupabaseService` - base service class
- [ ] Create `RealtimeService` - real-time subscriptions
- [ ] Create `StorageService` - file upload/download
- [ ] Create `AuthService` - authentication wrapper
- [ ] Add dependency injection setup

**Files to Create:**
- `lib/shared/services/supabase_service.dart`
- `lib/shared/services/realtime_service.dart`
- `lib/shared/services/storage_service.dart`
- `lib/shared/services/auth_service.dart`
- `lib/core/di/service_locator.dart`

---

### Task 0.8: Freezed Models - Core Entities 🔴
**Duration:** 3-4 hours
**Dependencies:** None
**Deliverables:**
- [ ] Create `Vendor` model
- [ ] Create `Venue` model
- [ ] Create `Event` model
- [ ] Create `Booking` model
- [ ] Run code generation

**Files to Create:**
- `lib/shared/models/vendor.dart`
- `lib/shared/models/venue.dart`
- `lib/shared/models/event.dart`
- `lib/shared/models/booking.dart`

**Commands:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

### Task 0.9: Freezed Models - Supporting Entities 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 0.8
**Deliverables:**
- [ ] Create `Bottle` model
- [ ] Create `BottleOrder` model
- [ ] Create `TeamMember` model
- [ ] Create `PromoCode` model
- [ ] Create `Transaction` model
- [ ] Create `Notification` model
- [ ] Create `Payout` model
- [ ] Run code generation

**Files to Create:**
- `lib/shared/models/bottle.dart`
- `lib/shared/models/bottle_order.dart`
- `lib/shared/models/team_member.dart`
- `lib/shared/models/promo_code.dart`
- `lib/shared/models/transaction.dart`
- `lib/shared/models/notification.dart`
- `lib/shared/models/payout.dart`

---

### Task 0.10: Common Widgets Library 🔴
**Duration:** 4-5 hours
**Dependencies:** None
**Deliverables:**
- [ ] Create `LoadingIndicator`
- [ ] Create `ErrorView`
- [ ] Create `EmptyState`
- [ ] Create `CustomButton`
- [ ] Create `CustomTextField`
- [ ] Create `CustomCard`
- [ ] Create `CustomAppBar`

**Files to Create:**
- `lib/shared/widgets/common/loading_indicator.dart`
- `lib/shared/widgets/common/error_view.dart`
- `lib/shared/widgets/common/empty_state.dart`
- `lib/shared/widgets/common/custom_button.dart`
- `lib/shared/widgets/common/custom_text_field.dart`
- `lib/shared/widgets/common/custom_card.dart`
- `lib/shared/widgets/common/custom_app_bar.dart`

---

## Phase 1: Authentication & Onboarding (Week 2)

### Task 1.1: Enhanced Authentication Flow 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 0.1, Task 0.7, Task 0.8
**Deliverables:**
- [ ] Update login screen with Supabase integration
- [ ] Update sign up screen with Supabase integration
- [ ] Implement email verification flow
- [ ] Implement password reset flow
- [ ] Add Google OAuth (optional)
- [ ] Create auth state provider

**Files to Update:**
- `lib/features/auth/screens/login_screen.dart`
- `lib/features/auth/screens/register_screen.dart`
- `lib/features/auth/screens/forgot_password_screen.dart`
- `lib/features/auth/providers/auth_provider.dart`

---

### Task 1.2: Role Selection Enhancement 🔴
**Duration:** 2 hours
**Dependencies:** Task 1.1
**Deliverables:**
- [ ] Update role selection UI
- [ ] Add role descriptions
- [ ] Store selected role in vendor profile
- [ ] Navigate to appropriate onboarding flow

**Files to Update:**
- `lib/features/auth/screens/role_selection_screen.dart`

---

### Task 1.3: Venue Owner Onboarding 🔴
**Duration:** 5-6 hours
**Dependencies:** Task 1.2, Task 0.6
**Deliverables:**
- [ ] Create multi-step wizard UI
- [ ] Step 1: Business information
- [ ] Step 2: License document upload
- [ ] Step 3: Stripe Connect onboarding
- [ ] Step 4: Venue photos/gallery
- [ ] Step 5: Basic floorplan (drag-drop later)
- [ ] Save to Supabase on completion

**Files to Create:**
- `lib/features/auth/screens/onboarding/venue_onboarding_screen.dart`
- `lib/features/auth/widgets/onboarding/progress_indicator.dart`
- `lib/features/auth/widgets/onboarding/business_info_step.dart`
- `lib/features/auth/widgets/onboarding/license_upload_step.dart`
- `lib/features/auth/widgets/onboarding/stripe_step.dart`
- `lib/features/auth/widgets/onboarding/gallery_step.dart`
- `lib/features/auth/providers/onboarding_provider.dart`

---

### Task 1.4: Organizer Onboarding 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 1.2
**Deliverables:**
- [ ] Organization details form
- [ ] Payout setup (Stripe Connect)
- [ ] Social media links
- [ ] Profile photo upload
- [ ] Save to Supabase

**Files to Create:**
- `lib/features/auth/screens/onboarding/organizer_onboarding_screen.dart`
- `lib/features/auth/widgets/onboarding/org_details_step.dart`
- `lib/features/auth/widgets/onboarding/payout_step.dart`
- `lib/features/auth/widgets/onboarding/socials_step.dart`

---

### Task 1.5: Promoter Onboarding 🟡
**Duration:** 2-3 hours
**Dependencies:** Task 1.2
**Deliverables:**
- [ ] Invite link validation
- [ ] Promo code generation
- [ ] Basic dashboard setup
- [ ] Commission structure display

**Files to Create:**
- `lib/features/auth/screens/onboarding/promoter_onboarding_screen.dart`

---

### Task 1.6: Staff Onboarding 🟡
**Duration:** 2 hours
**Dependencies:** Task 1.2
**Deliverables:**
- [ ] Limited role setup
- [ ] Venue/organizer assignment
- [ ] Basic profile information
- [ ] ID verification (optional)

**Files to Create:**
- `lib/features/auth/screens/onboarding/staff_onboarding_screen.dart`

---

## Phase 2: Navigation & Router (Week 2)

### Task 2.1: Update App Router 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 1.1
**Deliverables:**
- [ ] Add routes for all main screens
- [ ] Implement auth guard
- [ ] Add role-based route access
- [ ] Set up deep linking structure

**Routes to Add:**
```dart
/dashboard
/events
/events/:id
/events/create
/venue-hub
/venue-hub/profile
/venue-hub/bottles
/venue-hub/requests
/bookings
/bookings/orders
/bookings/tables
/earnings
/team
/team/invite
/team/shifts
/collaborations
/marketing
/marketing/promo-codes
/marketing/broadcasts
/feedback
/notifications
/settings
/settings/profile
/settings/payout
/settings/integrations
/settings/security
```

**Files to Update:**
- `lib/core/router/app_router.dart`
- `lib/core/router/route_guards.dart`

---

### Task 2.2: Bottom Navigation Bar 🔴
**Duration:** 2-3 hours
**Dependencies:** Task 2.1
**Deliverables:**
- [ ] Create custom bottom nav bar
- [ ] Add icons and labels
- [ ] Implement navigation logic
- [ ] Add active state styling

**Tabs:**
- 🏠 Dashboard
- 🎉 Events
- 🏢 Venue Hub (conditional)
- 💸 Earnings
- ☰ More

**Files to Create:**
- `lib/shared/widgets/navigation/bottom_nav_bar.dart`

---

### Task 2.3: More Drawer 🔴
**Duration:** 2 hours
**Dependencies:** Task 2.2
**Deliverables:**
- [ ] Create drawer widget
- [ ] Add menu items
- [ ] Implement navigation
- [ ] Add logout functionality

**Menu Items:**
- Team
- Collaborations
- Marketing
- Feedback
- Notifications
- Settings

**Files to Create:**
- `lib/shared/widgets/navigation/more_drawer.dart`

---

### Task 2.4: Web Sidebar Navigation 🟢
**Duration:** 3 hours
**Dependencies:** Task 2.1
**Deliverables:**
- [ ] Create responsive sidebar
- [ ] Add all menu items
- [ ] Implement collapsible sections
- [ ] Add active state

**Files to Create:**
- `lib/shared/widgets/navigation/side_nav_rail.dart`

---

## Phase 3: Dashboard (Week 3)

### Task 3.1: Dashboard Provider 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 0.5, Task 0.8
**Deliverables:**
- [ ] Create dashboard provider with Riverpod
- [ ] Fetch metrics from `dashboard_metrics` view
- [ ] Implement real-time updates
- [ ] Add error handling and loading states

**Files to Create:**
- `lib/features/dashboard/providers/dashboard_provider.dart`

---

### Task 3.2: Metric Cards 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 3.1
**Deliverables:**
- [ ] Create reusable metric card widget
- [ ] Display: Total Sales, Active Events, Pending Payouts
- [ ] Display: Pre-orders, Love Bottles, Low Stock
- [ ] Add trend indicators (up/down arrows)
- [ ] Add loading skeletons

**Files to Create:**
- `lib/features/dashboard/widgets/metric_card.dart`
- `lib/features/dashboard/widgets/metrics_grid.dart`

---

### Task 3.3: Quick Actions 🔴
**Duration:** 2 hours
**Dependencies:** Task 2.1
**Deliverables:**
- [ ] Create quick action card widget
- [ ] Add actions: Create Event, View Bookings, Manage Bottles, Send Broadcast
- [ ] Implement navigation on tap
- [ ] Add icons and styling

**Files to Create:**
- `lib/features/dashboard/widgets/quick_action_card.dart`
- `lib/features/dashboard/widgets/quick_actions_grid.dart`

---

### Task 3.4: Activity Feed 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 3.1, Task 0.9
**Deliverables:**
- [ ] Fetch recent transactions
- [ ] Create activity feed item widget
- [ ] Display: Bookings, Payouts, Promo usage
- [ ] Add real-time updates
- [ ] Implement pull-to-refresh

**Files to Create:**
- `lib/features/dashboard/widgets/activity_feed.dart`
- `lib/features/dashboard/widgets/activity_feed_item.dart`

---

### Task 3.5: Analytics Charts 🟡
**Duration:** 4-5 hours
**Dependencies:** Task 3.1
**Deliverables:**
- [ ] Create line chart for revenue trend
- [ ] Create bar chart for event performance
- [ ] Create pie chart for revenue breakdown
- [ ] Add date range selector
- [ ] Implement data aggregation

**Files to Create:**
- `lib/features/dashboard/widgets/analytics_chart.dart`
- `lib/shared/widgets/charts/line_chart.dart`
- `lib/shared/widgets/charts/bar_chart.dart`
- `lib/shared/widgets/charts/pie_chart.dart`

---

### Task 3.6: Empty State 🔴
**Duration:** 1 hour
**Dependencies:** Task 3.1
**Deliverables:**
- [ ] Create empty state for new users
- [ ] Add "Create Event" CTA button
- [ ] Add onboarding tips

**Files to Update:**
- `lib/features/dashboard/screens/dashboard_screen.dart`

---

## Phase 4: Events Module - Part 1 (Week 4)

### Task 4.1: Events Provider 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 0.8
**Deliverables:**
- [ ] Create events provider with Riverpod
- [ ] Fetch events from Supabase
- [ ] Implement filtering (Active, Drafts, Past, Templates)
- [ ] Add search functionality
- [ ] Add pagination

**Files to Create:**
- `lib/features/events/providers/events_provider.dart`

---

### Task 4.2: Events List Screen 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 4.1
**Deliverables:**
- [ ] Create tabbed interface
- [ ] Implement event cards
- [ ] Add search bar
- [ ] Add filter chips
- [ ] Add FAB for "Create Event"

**Files to Update:**
- `lib/features/events/screens/events_list_screen.dart`

**Files to Create:**
- `lib/features/events/widgets/event_card.dart`
- `lib/features/events/widgets/event_filters.dart`

---

### Task 4.3: Event Card Component 🔴
**Duration:** 2-3 hours
**Dependencies:** Task 4.2
**Deliverables:**
- [ ] Display flyer image
- [ ] Show venue, date, time
- [ ] Display sales progress bar
- [ ] Show revenue amount
- [ ] Add status badge (Draft, Active, Completed)
- [ ] Implement tap navigation

**Files to Create:**
- `lib/features/events/widgets/event_card.dart`

---

### Task 4.4: Create Event Wizard - Setup 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 2.1
**Deliverables:**
- [ ] Create wizard navigation structure
- [ ] Implement step indicator
- [ ] Add Next/Previous navigation
- [ ] Implement form state management
- [ ] Add validation

**Files to Create:**
- `lib/features/events/screens/create_event/create_event_wizard.dart`
- `lib/features/events/providers/create_event_provider.dart`
- `lib/features/events/widgets/wizard_step_indicator.dart`

---

### Task 4.5: Event Wizard - Basics Step 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 4.4
**Deliverables:**
- [ ] Event title and description
- [ ] Date and time picker
- [ ] Venue selection (for organizers)
- [ ] Flyer image upload
- [ ] Category selection

**Files to Create:**
- `lib/features/events/screens/create_event/steps/basics_step.dart`
- `lib/shared/widgets/forms/image_picker_field.dart`
- `lib/shared/widgets/forms/date_time_picker_field.dart`

---

### Task 4.6: Event Wizard - Tickets Step 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 4.4
**Deliverables:**
- [ ] Add/remove ticket types
- [ ] Configure pricing and quantity
- [ ] Set early bird pricing
- [ ] Add ticket descriptions
- [ ] Validation logic

**Files to Create:**
- `lib/features/events/screens/create_event/steps/tickets_step.dart`
- `lib/features/events/widgets/ticket_type_form.dart`

---

### Task 4.7: Event Wizard - Tables Step 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 4.4
**Deliverables:**
- [ ] Add/remove table types
- [ ] Configure capacity and pricing
- [ ] Add table benefits
- [ ] Minimum spend configuration
- [ ] Validation logic

**Files to Create:**
- `lib/features/events/screens/create_event/steps/tables_step.dart`
- `lib/features/events/widgets/table_type_form.dart`

---

## Phase 5: Events Module - Part 2 (Week 5)

### Task 5.1: Event Wizard - Bottles Step 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 4.4
**Deliverables:**
- [ ] Select bottles from venue inventory
- [ ] Configure event-specific pricing
- [ ] Set minimum order quantities
- [ ] Enable/disable bottles for event

**Files to Create:**
- `lib/features/events/screens/create_event/steps/bottles_step.dart`
- `lib/features/events/widgets/bottle_selector.dart`

---

### Task 5.2: Event Wizard - Team Step 🟡
**Duration:** 2-3 hours
**Dependencies:** Task 4.4
**Deliverables:**
- [ ] Assign team members to event
- [ ] Set roles (Door, Bottle Service, etc.)
- [ ] Configure shift times
- [ ] Add special instructions

**Files to Create:**
- `lib/features/events/screens/create_event/steps/team_step.dart`
- `lib/features/events/widgets/team_assignment.dart`

---

### Task 5.3: Event Wizard - Publish Step 🔴
**Duration:** 2-3 hours
**Dependencies:** Task 4.4
**Deliverables:**
- [ ] Review all event details
- [ ] Preview flyer
- [ ] Set event visibility (Public/Private)
- [ ] Save as draft or publish
- [ ] Submit to Supabase

**Files to Create:**
- `lib/features/events/screens/create_event/steps/publish_step.dart`
- `lib/features/events/widgets/event_preview.dart`

---

### Task 5.4: Event Detail Screen 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 4.1
**Deliverables:**
- [ ] Create tabbed interface
- [ ] Overview tab header with flyer and stats
- [ ] Tab bar navigation
- [ ] Edit and delete actions
- [ ] Share functionality

**Files to Create:**
- `lib/features/events/screens/event_detail_screen.dart`

---

### Task 5.5: Event Overview Tab 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 5.4
**Deliverables:**
- [ ] Event details display
- [ ] Real-time stats cards
- [ ] Recent bookings list
- [ ] Check-in progress
- [ ] QR code for event

**Files to Create:**
- `lib/features/events/widgets/event_overview_tab.dart`
- `lib/features/events/widgets/event_stats_card.dart`

---

### Task 5.6: Event Sales Tab 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 5.4
**Deliverables:**
- [ ] Revenue breakdown chart
- [ ] Sales by type (Tickets, Tables, Bottles)
- [ ] Sales timeline
- [ ] Promo code performance

**Files to Create:**
- `lib/features/events/widgets/event_sales_tab.dart`

---

### Task 5.7: Event Tickets/Tables/Bottles Tabs 🟡
**Duration:** 4-5 hours
**Dependencies:** Task 5.4
**Deliverables:**
- [ ] Display ticket types and sales
- [ ] Display table bookings
- [ ] Display bottle orders
- [ ] Quick edit functionality
- [ ] Export data

**Files to Create:**
- `lib/features/events/widgets/event_tickets_tab.dart`
- `lib/features/events/widgets/event_tables_tab.dart`
- `lib/features/events/widgets/event_bottles_tab.dart`

---

### Task 5.8: Check-In Screen 🔴
**Duration:** 5-6 hours
**Dependencies:** Task 5.4
**Deliverables:**
- [ ] QR code scanner
- [ ] Manual search and check-in
- [ ] Display booking details on scan
- [ ] Valid/Invalid/Already scanned states
- [ ] Check-in history
- [ ] Offline support

**Files to Create:**
- `lib/features/events/screens/check_in_screen.dart`
- `lib/features/events/widgets/qr_scanner_widget.dart`
- `lib/features/events/widgets/manual_check_in.dart`
- `lib/features/events/providers/check_in_provider.dart`

---

### Task 5.9: Guestlist Management 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 5.4
**Deliverables:**
- [ ] Add/remove guests
- [ ] Configure free entry before X time
- [ ] RSVP tracking
- [ ] Guest notes
- [ ] Export guestlist

**Files to Create:**
- `lib/features/events/screens/guestlist_screen.dart`
- `lib/features/events/widgets/guestlist_item.dart`

---

## Phase 6: Venue Hub (Week 6-7)

### Task 6.1: Venue Provider 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 0.8
**Deliverables:**
- [ ] Create venue provider
- [ ] Fetch venue data
- [ ] Update venue information
- [ ] Handle venue status changes

**Files to Create:**
- `lib/features/venues/providers/venue_provider.dart`

---

### Task 6.2: Venue Profile Screen 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 6.1
**Deliverables:**
- [ ] Display venue information
- [ ] Edit venue details
- [ ] Upload/manage license documents
- [ ] Gallery management
- [ ] Social links

**Files to Create:**
- `lib/features/venues/screens/venue_profile_screen.dart`
- `lib/features/venues/widgets/venue_info_card.dart`
- `lib/features/venues/widgets/document_manager.dart`
- `lib/features/venues/widgets/gallery_grid.dart`

---

### Task 6.3: Bottle Menu Screen 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 6.1, Task 0.8
**Deliverables:**
- [ ] List all bottles
- [ ] Add/edit/delete bottles
- [ ] Stock management
- [ ] Low stock alerts
- [ ] Category filtering

**Files to Create:**
- `lib/features/venues/screens/bottle_menu_screen.dart`
- `lib/features/venues/widgets/bottle_list_item.dart`
- `lib/features/venues/widgets/bottle_form.dart`
- `lib/features/venues/providers/bottle_menu_provider.dart`

---

### Task 6.4: Floorplan Editor (Basic) 🟢
**Duration:** 6-8 hours
**Dependencies:** Task 6.1
**Deliverables:**
- [ ] Upload floorplan image
- [ ] Add zone markers (drag-drop)
- [ ] Add table numbers
- [ ] Set capacity limits
- [ ] Save floorplan data

**Files to Create:**
- `lib/features/venues/screens/floorplan_editor_screen.dart`
- `lib/features/venues/widgets/floorplan_canvas.dart`
- `lib/features/venues/providers/floorplan_provider.dart`

---

### Task 6.5: Organizer Requests Screen 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 6.1
**Deliverables:**
- [ ] List pending requests
- [ ] View request details
- [ ] Approve/decline actions
- [ ] Chat functionality (basic)
- [ ] Request history

**Files to Create:**
- `lib/features/venues/screens/organizer_requests_screen.dart`
- `lib/features/venues/widgets/request_card.dart`
- `lib/features/venues/widgets/request_detail_modal.dart`

---

### Task 6.6: Live Ops Screen 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 6.1, Task 0.7
**Deliverables:**
- [ ] Real-time orders queue
- [ ] Pre-orders display
- [ ] Love Bottles tracking
- [ ] Staff assignment
- [ ] Order status updates

**Files to Create:**
- `lib/features/venues/screens/live_ops_screen.dart`
- `lib/features/venues/widgets/live_order_card.dart`

---

### Task 6.7: Venue Directory (Organizer Mode) 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 6.1
**Deliverables:**
- [ ] Browse venues
- [ ] Filter by city, capacity, amenities
- [ ] Search functionality
- [ ] View venue details

**Files to Create:**
- `lib/features/venues/screens/venue_directory_screen.dart`
- `lib/features/venues/widgets/venue_card.dart`
- `lib/features/venues/widgets/venue_filter.dart`

---

### Task 6.8: Venue Proposal Screen 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 6.7
**Deliverables:**
- [ ] Create proposal form
- [ ] Attach event flyer
- [ ] Add expected attendance
- [ ] Special requirements
- [ ] Submit proposal

**Files to Create:**
- `lib/features/venues/screens/venue_proposal_screen.dart`
- `lib/features/venues/widgets/proposal_form.dart`

---

## Phase 7: Bookings & Orders (Week 8)

### Task 7.1: Orders Provider 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 0.8, Task 0.9
**Deliverables:**
- [ ] Create orders provider
- [ ] Fetch bookings and bottle orders
- [ ] Filter by type and status
- [ ] Real-time updates subscription
- [ ] Update order status

**Files to Create:**
- `lib/features/bookings/providers/orders_provider.dart`
- `lib/features/bookings/providers/live_orders_provider.dart`

---

### Task 7.2: Orders Queue Screen 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 7.1
**Deliverables:**
- [ ] Create tabbed interface
- [ ] Tabs: Tables, Tickets, Pre-Orders, Love Bottles, Live Bottles
- [ ] Real-time order updates
- [ ] Filter and search
- [ ] Pull-to-refresh

**Files to Create:**
- `lib/features/bookings/screens/orders_queue_screen.dart`

---

### Task 7.3: Order Card Component 🔴
**Duration:** 2-3 hours
**Dependencies:** Task 7.2
**Deliverables:**
- [ ] Display order details
- [ ] Status badge
- [ ] Assign staff action
- [ ] Update status buttons
- [ ] Customer information

**Files to Create:**
- `lib/features/bookings/widgets/order_card.dart`

---

### Task 7.4: Order Status Flow 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 7.1
**Deliverables:**
- [ ] Status progression: Pending → Assigned → En-route → Delivered
- [ ] Staff assignment modal
- [ ] Push notification to staff
- [ ] Timestamp tracking
- [ ] Status history

**Files to Create:**
- `lib/features/bookings/widgets/order_status_flow.dart`
- `lib/features/bookings/widgets/staff_assignment_modal.dart`

---

### Task 7.5: Table Management 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 7.1
**Deliverables:**
- [ ] View table bookings
- [ ] Edit table assignments
- [ ] Upgrade table
- [ ] Cancel/refund
- [ ] Add-ons management

**Files to Create:**
- `lib/features/bookings/screens/table_management_screen.dart`
- `lib/features/bookings/widgets/table_booking_card.dart`

---

### Task 7.6: Love Bottles Feature ❤️ 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 7.1
**Deliverables:**
- [ ] Send love bottle interface
- [ ] Select recipient table
- [ ] Add personal message
- [ ] Assign delivery staff
- [ ] Delivery confirmation

**Files to Create:**
- `lib/features/bookings/screens/love_bottles_screen.dart`
- `lib/features/bookings/widgets/love_bottle_form.dart`
- `lib/features/bookings/widgets/love_bottle_card.dart`

---

## Phase 8: Earnings (Week 9)

### Task 8.1: Earnings Provider 🔴
**Duration:** 3-4 hours
**Dependencies:** Task 0.9
**Deliverables:**
- [ ] Create earnings provider
- [ ] Fetch balance and payouts
- [ ] Fetch transactions
- [ ] Calculate revenue breakdown
- [ ] Date filtering

**Files to Create:**
- `lib/features/earnings/providers/earnings_provider.dart`
- `lib/features/earnings/providers/payouts_provider.dart`

---

### Task 8.2: Earnings Screen 🔴
**Duration:** 4-5 hours
**Dependencies:** Task 8.1
**Deliverables:**
- [ ] Balance summary card
- [ ] Next payout display
- [ ] Revenue trend chart
- [ ] Payout history list
- [ ] Sales ledger

**Files to Create:**
- `lib/features/earnings/screens/earnings_screen.dart`
- `lib/features/earnings/widgets/balance_summary.dart`
- `lib/features/earnings/widgets/payout_history_list.dart`
- `lib/features/earnings/widgets/sales_ledger.dart`
- `lib/features/earnings/widgets/revenue_breakdown_chart.dart`

---

### Task 8.3: Payout Details 🟡
**Duration:** 2-3 hours
**Dependencies:** Task 8.1
**Deliverables:**
- [ ] View payout breakdown
- [ ] Download statement (PDF)
- [ ] View Stripe transfer details
- [ ] Transaction list for payout period

**Files to Create:**
- `lib/features/earnings/screens/payout_detail_screen.dart`

---

### Task 8.4: Commission Tracking 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 8.1
**Deliverables:**
- [ ] Promoter commissions
- [ ] Bottle delivery commissions
- [ ] Pending approvals
- [ ] Commission payout

**Files to Create:**
- `lib/features/earnings/widgets/commission_tracker.dart`

---

## Phase 9: Team Management (Week 10)

### Task 9.1: Team Provider 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 0.9
**Deliverables:**
- [ ] Create team provider
- [ ] Fetch team members
- [ ] Invite members
- [ ] Update roles and permissions
- [ ] Remove members

**Files to Create:**
- `lib/features/team/providers/team_provider.dart`

---

### Task 9.2: Team List Screen 🟡
**Duration:** 3-4 hours
**Dependencies:** Task 9.1
**Deliverables:**
- [ ] List team members
- [ ] Filter by role
- [ ] Search functionality
- [ ] Role badges
- [ ] Add member FAB

**Files to Create:**
- `lib/features/team/screens/team_list_screen.dart`
- `lib/features/team/widgets/team_member_card.dart`

---

### Task 9.3: Invite Member Screen 🟡
**Duration:** 2-3 hours
**Dependencies:** Task 9.1
**Deliverables:**
- [ ] Email/phone input
- [ ] Role selection
- [ ] Permission configuration
- [ ] Send invitation
- [ ] Copy invite link

**Files to Create:**
- `lib/features/team/screens/invite_member_screen.dart`
- `lib/features/team/widgets/role_selector.dart`

---

### Task 9.4: Shift Calendar 🟡
**Duration:** 4-5 hours
**Dependencies:** Task 9.1
**Deliverables:**
- [ ] Calendar view
- [ ] Assign staff to events
- [ ] Set shift times
- [ ] Add shift notes
- [ ] Conflict detection

**Files to Create:**
- `lib/features/team/screens/shift_calendar_screen.dart`
- `lib/features/team/widgets/shift_assignment.dart`

---

### Task 9.5: Team Performance 🟢
**Duration:** 3-4 hours
**Dependencies:** Task 9.1
**Deliverables:**
- [ ] Sales by staff member
- [ ] Check-ins by staff
- [ ] Bottle upsells
- [ ] Performance charts

**Files to Create:**
- `lib/features/team/screens/team_performance_screen.dart`

---

## Phase 10: Additional Features (Week 11-15)

### Task 10.1: Collaborations Module 🟢
**Duration:** 6-8 hours
**Deliverables:**
- [ ] List collaborations
- [ ] Create collaboration
- [ ] Revenue split config
- [ ] Permission settings
- [ ] Shared analytics

**Files to Create:**
- `lib/features/collaborations/screens/collaborations_screen.dart`
- `lib/features/collaborations/screens/create_collaboration_screen.dart`
- `lib/features/collaborations/widgets/collaboration_card.dart`
- `lib/features/collaborations/widgets/revenue_split_config.dart`
- `lib/features/collaborations/providers/collaborations_provider.dart`

---

### Task 10.2: Marketing Module 🟡
**Duration:** 8-10 hours
**Deliverables:**
- [ ] Promo codes CRUD
- [ ] Promoter leaderboard
- [ ] Broadcast composer
- [ ] Social shareables
- [ ] Campaign analytics

**Files to Create:**
- `lib/features/marketing/screens/marketing_screen.dart`
- `lib/features/marketing/screens/promo_codes_screen.dart`
- `lib/features/marketing/screens/promoter_leaderboard_screen.dart`
- `lib/features/marketing/screens/broadcasts_screen.dart`
- `lib/features/marketing/providers/marketing_provider.dart`

---

### Task 10.3: Feedback Module 🟢
**Duration:** 6-8 hours
**Deliverables:**
- [ ] Review display
- [ ] Survey builder
- [ ] Rating breakdown
- [ ] Sentiment analysis

**Files to Create:**
- `lib/features/feedback/screens/feedback_screen.dart`
- `lib/features/feedback/screens/survey_builder_screen.dart`
- `lib/features/feedback/widgets/review_card.dart`
- `lib/features/feedback/providers/feedback_provider.dart`

---

### Task 10.4: Notifications Module 🔴
**Duration:** 6-8 hours
**Deliverables:**
- [ ] Notification center
- [ ] Push notification service
- [ ] Category filtering
- [ ] Mark as read
- [ ] Deep linking

**Files to Create:**
- `lib/features/notifications/screens/notifications_screen.dart`
- `lib/features/notifications/widgets/notification_card.dart`
- `lib/features/notifications/services/push_notification_service.dart`
- `lib/features/notifications/providers/notifications_provider.dart`

---

### Task 10.5: Settings Module 🟡
**Duration:** 6-8 hours
**Deliverables:**
- [ ] Business profile
- [ ] Payout setup
- [ ] Integrations
- [ ] Security (2FA)
- [ ] Data controls

**Files to Create:**
- `lib/features/settings/screens/business_profile_screen.dart`
- `lib/features/settings/screens/payout_setup_screen.dart`
- `lib/features/settings/screens/integrations_screen.dart`
- `lib/features/settings/screens/security_screen.dart`
- `lib/features/settings/providers/settings_provider.dart`

---

## 🎯 Suggested Execution Order

### **Sprint 1: Foundation (Week 1)**
1. Task 0.1 → 0.2 → 0.3 → 0.4 → 0.5 → 0.6
2. Task 0.7 → 0.8 → 0.9 → 0.10

### **Sprint 2: Auth & Navigation (Week 2)**
1. Task 1.1 → 1.2 → 1.3 → 1.4
2. Task 2.1 → 2.2 → 2.3
3. Task 1.5 → 1.6 (parallel)

### **Sprint 3: Dashboard (Week 3)**
1. Task 3.1 → 3.2 → 3.3 → 3.6
2. Task 3.4 → 3.5 (parallel)

### **Sprint 4-5: Events Core (Week 4-5)**
1. Task 4.1 → 4.2 → 4.3
2. Task 4.4 → 4.5 → 4.6 → 4.7
3. Task 5.1 → 5.2 → 5.3
4. Task 5.4 → 5.5 → 5.8

### **Sprint 6: Venue Hub (Week 6-7)**
1. Task 6.1 → 6.2 → 6.3
2. Task 6.5 → 6.6
3. Task 6.7 → 6.8 (for organizers)

### **Sprint 7: Bookings (Week 8)**
1. Task 7.1 → 7.2 → 7.3 → 7.4
2. Task 7.6 (Love Bottles ❤️)

### **Sprint 8: Earnings (Week 9)**
1. Task 8.1 → 8.2 → 8.3

### **Sprint 9: Team (Week 10)**
1. Task 9.1 → 9.2 → 9.3 → 9.4

### **Sprint 10: Polish & Additional Features (Week 11-15)**
1. Task 10.4 (Notifications) - High priority
2. Task 10.5 (Settings)
3. Task 10.2 (Marketing)
4. Task 10.1 (Collaborations)
5. Task 10.3 (Feedback)

---

## 📊 Progress Tracking

### MVP Completion Checklist
- [ ] Authentication & Onboarding (Tasks 1.1-1.4)
- [ ] Navigation (Tasks 2.1-2.3)
- [ ] Dashboard (Tasks 3.1-3.6)
- [ ] Events Management (Tasks 4.1-5.3)
- [ ] Check-In System (Task 5.8)
- [ ] Bookings & Orders (Tasks 7.1-7.6)
- [ ] Earnings Tracking (Tasks 8.1-8.2)
- [ ] Notifications (Task 10.4)

### Phase 2 Features
- [ ] Venue Hub (Tasks 6.1-6.8)
- [ ] Team Management (Tasks 9.1-9.4)
- [ ] Settings (Task 10.5)
- [ ] Marketing (Task 10.2)

### Phase 3 Features
- [ ] Collaborations (Task 10.1)
- [ ] Feedback (Task 10.3)
- [ ] Advanced Analytics
- [ ] Web Portal

---

## 🚨 Critical Dependencies

**Must Complete First:**
- Database Schema (Tasks 0.2-0.4)
- Core Services (Task 0.7)
- Freezed Models (Tasks 0.8-0.9)
- Authentication (Task 1.1)

**Can Be Parallelized:**
- UI Components (Task 0.10) while doing database work
- Different feature modules after foundation is complete
- Marketing, Feedback, Collaborations are independent

---

## 💡 Tips for Execution

1. **Start with Critical Path**: Focus on 🔴 tasks first
2. **Test Each Task**: Don't move forward until current task works
3. **Commit Often**: Commit after each task completion
4. **Run Code Generation**: After creating/updating models
5. **Database Migrations**: Test migrations on dev database first
6. **Real-time Testing**: Test Supabase real-time subscriptions early
7. **Responsive Design**: Test on different screen sizes throughout
8. **Error Handling**: Implement proper error states for each feature
9. **Loading States**: Add loading skeletons for better UX
10. **Documentation**: Document complex logic as you build

---

**Last Updated:** 2025-12-19
**Total Estimated Duration:** 15-16 weeks
**MVP Duration:** 8-10 weeks
