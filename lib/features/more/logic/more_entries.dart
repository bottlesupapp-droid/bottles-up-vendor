import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../workspace/models/workspace_role.dart';

/// One line of a More hub: where the person goes for things that do not have a tab of their own.
class MoreEntry {
  const MoreEntry({required this.id, required this.label, required this.subtitle, required this.icon});

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
}

const _team = MoreEntry(id: 'team', label: 'Team', subtitle: 'Staff, invitations and roles for the business.', icon: Ionicons.people_outline);
const _inventory = MoreEntry(id: 'inventory', label: 'Inventory', subtitle: 'Stock counts, deliveries, wastage and low-stock alerts.', icon: Ionicons.cube_outline);
const _vip = MoreEntry(id: 'vip', label: 'VIP guests', subtitle: 'Guests with standing perks, checked at the door.', icon: Ionicons.star_outline);
const _discounts = MoreEntry(id: 'discounts', label: 'Discounts', subtitle: 'Promo codes staff may apply, with limits and approvals.', icon: Ionicons.pricetag_outline);
const _complimentary = MoreEntry(id: 'complimentary', label: 'Complimentary bottles', subtitle: 'Offer a bottle with a claim link; every one is recorded.', icon: Ionicons.gift_outline);
const _agreements = MoreEntry(id: 'agreements', label: 'Events and agreements', subtitle: 'Organizer events at your club and the terms agreed for each.', icon: Ionicons.document_text_outline);
const _settlement = MoreEntry(id: 'settlement', label: 'Settlement', subtitle: 'What is owed between your events and the venues.', icon: Ionicons.cash_outline);
const _notifications = MoreEntry(id: 'notifications', label: 'Notifications', subtitle: 'What the app tells you, and how.', icon: Ionicons.notifications_outline);
const _security = MoreEntry(id: 'security', label: 'Security', subtitle: 'Alerts, tasks and incident reports for your club.', icon: Ionicons.shield_outline);
const _chat = MoreEntry(id: 'chat', label: 'Chat', subtitle: 'Your club\'s staff chat, event chats and direct messages.', icon: Ionicons.chatbubbles_outline);
const _settings = MoreEntry(id: 'settings', label: 'Settings', subtitle: 'Who you are signed in as, and the privacy policy.', icon: Ionicons.settings_outline);

/// The entries of a role's More tab, in the order the brief lists them. Roles without a More tab have none.
List<MoreEntry> moreEntriesFor(WorkspaceRole role) => switch (role) {
      WorkspaceRole.owner => const [_team, _inventory, _vip, _discounts, _complimentary, _agreements, _chat, _settings],
      WorkspaceRole.manager => const [_security, _inventory, _vip, _discounts, _complimentary, _agreements, _chat, _settings],
      WorkspaceRole.organizer => const [_team, _settlement, _notifications, _settings],
      _ => const [],
    };
