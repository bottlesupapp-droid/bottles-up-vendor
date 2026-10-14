import 'package:flutter/widgets.dart';
import 'package:ionicons/ionicons.dart';

import 'workspace.dart';
import 'workspace_role.dart';

/// One tab of a role's bottom navigation.
class WorkspaceSection {
  const WorkspaceSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.summary,
  });

  /// Used in the URL: `/w/{membershipId}/{id}`.
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// What this section will hold, taken from the Phase 2 brief. Shown while the
  /// section is not built yet, so the app is honest about what is missing.
  final String summary;
}

class RoleNavigation {
  const RoleNavigation({required this.role, required this.sections});

  final WorkspaceRole role;

  /// Tabs in display order. The first one is where the role lands.
  final List<WorkspaceSection> sections;

  WorkspaceSection get landing => sections.first;

  WorkspaceSection? byId(String id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  int indexOf(String id) {
    final i = sections.indexWhere((s) => s.id == id);
    return i < 0 ? 0 : i;
  }
}

WorkspaceSection _s(String id, String label, IconData icon, IconData activeIcon, String summary) =>
    WorkspaceSection(id: id, label: label, icon: icon, activeIcon: activeIcon, summary: summary);

/// Navigation per role: Phase 2 brief, section 2, "App-wide navigation and
/// behavior". Labels and order are the client's; do not rename them casually.
final Map<WorkspaceRole, RoleNavigation> _navigation = {
  WorkspaceRole.owner: RoleNavigation(role: WorkspaceRole.owner, sections: [
    _s('home', 'Home', Ionicons.home_outline, Ionicons.home,
        'All Venues overview: recorded sales, collections, bookings, outstanding balances, event status and unresolved issues.'),
    _s('venues', 'Venues', Ionicons.business_outline, Ionicons.business,
        'Add, select and manage clubs. Each venue keeps its own rooms, payments, staff and stock.'),
    _s('money', 'Money', Ionicons.cash_outline, Ionicons.cash,
        'Collections, outstanding balances and organizer settlements.'),
    _s('reports', 'Reports', Ionicons.document_text_outline, Ionicons.document_text,
        'Preliminary and final nightly reports for each venue and event.'),
    _s('more', 'More', Ionicons.menu_outline, Ionicons.menu,
        'Team, inventory, VIP guests, discounts and complimentary offers, agreements, chat and settings.'),
  ]),
  WorkspaceRole.manager: RoleNavigation(role: WorkspaceRole.manager, sections: [
    _s('tonight', 'Tonight', Ionicons.moon_outline, Ionicons.moon,
        'Prepare, run and close the night: checklist, needs-attention queue, live floor and orders.'),
    _s('floor', 'Floor', Ionicons.grid_outline, Ionicons.grid,
        'Rooms and tables with live status, bookings and table actions.'),
    _s('orders', 'Orders', Ionicons.receipt_outline, Ionicons.receipt,
        'Bottle orders and their service progress for tonight.'),
    _s('team', 'Team', Ionicons.people_outline, Ionicons.people,
        'Staff, invitations, shifts and role limits for this venue.'),
    _s('more', 'More', Ionicons.menu_outline, Ionicons.menu,
        'Inventory, VIP guests, discounts, events and agreements, chat and settings.'),
  ]),
  WorkspaceRole.organizer: RoleNavigation(role: WorkspaceRole.organizer, sections: [
    _s('home', 'Home', Ionicons.home_outline, Ionicons.home,
        'My events and each event\'s overview.'),
    _s('events', 'Events', Ionicons.calendar_outline, Ionicons.calendar,
        'Create events, set tickets and tables, link a venue, agree terms and publish.'),
    _s('guests', 'Guests', Ionicons.people_outline, Ionicons.people,
        'Guest lists, invitations and passes for your events.'),
    _s('chat', 'Chat', Ionicons.chatbubbles_outline, Ionicons.chatbubbles,
        'Shared event chat with approved venue staff.'),
    _s('more', 'More', Ionicons.menu_outline, Ionicons.menu,
        'Team, settlement, notifications and settings.'),
  ]),
  WorkspaceRole.server: RoleNavigation(role: WorkspaceRole.server, sections: [
    _s('tables', 'My Tables', Ionicons.grid_outline, Ionicons.grid,
        'Your shift: assigned tables, guests and the next action for each.'),
    _s('orders', 'Orders', Ionicons.receipt_outline, Ionicons.receipt,
        'Orders for your tables, filtered by status.'),
    _s('scan', 'Scan', Ionicons.qr_code_outline, Ionicons.qr_code,
        'Scan a booking QR to confirm the guest and seat them.'),
    _s('requests', 'Requests', Ionicons.hand_left_outline, Ionicons.hand_left,
        'Service requests from your tables.'),
    _s('chat', 'Chat', Ionicons.chatbubbles_outline, Ionicons.chatbubbles,
        'Venue and event chat.'),
  ]),
  WorkspaceRole.door: RoleNavigation(role: WorkspaceRole.door, sections: [
    _s('scan', 'Scan', Ionicons.qr_code_outline, Ionicons.qr_code,
        'Scan tickets and passes for the assigned event.'),
    _s('guests', 'Guests', Ionicons.people_outline, Ionicons.people,
        'Search the guest list: tickets, booth guests, VIP and invited guests.'),
    _s('door-sales', 'Door Sales', Ionicons.ticket_outline, Ionicons.ticket,
        'Sell a ticket at the door and check the guest in.'),
    _s('chat', 'Chat', Ionicons.chatbubbles_outline, Ionicons.chatbubbles,
        'Event chat.'),
  ]),
  WorkspaceRole.security: RoleNavigation(role: WorkspaceRole.security, sections: [
    _s('alerts', 'Alerts', Ionicons.warning_outline, Ionicons.warning,
        'Alerts for your shift.'),
    _s('tasks', 'Tasks', Ionicons.checkbox_outline, Ionicons.checkbox,
        'Tasks assigned to you.'),
    _s('chat', 'Chat', Ionicons.chatbubbles_outline, Ionicons.chatbubbles,
        'Staff chat.'),
    _s('incidents', 'Incidents', Ionicons.shield_outline, Ionicons.shield,
        'Report and review incidents.'),
  ]),
  WorkspaceRole.verifier: RoleNavigation(role: WorkspaceRole.verifier, sections: [
    _s('review', 'Review', Ionicons.eye_outline, Ionicons.eye,
        'Payment review queue: compare each bill and receipt with the transaction.'),
    _s('cash', 'Cash', Ionicons.wallet_outline, Ionicons.wallet,
        'Cash handovers to acknowledge and reconcile.'),
    _s('exceptions', 'Exceptions', Ionicons.alert_circle_outline, Ionicons.alert_circle,
        'Flagged payments waiting for a manager.'),
    _s('summary', 'Summary', Ionicons.stats_chart_outline, Ionicons.stats_chart,
        'Review totals for your shift.'),
  ]),
};

RoleNavigation navigationFor(WorkspaceRole role) => _navigation[role]!;

/// Where a workspace opens: its role's first tab.
String workspaceLandingPath(Workspace workspace) =>
    workspaceSectionPath(workspace.membershipId, navigationFor(workspace.role).landing.id);

String workspaceSectionPath(String membershipId, String sectionId) => '/w/$membershipId/$sectionId';

/// One venue inside an owner's Venues tab: `/w/{membershipId}/venues/{venueId}`.
String workspaceVenuePath(String membershipId, String venueId) => '/w/$membershipId/venues/$venueId';
