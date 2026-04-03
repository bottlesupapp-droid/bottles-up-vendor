# Bottles Up - Vendor App Project Plan

## Overview
Complete implementation plan for the Bottles Up Vendor App, covering Supabase backend architecture and Flutter UI implementation.

---

## 🗄️ Supabase Database Schema

### Core Tables

#### 1. `vendors`
```sql
- id (uuid, primary key)
- email (text, unique)
- phone (text, unique)
- role (enum: venue_owner, organizer, promoter, staff)
- business_name (text)
- logo_url (text)
- stripe_account_id (text)
- onboarding_completed (boolean)
- two_fa_enabled (boolean)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### 2. `venues`
```sql
- id (uuid, primary key)
- owner_id (uuid, foreign key -> vendors)
- name (text)
- address (jsonb)
- license_documents (jsonb array)
- gallery (jsonb array)
- floorplan_data (jsonb)
- capacity (integer)
- status (enum: pending, approved, active, suspended)
- social_links (jsonb)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### 3. `events`
```sql
- id (uuid, primary key)
- venue_id (uuid, foreign key -> venues)
- organizer_id (uuid, foreign key -> vendors)
- title (text)
- description (text)
- flyer_url (text)
- start_time (timestamptz)
- end_time (timestamptz)
- status (enum: draft, published, active, completed, cancelled)
- ticket_config (jsonb)
- table_config (jsonb)
- bottle_config (jsonb)
- guestlist_config (jsonb)
- total_revenue (numeric)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### 4. `bookings`
```sql
- id (uuid, primary key)
- event_id (uuid, foreign key -> events)
- customer_id (uuid)
- type (enum: ticket, table, bottle_preorder)
- booking_data (jsonb)
- amount (numeric)
- status (enum: pending, confirmed, cancelled, refunded)
- promo_code (text)
- checked_in (boolean)
- checked_in_at (timestamptz)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### 5. `bottles`
```sql
- id (uuid, primary key)
- venue_id (uuid, foreign key -> venues)
- name (text)
- category (text)
- price (numeric)
- stock_quantity (integer)
- low_stock_threshold (integer)
- image_url (text)
- is_active (boolean)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### 6. `bottle_orders`
```sql
- id (uuid, primary key)
- event_id (uuid, foreign key -> events)
- booking_id (uuid, foreign key -> bookings, nullable)
- bottle_id (uuid, foreign key -> bottles)
- quantity (integer)
- type (enum: preorder, live, love_bottle)
- table_number (text, nullable)
- recipient_name (text, nullable for love bottles)
- status (enum: pending, assigned, enroute, delivered)
- assigned_staff_id (uuid, nullable)
- amount (numeric)
- created_at (timestamptz)
- delivered_at (timestamptz)
```

#### 7. `team_members`
```sql
- id (uuid, primary key)
- vendor_id (uuid, foreign key -> vendors)
- venue_id (uuid, foreign key -> venues, nullable)
- role (enum: admin, manager, promoter, door, bottle_service, accounting)
- permissions (jsonb)
- email (text)
- phone (text)
- status (enum: invited, active, inactive)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### 8. `shifts`
```sql
- id (uuid, primary key)
- event_id (uuid, foreign key -> events)
- staff_id (uuid, foreign key -> team_members)
- role (text)
- start_time (timestamptz)
- end_time (timestamptz)
- notes (text)
- created_at (timestamptz)
```

#### 9. `promo_codes`
```sql
- id (uuid, primary key)
- code (text, unique)
- event_id (uuid, foreign key -> events, nullable)
- promoter_id (uuid, foreign key -> vendors, nullable)
- discount_type (enum: percentage, fixed)
- discount_value (numeric)
- usage_limit (integer)
- usage_count (integer)
- expires_at (timestamptz)
- is_active (boolean)
- created_at (timestamptz)
```

