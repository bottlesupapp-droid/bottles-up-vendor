import 'package:flutter/material.dart';

import '../logic/owner_rules.dart';

/// "Live" or "Draft" beside a venue's name. Only a published venue is live.
class VenueStatusChip extends StatelessWidget {
  const VenueStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final live = isLiveStatus(status);
    final color = live ? const Color(0xFF66BB6A) : const Color(0xFF9E9E9E);
    return Container(
      key: const Key('venue-status'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.7)), borderRadius: BorderRadius.circular(20)),
      child: Text(statusWord(status), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}
