import 'package:flutter/material.dart';

import '../../../core/ui/bu_kit.dart';
import '../logic/owner_rules.dart';

/// "Live" or "Draft" beside a venue's name. Only a published venue is live.
class VenueStatusChip extends StatelessWidget {
  const VenueStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return BuStatusPill(statusWord(status), key: const Key('venue-status'), tone: isLiveStatus(status) ? BuTone.good : BuTone.neutral);
  }
}