#### 10. `collaborations`
```sql
- id (uuid, primary key)
- event_id (uuid, foreign key -> events)
- collaborator_id (uuid, foreign key -> vendors)
- revenue_split_percentage (numeric)
- permissions (jsonb)
- status (enum: pending, accepted, declined)
- agreement_signed (boolean)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### 11. `payouts`
```sql
- id (uuid, primary key)
- vendor_id (uuid, foreign key -> vendors)
- amount (numeric)
- stripe_transfer_id (text)
- status (enum: pending, processing, completed, failed)
- period_start (timestamptz)
- period_end (timestamptz)
- statement_url (text)
- created_at (timestamptz)
- completed_at (timestamptz)
```

#### 12. `transactions`
```sql
- id (uuid, primary key)
- vendor_id (uuid, foreign key -> vendors)
- event_id (uuid, foreign key -> events, nullable)
- booking_id (uuid, foreign key -> bookings, nullable)
- bottle_order_id (uuid, foreign key -> bottle_orders, nullable)
- type (enum: ticket_sale, table_booking, bottle_sale, refund, payout)
- amount (numeric)
- fee (numeric)
- net_amount (numeric)
- description (text)
- created_at (timestamptz)
```

#### 13. `venue_requests`
```sql
- id (uuid, primary key)
- venue_id (uuid, foreign key -> venues)
- organizer_id (uuid, foreign key -> vendors)
- event_proposal (jsonb)
- expected_attendance (integer)
- status (enum: pending, approved, declined)
- notes (text)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### 14. `notifications`
```sql
- id (uuid, primary key)
- vendor_id (uuid, foreign key -> vendors)
- category (enum: sales, orders, team, finance, system)
- priority (enum: critical, high, normal, low)
- title (text)
- message (text)
- data (jsonb)
- read (boolean)
- sent_via (jsonb array: in_app, push, email, sms)
- created_at (timestamptz)
```

#### 15. `reviews`
```sql
- id (uuid, primary key)
- event_id (uuid, foreign key -> events)
- customer_id (uuid)
- rating_overall (integer)
- rating_music (integer)
- rating_service (integer)
- rating_atmosphere (integer)
- comment (text)
- is_public (boolean)
- created_at (timestamptz)
```

#### 16. `analytics_events`
```sql
- id (uuid, primary key)
- vendor_id (uuid, foreign key -> vendors)
- event_id (uuid, foreign key -> events, nullable)
- event_type (text)
- properties (jsonb)
- created_at (timestamptz)
```

### Views & Functions

#### Views
- `dashboard_metrics` - Aggregated metrics for dashboard
- `event_sales_summary` - Sales breakdown per event
- `promoter_performance` - Promoter leaderboard data
- `low_stock_bottles` - Bottles below threshold

#### Functions
- `calculate_revenue_split()` - Calculate collaboration splits
- `process_payout()` - Handle payout processing
- `check_promo_code()` - Validate promo code usage
- `update_bottle_stock()` - Decrement stock on order

---

## 🔐 Row Level Security (RLS) Policies

