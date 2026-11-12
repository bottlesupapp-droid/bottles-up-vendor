import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../preview_catalog.dart';
import '../widgets/pv_kit.dart';

/// The design's first screen: "How are you working tonight?", a list of roles to explore, marked DEMO MODE. The real app never asks: it
/// knows each person's role from their workspace. It is here so the client can see every role in one place; the three roles the app does not
/// have open their sample, the others say where they already live.
class RoleChooserPage extends StatelessWidget {
  const RoleChooserPage({super.key});

  static const _roles = <(String, String, IconData, String?)>[
    ('Venue Owner', 'Business performance, venues, and payments', Ionicons.business_outline, null),
    ('Venue Manager', 'Run an assigned venue and shift', Ionicons.home_outline, null),
    ('Event Organizer', 'Events, tickets, guests, and agreements', Ionicons.calendar_outline, null),
    ('DJ / Artist', 'Booking requests, gigs, and prices', Ionicons.musical_notes_outline, 'dj'),
    ('Door Staff', 'Scan tickets and manage arrivals', Ionicons.scan_outline, null),
    ('Server', 'Tables, orders, and guest service', Ionicons.wine_outline, null),
    ('Ambassador', 'Share events and track commission', Ionicons.share_social_outline, 'ambassador'),
    ('Event Lead', 'Lead events, teams, and performance', Ionicons.ribbon_outline, 'event-lead'),
  ];

  @override
  Widget build(BuildContext context) {
    return PvStandalone(
      title: 'Role chooser',
      child: PvPage(
        eyebrow: 'Welcome',
        title: 'How are you working tonight?',
        intro: 'Choose a role to explore its tools and demo account.',
        trailing: const BuStatusPill('Demo mode', tone: BuTone.attention),
        children: [
          for (final r in _roles)
            Padding(
              padding: const EdgeInsets.only(bottom: BuSpace.m),
              child: BuCard(
                key: Key('role-${r.$1}'),
                padding: EdgeInsets.zero,
                onTap: () => _open(context, r),
                child: BuListRow(
                  icon: r.$3,
                  title: r.$1,
                  subtitle: r.$2,
                  trailing: r.$4 == null ? null : const BuStatusPill('Sample', tone: BuTone.attention),
                  onTap: () => _open(context, r),
                ),
              ),
            ),
          const PvNote('The app does not ask who you are: it opens the role of the workspace you sign in to. This screen is for showing the roles side by side.'),
        ],
      ),
    );
  }

  void _open(BuildContext context, (String, String, IconData, String?) role) {
    final id = role.$4;
    final entry = id == null ? null : previewEntryFor(id);
    if (entry != null) {
      pvOpen<void>(context, Builder(builder: entry.build));
      return;
    }
    showPvSheet(
      context,
      eyebrow: role.$1,
      title: 'Already in the app',
      child: Text('${role.$1} is a real role of the app. A signed-in person reaches it through their workspace, so there is nothing to choose.', style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
