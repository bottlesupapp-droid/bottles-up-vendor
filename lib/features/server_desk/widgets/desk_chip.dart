import 'package:flutter/material.dart';

import '../logic/server_desk_rules.dart';

/// The colour of a request's status: amber while it waits, blue while someone is on it, green when done, red when it was passed up.
Color requestStatusColor(RequestStatus s) => switch (s) {
      RequestStatus.fresh => const Color(0xFFFFB300),
      RequestStatus.acknowledged || RequestStatus.inProgress => const Color(0xFF42A5F5),
      RequestStatus.completed => const Color(0xFF66BB6A),
      RequestStatus.escalated => const Color(0xFFEF5350),
      RequestStatus.cancelled => const Color(0xFF9E9E9E),
    };

/// A small outlined label, like the chips on the bookings list.
class DeskChip extends StatelessWidget {
  const DeskChip({super.key, required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.7)), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ]),
    );
  }
}
