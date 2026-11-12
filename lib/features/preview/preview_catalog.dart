import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import 'screens/ambassador_lead_screens.dart';
import 'screens/app_wide_screens.dart';
import 'screens/dj_screens.dart';
import 'screens/inbox_screens.dart';
import 'screens/organizer_screens.dart';
import 'screens/role_chooser_screen.dart';
import 'screens/venue_screens.dart';
import 'widgets/pv_mini_app.dart';

/// Every sample screen, in one list. The gallery lists them, the router opens them by [PreviewEntry.id], and the tests open every one.
///
/// To add one: write the screen under `screens/`, add an entry here, and add a line to `docs/VENDOR_APP_PENDING.md` (in the monorepo) saying
/// what is still needed to make it real. `source` is the file of the web prototype (branch `prototype-web`, folder `prototype/src`) the layout
/// was taken from.
enum PreviewGroup {
  newRoles('New roles', 'Roles in the design that the app does not have yet.'),
  organizer('Organizer tools', 'Tools in the design for event organizers.'),
  owner('Owner and manager tools', 'Tools in the design for a venue owner or manager.'),
  appWide('Whole app', 'Screens that belong to the app, not to one role.');

  const PreviewGroup(this.label, this.blurb);

  final String label;
  final String blurb;
}

class PreviewEntry {
  const PreviewEntry({
    required this.id,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.source,
    this.app,
    this.page,
  }) : assert((app == null) != (page == null), 'Give either an app (a role with tabs) or a page');

  final String id;
  final PreviewGroup group;
  final String title;
  final String subtitle;
  final IconData icon;
  final String source;

  /// A whole role, with its tabs.
  final PvMiniAppConfig? app;

  /// A single page.
  final WidgetBuilder? page;

  Widget build(BuildContext context) => app != null ? PvMiniApp(config: app!) : page!(context);
}

