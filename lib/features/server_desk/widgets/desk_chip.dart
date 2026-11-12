import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../logic/server_desk_rules.dart';

/// The colour of a request's status: amber while it waits, orange while someone is on it, green when done, red when it was passed up. The word on the chip says the same, so colour is never the only signal.
/// (These are the design's own colours; the app is dark only for now, so they are read from the dark tokens.)
Color requestStatusColor(RequestStatus s) => switch (s) {
      RequestStatus.fresh => BuTokens.dark.amber,
      RequestStatus.acknowledged || RequestStatus.inProgress => BuTokens.dark.orangeSoft,
      RequestStatus.completed => BuTokens.dark.green,
      RequestStatus.escalated => BuTokens.dark.red,
      RequestStatus.cancelled => BuTokens.dark.muted,
    };

/// A small status pill: a faint wash of its colour, the same colour at its edge and in its word (the kit's status pill, with room for an icon).
class DeskChip extends StatelessWidget {
  const DeskChip({super.key, required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(BuRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      ]),
    );
  }
}
