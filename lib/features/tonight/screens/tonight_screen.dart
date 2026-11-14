import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/ui/bu_coming_soon.dart';

/// Tonight, for the accounts that have no workspace yet: the design's live view of the night (floor, bookings, orders, team) is not built for them, so the tab is
/// here, in the design's place, and says so. Nothing on it saves or sends anything.
class TonightScreen extends StatelessWidget {
  const TonightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BuComingSoonPage(
      eyebrow: 'Tonight',
      title: 'Tonight',
      intro: 'Run the night live: the floor, the bookings, the orders and your team in one place.',
      icon: Ionicons.moon,
      will: const [
        ('Floor', 'Tables seated and guests arrived, as they happen', Ionicons.grid_outline),
        ('Bookings', 'Who is coming, at which table, and what they ordered', Ionicons.bookmarks_outline),
        ('Orders', 'Open orders and their value, by table', Ionicons.receipt_outline),
        ('Team', 'Who is on shift, and who is arriving', Ionicons.people_outline),
      ],
      actionLabel: 'Back to Overview',
      onAction: () => context.go('/dashboard'),
    );
  }
}
