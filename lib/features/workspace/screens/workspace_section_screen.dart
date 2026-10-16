import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../door/screens/door_guests_screen.dart';
import '../../door/screens/door_scan_screen.dart';
import '../../floor/screens/floor_screen.dart';
import '../../organizer_events/screens/organizer_events_screen.dart';
import '../../owner/screens/owner_home_screen.dart';
import '../../owner/screens/owner_venues_screen.dart';
import '../../server_desk/screens/my_tables_screen.dart';
import '../../server_desk/screens/service_requests_screen.dart';
import '../../table_service/screens/orders_screen.dart';
import '../../table_service/screens/payment_review_screen.dart';
import '../../table_service/screens/tonight_screen.dart';
import '../../team/screens/team_screen.dart';
import '../models/role_navigation.dart';
import '../models/workspace.dart';
import '../models/workspace_role.dart';
import '../providers/workspace_providers.dart';
import '../../cash_review/screens/summary_screen.dart';
import '../../cash_review/screens/exceptions_screen.dart';
import '../../cash_review/screens/cash_screen.dart';
import '../../seating/screens/server_scan_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../more/screens/more_screen.dart';
import '../../security/screens/alerts_screen.dart';
import '../../security/screens/incidents_screen.dart';
import '../../security/screens/tasks_screen.dart';

/// The sections that are built, keyed by role and section id. Everything else shows the honest "not built yet" card.
///
/// An owner's Home shows tonight across every venue of the business, and Venues lists the venues with their setup (each opens its
/// bookings, setup checklist and booking link). Money, reports and the rest of the owner's tabs wait for the production-only
/// definitions of payments.
///
/// A manager's Tonight (what needs a person, the night at a glance), Floor (the bookings of their own club, each with its orders and
/// payments) and Orders (the club's bottle orders for the night) are built. Their Team tab is shared with the owner.
///
/// A server's My Tables (the tables the manager has given them for the night, each with its orders and payments), Orders and Requests
/// are built on the website's `my_assigned_tables`, `desk_*` and service-request functions. Their Scan tab seats a guest from a booking
/// QR or code. Chat is the Chat tab of the server, door, security and organizer roles. Only the DOOR role gets the ticket scanner: scanning a ticket on a server's Scan tab would be the wrong tool.
///
/// A verifier's Review tab is the queue of payments to check. Cash, Exceptions and Summary are not built.
Widget? builtSectionFor(Workspace workspace, String sectionId) {
  // Chat: the tab of the server, door, security and organizer roles. (A manager and an owner reach it from More.)
  if (sectionId == 'chat' &&
      const {WorkspaceRole.server, WorkspaceRole.door, WorkspaceRole.security, WorkspaceRole.organizer}.contains(workspace.role)) {
    return ChatScreen(workspace: workspace);
  }
  // More: the parts of an owner, a manager and an organizer that do not have a tab of their own.
  if (sectionId == 'more' && const {WorkspaceRole.owner, WorkspaceRole.manager, WorkspaceRole.organizer}.contains(workspace.role)) {
    return MoreScreen(workspace: workspace);
  }
  // Security: alerts for the night, tasks given to them, and incident reports.
  if (workspace.role == WorkspaceRole.security) {
    switch (sectionId) {
      case 'alerts':
        return AlertsScreen(workspace: workspace);
      case 'tasks':
        return TasksScreen(workspace: workspace);
      case 'incidents':
        return IncidentsScreen(workspace: workspace);
    }
  }
  if (workspace.role == WorkspaceRole.door) {
    switch (sectionId) {
      case 'scan':
        return DoorScanScreen(membershipId: workspace.membershipId);
      case 'guests':
        return DoorGuestsScreen(membershipId: workspace.membershipId);
    }
  }
  if (workspace.role == WorkspaceRole.server) {
    switch (sectionId) {
      case 'tables':
        return MyTablesScreen(workspace: workspace);
      case 'orders':
        return OrdersScreen(workspace: workspace);
      case 'requests':
        return ServiceRequestsScreen(workspace: workspace);
      case 'scan':
        return ServerScanScreen(workspace: workspace);
    }
  }
  // A verifier's Review tab is the queue of payments to check at their club.
  if (workspace.role == WorkspaceRole.verifier) {
    switch (sectionId) {
      case 'review':
        return PaymentReviewScreen(workspace: workspace);
      case 'cash':
        return CashScreen(workspace: workspace);
      case 'exceptions':
        return ExceptionsScreen(workspace: workspace);
      case 'summary':
        return VerifierSummaryScreen(workspace: workspace);
    }
  }
  if (workspace.role == WorkspaceRole.manager) {
    switch (sectionId) {
      case 'tonight':
        return TonightScreen(workspace: workspace);
      case 'orders':
        return OrdersScreen(workspace: workspace);
    }
  }
  if (workspace.role == WorkspaceRole.owner) {
    switch (sectionId) {
      case 'home':
        return OwnerHomeScreen(workspace: workspace);
      case 'venues':
        return OwnerVenuesScreen(workspace: workspace);
    }
  }
  // An organizer's Home and Events: the business's own events, created as private drafts that the BottlesUp team publishes.
  if (workspace.role == WorkspaceRole.organizer && (sectionId == 'home' || sectionId == 'events')) {
    return OrganizerEventsScreen(workspace: workspace);
  }
  // Team: an owner invites and manages everyone in the business, a manager the staff of their own club. The database decides who
  // sees whom and which roles may be appointed; the screen only shows it.
  if ((workspace.role == WorkspaceRole.owner || workspace.role == WorkspaceRole.manager) && sectionId == 'team') {
    return TeamScreen(workspace: workspace);
  }
  if (workspace.role == WorkspaceRole.manager && sectionId == 'floor') {
    // The manager's club comes from the workspace itself; the database re-checks that they manage it.
    return FloorScreen(venueId: workspace.venueId, venueName: workspace.venueName, orgId: workspace.orgId);
  }
  return null;
}

/// A tab of a workspace. Until each one is built it says so plainly and states
/// what it will hold, instead of showing an empty or broken screen. The brief:
/// "An unavailable integration must appear as unavailable, not connected."
class WorkspaceSectionScreen extends ConsumerWidget {
  const WorkspaceSectionScreen({super.key, required this.membershipId, required this.sectionId});

  final String membershipId;
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceStateProvider).byMembershipId(membershipId);
    final section = workspace == null ? null : navigationFor(workspace.role).byId(sectionId);
    final theme = Theme.of(context);

    if (section == null) {
      return const Center(child: Text('This section is not part of your role.'));
    }

    final built = builtSectionFor(workspace!, section.id);
    if (built != null) return built;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
      children: [
        Row(
          children: [
            Icon(section.activeIcon, size: 28, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(section.label, style: theme.textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 12),
        Text(section.summary, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        Container(
          key: const Key('not-built-yet'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          ),
          child: Text(
            'Not built yet. This is where it will appear for ${workspace.role.label.toLowerCase()}s of ${workspace.scopeLabel}.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