### General Principles
1. Vendors can only see their own data
2. Staff members see data based on role permissions
3. Venue owners see their venue's data
4. Organizers see their events' data
5. Promoters see limited data (events they're assigned to)

### Example Policies
```sql
-- vendors: users can only view/update their own record
CREATE POLICY "Vendors can view own data" ON vendors
  FOR SELECT USING (auth.uid() = id);

-- events: organizers see their events, venue owners see venue events
CREATE POLICY "Event access" ON events
  FOR SELECT USING (
    organizer_id = auth.uid() OR
    venue_id IN (SELECT id FROM venues WHERE owner_id = auth.uid())
  );

-- bookings: accessible by event organizer or venue owner
CREATE POLICY "Booking access" ON bookings
  FOR SELECT USING (
    event_id IN (
      SELECT id FROM events
      WHERE organizer_id = auth.uid()
      OR venue_id IN (SELECT id FROM venues WHERE owner_id = auth.uid())
    )
  );
```

---

## 📡 Supabase Realtime Subscriptions

### Critical Realtime Channels
1. **Live Orders** - `bottle_orders` where status changes
2. **Check-ins** - `bookings` where checked_in updates
3. **Notifications** - `notifications` for vendor_id
4. **Dashboard Metrics** - Subscribe to sales updates during events

---

## 🎨 Flutter UI Implementation Plan

### Phase 1: Foundation (Week 1-2)

#### 1.1 Authentication & Onboarding
**Files to Create/Update:**
- `lib/features/auth/screens/role_selection_screen.dart` ✅ (exists)
- `lib/features/auth/screens/onboarding/venue_onboarding_screen.dart`
- `lib/features/auth/screens/onboarding/organizer_onboarding_screen.dart`
- `lib/features/auth/screens/onboarding/promoter_onboarding_screen.dart`
- `lib/features/auth/screens/onboarding/staff_onboarding_screen.dart`
- `lib/features/auth/providers/onboarding_provider.dart`

**Components:**
- Multi-step wizard with progress indicator
- Document upload widget (license, ID)
- Stripe Connect onboarding integration
- Floorplan upload/editor (basic)

#### 1.2 Navigation Structure
**Files to Update:**
- `lib/core/router/app_router.dart` ✅ (exists)
- `lib/shared/widgets/navigation/bottom_nav_bar.dart`
- `lib/shared/widgets/navigation/side_nav_rail.dart` (for web)
- `lib/shared/widgets/navigation/more_drawer.dart`

**Routes to Add:**
- `/dashboard`
- `/events`
- `/venue-hub`
- `/earnings`
- `/bookings`
- `/team`
- `/collaborations`
- `/marketing`
- `/feedback`
- `/notifications`
- `/settings`

### Phase 2: Dashboard (Week 3)

#### 2.1 Dashboard Screen
**Files to Create:**
- `lib/features/dashboard/screens/dashboard_screen.dart` ✅ (exists)
- `lib/features/dashboard/widgets/metric_card.dart`
- `lib/features/dashboard/widgets/quick_action_card.dart`
- `lib/features/dashboard/widgets/activity_feed.dart`
- `lib/features/dashboard/widgets/analytics_chart.dart`
- `lib/features/dashboard/providers/dashboard_provider.dart`

**Metrics to Display:**
- Total Sales (current period)
- Active Events count
- Pending Payouts amount
- Pre-orders count
- Love Bottles sent
- Low Stock alerts

**Quick Actions:**
- Create Event
- View Bookings
- Manage Bottles
- Send Broadcast

### Phase 3: Events Module (Week 4-5)

#### 3.1 Events List
**Files to Create:**
- `lib/features/events/screens/events_list_screen.dart` ✅ (exists)
- `lib/features/events/widgets/event_card.dart`
- `lib/features/events/widgets/event_filters.dart`
- `lib/features/events/providers/events_provider.dart`

**Features:**
- Tabs: Active | Drafts | Past | Templates
- Filters: City, Date, Status
- Search functionality
- Sort options

#### 3.2 Event Creation Wizard
**Files to Create:**
- `lib/features/events/screens/create_event/create_event_wizard.dart`
- `lib/features/events/screens/create_event/steps/basics_step.dart`
- `lib/features/events/screens/create_event/steps/tickets_step.dart`
- `lib/features/events/screens/create_event/steps/tables_step.dart`
- `lib/features/events/screens/create_event/steps/bottles_step.dart`
- `lib/features/events/screens/create_event/steps/team_step.dart`
- `lib/features/events/screens/create_event/steps/publish_step.dart`
- `lib/features/events/providers/create_event_provider.dart`

**Components:**
- Step progress indicator
- Form validation
- Image upload (flyer)
- Date/time picker
- Pricing configuration
- Team assignment

#### 3.3 Event Detail & Management
**Files to Create:**
- `lib/features/events/screens/event_detail_screen.dart`
- `lib/features/events/widgets/event_overview_tab.dart`
- `lib/features/events/widgets/event_sales_tab.dart`
- `lib/features/events/widgets/event_tickets_tab.dart`
- `lib/features/events/widgets/event_tables_tab.dart`
- `lib/features/events/widgets/event_bottles_tab.dart`
- `lib/features/events/widgets/event_team_tab.dart`
- `lib/features/events/widgets/event_settings_tab.dart`

#### 3.4 Check-In & Guestlist
**Files to Create:**
- `lib/features/events/screens/check_in_screen.dart`
- `lib/features/events/widgets/qr_scanner_widget.dart`
- `lib/features/events/widgets/manual_check_in.dart`
- `lib/features/events/screens/guestlist_screen.dart`
- `lib/features/events/providers/check_in_provider.dart`

**Features:**
- QR code scanning
- Manual search & check-in
- Valid/Invalid/Already scanned states
- Guestlist management (free before X, RSVP)

### Phase 4: Venue Hub (Week 6-7)

#### 4.1 Venue Owner Mode
**Files to Create:**
- `lib/features/venues/screens/venue_profile_screen.dart`
- `lib/features/venues/screens/floorplan_editor_screen.dart`
- `lib/features/venues/screens/bottle_menu_screen.dart`
- `lib/features/venues/screens/organizer_requests_screen.dart`
- `lib/features/venues/screens/live_ops_screen.dart`
- `lib/features/venues/providers/venue_provider.dart`
- `lib/features/venues/providers/floorplan_provider.dart`
- `lib/features/venues/providers/bottle_menu_provider.dart`

**Components:**
- Document upload manager
- Gallery image grid
- Floorplan drag-and-drop editor
- Bottle CRUD operations
- Low stock alerts
- Request approval workflow

#### 4.2 Organizer Mode
**Files to Create:**
- `lib/features/venues/screens/venue_directory_screen.dart`
- `lib/features/venues/screens/venue_detail_screen.dart`
- `lib/features/venues/screens/venue_proposal_screen.dart`
- `lib/features/venues/widgets/venue_card.dart`
- `lib/features/venues/widgets/venue_filter.dart`

**Features:**
- Browse venues with filters
- View venue details
- Send booking proposal
- Track proposal status

### Phase 5: Bookings & Orders (Week 8)

#### 5.1 Orders Management
**Files to Create:**
- `lib/features/bookings/screens/orders_queue_screen.dart`
- `lib/features/bookings/widgets/order_card.dart`
- `lib/features/bookings/widgets/order_status_flow.dart`
- `lib/features/bookings/screens/table_management_screen.dart`
- `lib/features/bookings/screens/love_bottles_screen.dart`
- `lib/features/bookings/providers/orders_provider.dart`
- `lib/features/bookings/providers/live_orders_provider.dart` (realtime)

**Tabs:**
- Tables
- Tickets
- Pre-Orders
- Love Bottles ❤️
- Live Bottles

**Features:**
- Status updates (Assigned → En-route → Delivered)
- Staff assignment
- Push notifications to staff
- Refund processing
- Add-ons management

### Phase 6: Earnings (Week 9)

#### 6.1 Earnings Dashboard
**Files to Create:**
- `lib/features/earnings/screens/earnings_screen.dart`
- `lib/features/earnings/widgets/balance_summary.dart`
- `lib/features/earnings/widgets/payout_history_list.dart`
- `lib/features/earnings/widgets/sales_ledger.dart`
- `lib/features/earnings/widgets/revenue_breakdown_chart.dart`
- `lib/features/earnings/providers/earnings_provider.dart`
- `lib/features/earnings/providers/payouts_provider.dart`

**Features:**
- Balance display (Available, Pending)
- Next payout date
- Payout history with statements
- Sales ledger with filters
- Commission tracking
- Refunds & disputes
- Revenue breakdown (tickets/tables/bottles)

### Phase 7: Team Management (Week 10)

#### 7.1 Team Module
**Files to Create:**
- `lib/features/team/screens/team_list_screen.dart`
- `lib/features/team/screens/invite_member_screen.dart`
- `lib/features/team/screens/shift_calendar_screen.dart`
- `lib/features/team/screens/team_performance_screen.dart`
- `lib/features/team/widgets/team_member_card.dart`
- `lib/features/team/widgets/role_selector.dart`
- `lib/features/team/widgets/shift_assignment.dart`
- `lib/features/team/providers/team_provider.dart`

**Features:**
- Role-based permissions
- Invite via email/phone
- Shift calendar
- Performance reports
- Internal notes

### Phase 8: Collaborations (Week 11)

#### 8.1 Collaborations
**Files to Create:**
- `lib/features/collaborations/screens/collaborations_screen.dart`
- `lib/features/collaborations/screens/create_collaboration_screen.dart`
- `lib/features/collaborations/widgets/collaboration_card.dart`
- `lib/features/collaborations/widgets/revenue_split_config.dart`
- `lib/features/collaborations/widgets/permissions_config.dart`
- `lib/features/collaborations/providers/collaborations_provider.dart`

**Features:**
- Create co-host agreements
- Revenue split configuration
- Permission settings
- Digital agreement signing (future: DocuSign integration)
- Shared analytics view

### Phase 9: Marketing (Week 12)

#### 9.1 Marketing Tools
**Files to Create:**
- `lib/features/marketing/screens/marketing_screen.dart`
- `lib/features/marketing/screens/promo_codes_screen.dart`
- `lib/features/marketing/screens/promoter_leaderboard_screen.dart`
- `lib/features/marketing/screens/broadcasts_screen.dart`
- `lib/features/marketing/widgets/promo_code_form.dart`
- `lib/features/marketing/widgets/promoter_rank_card.dart`
- `lib/features/marketing/widgets/broadcast_composer.dart`
- `lib/features/marketing/providers/marketing_provider.dart`
- `lib/features/marketing/providers/promo_codes_provider.dart`

**Features:**
- Create/manage promo codes
- Promoter leaderboard
- Social shareables (QR codes, IG templates)
- Broadcast messages (Push, Email, SMS)
- Campaign analytics

### Phase 10: Feedback (Week 13)

#### 10.1 Feedback & Reviews
**Files to Create:**
- `lib/features/feedback/screens/feedback_screen.dart`
- `lib/features/feedback/screens/survey_builder_screen.dart`
- `lib/features/feedback/widgets/review_card.dart`
- `lib/features/feedback/widgets/rating_breakdown.dart`
- `lib/features/feedback/widgets/sentiment_chart.dart`
- `lib/features/feedback/providers/feedback_provider.dart`

**Features:**
- Post-event surveys
- Review display (public/private)
- Staff feedback (private only)
- Structured ratings (music, service, atmosphere)
- Sentiment reports

### Phase 11: Notifications (Week 14)

#### 11.1 Notification Center
**Files to Create:**
- `lib/features/notifications/screens/notifications_screen.dart`
- `lib/features/notifications/widgets/notification_card.dart`
- `lib/features/notifications/widgets/notification_filter.dart`
- `lib/features/notifications/providers/notifications_provider.dart`
- `lib/features/notifications/services/push_notification_service.dart`

**Categories:**
- Sales
- Orders
- Team
- Finance
- System

**Features:**
- Unified notification center
- Category filters
- Mark as read
- Priority indicators
- Deep linking to relevant screens

### Phase 12: Settings (Week 15)

#### 12.1 Settings Module
**Files to Update/Create:**
- `lib/features/profile/screens/profile_screen.dart` ✅ (exists)
- `lib/features/settings/screens/business_profile_screen.dart`
- `lib/features/settings/screens/payout_setup_screen.dart`
- `lib/features/settings/screens/integrations_screen.dart`
- `lib/features/settings/screens/security_screen.dart`
- `lib/features/settings/screens/data_controls_screen.dart`
- `lib/features/settings/providers/settings_provider.dart`

**Features:**
- Business profile editing
- Stripe Connect management
- Integrations (Google Calendar, Meta Pixel, Mailchimp, Zapier, WhatsApp)
- 2FA setup
- Device sessions
- Data export
- Account deletion

---

## 🔧 Shared Services & Utilities

### Services to Create
**Files to Create:**
- `lib/shared/services/supabase_service.dart`
- `lib/shared/services/realtime_service.dart`
- `lib/shared/services/storage_service.dart`
- `lib/shared/services/notification_service.dart`
- `lib/shared/services/analytics_service.dart`
- `lib/shared/services/stripe_service.dart`
- `lib/shared/services/qr_service.dart`

### Models to Create
**Files to Create:**
- `lib/shared/models/vendor.dart`
- `lib/shared/models/venue.dart`
- `lib/shared/models/event.dart`
- `lib/shared/models/booking.dart`
- `lib/shared/models/bottle.dart`
- `lib/shared/models/bottle_order.dart`
- `lib/shared/models/team_member.dart`
- `lib/shared/models/promo_code.dart`
- `lib/shared/models/collaboration.dart`
- `lib/shared/models/payout.dart`
- `lib/shared/models/transaction.dart`
- `lib/shared/models/notification.dart`
- `lib/shared/models/review.dart`

### Reusable Widgets
**Files to Create:**
- `lib/shared/widgets/common/loading_indicator.dart`
- `lib/shared/widgets/common/error_view.dart`
- `lib/shared/widgets/common/empty_state.dart`
- `lib/shared/widgets/common/custom_button.dart`
- `lib/shared/widgets/common/custom_text_field.dart`
- `lib/shared/widgets/common/custom_card.dart`
- `lib/shared/widgets/common/custom_app_bar.dart`
- `lib/shared/widgets/charts/line_chart.dart`
- `lib/shared/widgets/charts/bar_chart.dart`
- `lib/shared/widgets/charts/pie_chart.dart`
- `lib/shared/widgets/forms/image_picker_field.dart`
- `lib/shared/widgets/forms/date_time_picker_field.dart`
- `lib/shared/widgets/forms/multi_select_field.dart`

---

## 📦 Dependencies to Add

```yaml
dependencies:
  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Supabase
  supabase_flutter: ^2.5.6

  # UI Components
  flutter_svg: ^2.0.10+1
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  pull_to_refresh: ^2.0.0

  # Charts
  fl_chart: ^0.68.0
  syncfusion_flutter_charts: ^25.1.35

  # QR Code
  qr_code_scanner: ^1.0.1
  qr_flutter: ^4.1.0

  # Image Handling
  image_picker: ^1.0.7
  image_cropper: ^5.0.1

  # File Handling
  file_picker: ^6.2.0
  path_provider: ^2.1.2

  # PDF Generation
  pdf: ^3.10.8
  printing: ^5.12.0

  # CSV
  csv: ^6.0.0

  # Payments
  stripe_flutter: ^10.1.1

  # Push Notifications
  firebase_messaging: ^14.7.19
  flutter_local_notifications: ^17.0.0

  # Deep Linking
  uni_links: ^0.5.1

  # Utilities
  intl: ^0.19.0
  timeago: ^3.6.1
  url_launcher: ^6.2.5
  share_plus: ^7.2.2

dev_dependencies:
  # Code Generation
  build_runner: ^2.4.8
  riverpod_generator: ^2.4.0
  freezed: ^2.4.7
  json_serializable: ^6.7.1
```

---

## 🚀 Implementation Phases Summary

### Phase 1-2: Foundation (Weeks 1-2)
- ✅ Authentication flows
- ✅ Role-based onboarding
- ✅ Navigation structure

### Phase 3: Core Dashboard (Week 3)
- ✅ Metrics display
- ✅ Quick actions
- ✅ Activity feed

### Phase 4-5: Events (Weeks 4-5)
- ✅ Events listing
- ✅ Event creation wizard
- ✅ Event management
- ✅ Check-in system

### Phase 6-7: Venue Hub (Weeks 6-7)
- ✅ Venue management
- ✅ Bottle menu
- ✅ Floorplan editor
- ✅ Organizer requests

### Phase 8: Bookings (Week 8)
- ✅ Orders queue
- ✅ Table management
- ✅ Love Bottles

### Phase 9: Earnings (Week 9)
- ✅ Earnings dashboard
- ✅ Payout tracking
- ✅ Sales ledger

### Phase 10: Team (Week 10)
- ✅ Team management
- ✅ Shift scheduling
- ✅ Performance tracking

### Phase 11: Collaborations (Week 11)
- ✅ Co-host agreements
- ✅ Revenue splits
- ✅ Shared analytics

### Phase 12: Marketing (Week 12)
- ✅ Promo codes
- ✅ Promoter tools
- ✅ Broadcasts

### Phase 13: Feedback (Week 13)
- ✅ Reviews system
- ✅ Surveys
- ✅ Sentiment analysis

### Phase 14: Notifications (Week 14)
- ✅ Notification center
- ✅ Push notifications
- ✅ Email/SMS integration

### Phase 15: Settings (Week 15)
- ✅ Profile management
- ✅ Integrations
- ✅ Security settings

### Phase 16: Web Portal (Week 16)
- ✅ Bulk operations
- ✅ Advanced analytics
- ✅ Admin controls

---

## 🎯 Priority Features (MVP)

### Must Have (Phase 1)
1. ✅ Authentication & role selection
2. ✅ Basic dashboard
3. ✅ Event creation & listing
4. ✅ Bookings management
5. ✅ Check-in system
6. ✅ Basic earnings tracking

### Should Have (Phase 2)
1. ✅ Venue Hub
2. ✅ Bottle inventory
3. ✅ Team management
4. ✅ Promo codes
5. ✅ Notifications

### Nice to Have (Phase 3)
1. ✅ Collaborations
2. ✅ Advanced analytics
3. ✅ Marketing tools
4. ✅ Feedback system
5. ✅ Web portal features

---

## 📊 Success Metrics

### Technical Metrics
- App load time < 3s
- Real-time updates < 1s latency
- 99.9% uptime
- < 5% error rate

### Business Metrics
- Onboarding completion rate > 80%
- Daily active users growth
- Average session duration
- Feature adoption rates

---

## 🔒 Security Checklist

- [x] Row Level Security on all tables
- [ ] API rate limiting
- [ ] Input validation
- [ ] SQL injection prevention
- [ ] XSS protection
- [ ] CSRF tokens
- [ ] Secure file uploads
- [ ] Encrypted sensitive data
- [ ] 2FA implementation
- [ ] Audit logging

---

## 📝 Notes

- Use Freezed for all models
- Implement offline-first approach where possible
- Follow Material Design 3 guidelines
- Maintain dark theme consistency
- Document all API endpoints
- Write tests for critical paths
- Regular security audits
- Performance monitoring

---

**Last Updated:** 2025-12-19
**Version:** 1.0
**Status:** Active Development