List<PreviewEntry> get previewCatalog => [
      PreviewEntry(
        id: 'dj',
        group: PreviewGroup.newRoles,
        title: 'DJ / Artist',
        subtitle: 'Booking requests with a price breakdown, calendar, packages and add-ons, earnings, public profile.',
        icon: Ionicons.musical_notes_outline,
        source: 'Dj.tsx, DjStudio.tsx, Inbox.tsx',
        app: djApp,
      ),
      PreviewEntry(
        id: 'ambassador',
        group: PreviewGroup.newRoles,
        title: 'Ambassador',
        subtitle: 'Shares an organizer\'s events with a referral code and link, and earns commission.',
        icon: Ionicons.share_social_outline,
        source: 'Roles.tsx',
        app: ambassadorApp,
      ),
      PreviewEntry(
        id: 'event-lead',
        group: PreviewGroup.newRoles,
        title: 'Event Lead',
        subtitle: 'Leads the ambassadors of an event: team, leaderboard, invitations, earnings.',
        icon: Ionicons.ribbon_outline,
        source: 'Roles.tsx',
        app: eventLeadApp,
      ),
      PreviewEntry(
        id: 'organizer-overview',
        group: PreviewGroup.organizer,
        title: 'Overview with a branded banner',
        subtitle: 'The banner guests see, shortcuts, upcoming events, what needs attention, bookings and sales.',
        icon: Ionicons.home_outline,
        source: 'OrgTools.tsx (Banner, Dashboard)',
        page: (_) => const OrganizerOverviewPage(),
      ),
      PreviewEntry(
        id: 'organizer-analytics',
        group: PreviewGroup.organizer,
        title: 'Analytics',
        subtitle: 'Ticket sales by day, views to bookings, gross sales to net earnings, for each event.',
        icon: Ionicons.stats_chart_outline,
        source: 'OrgTools.tsx (Analytics)',
        page: (_) => const OrganizerAnalyticsPage(),
      ),
      PreviewEntry(
        id: 'organizer-opportunities',
        group: PreviewGroup.organizer,
        title: 'Opportunities',
        subtitle: 'Post a role (photographer, DJ, host...), see applicants, shortlist or decline.',
        icon: Ionicons.sparkles_outline,
        source: 'OrgTools.tsx (Opportunities)',
        page: (_) => const OpportunitiesPage(),
      ),
      PreviewEntry(
        id: 'organizer-profile',
        group: PreviewGroup.organizer,
        title: 'Public profile',
        subtitle: 'What guests see of the organizer, with the details to edit and what to show.',
        icon: Ionicons.person_circle_outline,
        source: 'OrgProfile.tsx (PublicProfile, ProfileEditor)',
        page: (_) => const OrganizerProfilePage(),
      ),
      PreviewEntry(
        id: 'organizer-content',
        group: PreviewGroup.organizer,
        title: 'Posts and highlights',
        subtitle: 'Posts, story highlights, comments to review, tips to grow.',
        icon: Ionicons.images_outline,
        source: 'OrgProfile.tsx (ContentManager)',
        page: (_) => const ContentManagerPage(),
      ),
      PreviewEntry(
        id: 'organizer-flyer',
        group: PreviewGroup.organizer,
        title: 'Flyer tool',
        subtitle: 'Pick a template, type the event details, see the flyer, export an image.',
        icon: Ionicons.color_palette_outline,
        source: 'OrgTools.tsx (FlyerTool)',
        page: (_) => const FlyerToolPage(),
      ),
      PreviewEntry(
        id: 'organizer-repeat-promos',
        group: PreviewGroup.organizer,
        title: 'Repeating events and promo codes',
        subtitle: 'Weekly schedules for an event, and promo codes with limits.',
        icon: Ionicons.repeat_outline,
        source: 'EventParts.tsx (RepeatEditor), OrgTools.tsx (PromoForm, PromoList)',
        page: (_) => const RepeatAndPromosPage(),
      ),
      PreviewEntry(
        id: 'organizer-messages',
        group: PreviewGroup.organizer,
        title: 'Messages: inquiries and team',
        subtitle: 'Guests and clients on one side, staff, venues and DJs on the other; group chats per event.',
        icon: Ionicons.chatbubbles_outline,
        source: 'Inbox.tsx, Messages.tsx',
        page: (_) => const InboxPage(account: 'Event organizer'),
      ),
      PreviewEntry(
        id: 'owner-numbers',
        group: PreviewGroup.owner,
        title: 'What is behind the Overview numbers',
        subtitle: 'Expected, Arrived and Sales, each opening into what it is made of.',
        icon: Ionicons.analytics_outline,
        source: 'OwnerStats.tsx',
        page: (_) => const OverviewNumbersPage(),
      ),
      PreviewEntry(
        id: 'owner-payout-issue',
        group: PreviewGroup.owner,
        title: 'A payout that failed',
        subtitle: 'Says what happened, that the money is safe, and the one thing to do: fix the bank details.',
        icon: Ionicons.card_outline,
        source: 'Owner.tsx (PayoutIssue, BankForm, PayoutSupport)',
        page: (_) => const PayoutIssuePage(),
      ),
      PreviewEntry(
        id: 'venue-messages',
        group: PreviewGroup.owner,
        title: 'Messages centre',
        subtitle: 'Customers, team, and requests (help, bottle signs, refunds) in one place.',
        icon: Ionicons.mail_unread_outline,
        source: 'Messages.tsx (MessagesCenter, Requests)',
        page: (_) => const MessagesCenterPage(),
      ),
      PreviewEntry(
        id: 'booking-details',
        group: PreviewGroup.owner,
        title: 'Booking: passes, pre-orders, refund',
        subtitle: 'Who has claimed a pass, what was ordered ahead, the sign, and cancelling with a refund.',
        icon: Ionicons.receipt_outline,
        source: 'Guests.tsx (BookingExtras, CancelBody, ChangeSignBody)',
        page: (_) => const BookingExtrasPage(),
      ),
      PreviewEntry(
        id: 'venue-events',
        group: PreviewGroup.owner,
        title: "The venue's own events",
        subtitle: 'One-time and weekly events a venue creates itself, with each date\'s tickets, guest list, tables and staff.',
        icon: Ionicons.calendar_number_outline,
        source: 'VenueOps.tsx (VenueEvents)',
        page: (_) => const VenueEventsPage(),
      ),
      PreviewEntry(
        id: 'role-chooser',
        group: PreviewGroup.appWide,
        title: 'Role chooser (demo)',
        subtitle: '"How are you working tonight?": all eight roles side by side. A demo screen, not part of a real sign-in.',
        icon: Ionicons.people_circle_outline,
        source: 'Access.tsx (RoleAccess)',
        page: (_) => const RoleChooserPage(),
      ),
      PreviewEntry(
        id: 'settings',
        group: PreviewGroup.appWide,
        title: 'Settings and appearance',
        subtitle: 'Dark, Light or match the phone; what the app notifies you about.',
        icon: Ionicons.settings_outline,
        source: 'shared.tsx (SettingsBody, AppearanceCard)',
        page: (_) => const AppearanceSettingsPage(),
      ),
      PreviewEntry(
        id: 'launch',
        group: PreviewGroup.appWide,
        title: 'Launch screen',
        subtitle: 'The screen while the app starts: logo, name, "Business", a turning cue.',
        icon: Ionicons.rocket_outline,
        source: 'Launch.tsx, BottlePop.tsx',
        page: (_) => const LaunchScreenPage(),
      ),
      PreviewEntry(
        id: 'access-states',
        group: PreviewGroup.appWide,
        title: 'Invitation, expired and pending',
        subtitle: 'What a person sees when an invitation or an access request is not simply "in".',
        icon: Ionicons.mail_open_outline,
        source: 'Access.tsx (AccessState)',
        page: (_) => const AccessStatesPage(),
      ),
    ];

PreviewEntry? previewEntryFor(String id) {
  for (final e in previewCatalog) {
    if (e.id == id) return e;
  }
  return null;
}
