import 'package:flutter/material.dart';

import '../../agreements/screens/agreements_screen.dart';
import '../../booking_conflicts/screens/booking_conflicts_screen.dart';
import '../../bottle_signs/screens/bottle_signs_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../discounts/screens/discounts_screen.dart';
import '../../door_sales/screens/shift_summary_screen.dart';
import '../../door_staff/screens/club_door_staff_screen.dart';
import '../../door_staff/screens/organizer_team_screen.dart';
import '../../inventory/screens/inventory_screen.dart';
import '../../money/screens/owner_money_screen.dart';
import '../../payouts/screens/payouts_screen.dart';
import '../../refunds/screens/refunds_screen.dart';
import '../../security/screens/incidents_screen.dart';
import '../../security/screens/security_hub_screen.dart';
import '../../team/screens/team_screen.dart';
import '../../vip/screens/vip_screen.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/more_entries.dart';
import 'workspace_settings_screen.dart';

/// The page behind a More entry, or null while that part is not built. Add to this as each part is built; nothing else changes.
Widget? moreDestinationFor(Workspace workspace, String entryId) => switch (entryId) {
      'chat' => ChatScreen(workspace: workspace),
      // Inventory is the manager's and the owner's: stock levels and the history of how they changed.
      'inventory' => InventoryScreen(workspace: workspace),
      // VIP guests are the manager's and the owner's list; servers look a guest up from My Tables.
      'vip' => VipScreen(workspace: workspace),
      // Payouts are the business's own (an owner's club money, an organizer's account): read only, set up and paid by BottlesUp.
      'payouts' when workspace.role == WorkspaceRole.owner || workspace.role == WorkspaceRole.organizer => PayoutsScreen(workspace: workspace),
      // Discounts and free bottles: the owner sets the limits, the manager decides what is above a server's limit (the owner picks the club).
      'discounts' when workspace.role == WorkspaceRole.owner || workspace.role == WorkspaceRole.manager => DiscountsScreen(workspace: workspace),
      // Bottle signs are the club's: where a sign can go, whether a manager approves a server's, and the signs waiting (the owner picks the club).
      'bottle-signs' when workspace.role == WorkspaceRole.owner || workspace.role == WorkspaceRole.manager => BottleSignsScreen(workspace: workspace),
      // Refunds are the club's: its refund policy and the requests to decide (the owner picks the club).
      'refunds' when workspace.role == WorkspaceRole.owner || workspace.role == WorkspaceRole.manager => RefundsScreen(workspace: workspace),
      // Double-booked tables: guests who paid after their table had gone to someone else, for the manager to sort out (the owner picks the club).
      'conflicts' when workspace.role == WorkspaceRole.owner || workspace.role == WorkspaceRole.manager => BookingConflictsScreen(workspace: workspace),
      // Agreements: a club's requests and terms with organizers, and an organizer's requests to clubs.
      'agreements' => AgreementsScreen(workspace: workspace),
      // Security is the manager's: the club's alerts, tasks and incident reports.
      'security' when workspace.role == WorkspaceRole.manager => SecurityHubScreen(workspace: workspace),
      // The Team screen is the owner's (and the manager's own Team tab); an organizer's team is not built.
      'team' when workspace.role == WorkspaceRole.owner => TeamScreen(workspace: workspace),
      // An organizer's team is its door staff, event by event (the club decides whether it may bring its own).
      'team' when workspace.role == WorkspaceRole.organizer => OrganizerTeamScreen(workspace: workspace),
      // The club's side: which organizers may bring door staff to which events, and who they have brought.
      'organizer-door' when workspace.role == WorkspaceRole.owner || workspace.role == WorkspaceRole.manager => ClubDoorStaffScreen(workspace: workspace),
      // Payments and earnings is the owner's: each club's money for a range of nights (it used to be a tab of its own).
      'money' when workspace.role == WorkspaceRole.owner => OwnerMoneyScreen(workspace: workspace),
      // Incidents are the security staff's: report one, and read the ones they reported.
      'incidents' when workspace.role == WorkspaceRole.security => IncidentsScreen(workspace: workspace),
      // The door's own shift at the chosen event: what they scanned in and what they sold, cash and card machine apart.
      'shift-summary' when workspace.role == WorkspaceRole.door => ShiftSummaryScreen(membershipId: workspace.membershipId),
      'settings' => WorkspaceSettingsScreen(workspace: workspace),
      _ => null,
    };

/// Rows for parts that are not built yet are left out of the menu, so nobody opening the app (a client, a store reviewer) meets a row that goes nowhere. Switch it on while building to see
/// every part of the brief again, each plainly marked "Not available yet". (The parts: Complimentary bottles, the door's Promo codes, an organizer's Settlement and Notifications.)
const bool showUnbuiltMoreEntries = false;

/// The More tab of an owner, a manager, an organizer, a door or a security role: the parts that do not have a tab of their own. A part that is not built says so,
/// plainly, instead of opening an empty page.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.workspace, this.showUnbuilt = showUnbuiltMoreEntries});

  final Workspace workspace;

  /// Whether rows for parts that are not built are shown (as "Not available yet"). Off in the app; tests switch it on to see them.
  final bool showUnbuilt;

  void _open(BuildContext context, MoreEntry entry, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(entry.label)),
          body: SafeArea(child: page),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = [
      for (final e in moreEntriesFor(workspace.role))
        if (showUnbuilt || moreDestinationFor(workspace, e.id) != null) e,
    ];
    return ListView(
      key: const Key('more-list'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
      children: [
        Text('More', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(workspace.scopeLabel, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final e in entries)
          Builder(builder: (context) {
            final page = moreDestinationFor(workspace, e.id);
            return ListTile(
              key: Key('more-${e.id}'),
              contentPadding: EdgeInsets.zero,
              enabled: page != null,
              leading: Icon(e.icon),
              title: Text(e.label),
              subtitle: Text(page == null ? 'Not available yet. ${e.subtitle}' : e.subtitle),
              trailing: page == null ? null : const Icon(Icons.chevron_right),
              onTap: page == null ? null : () => _open(context, e, page),
            );
          }),
      ],
    );
  }
}
