import 'package:flutter/material.dart';

import '../logic/organizer_events_rules.dart';

/// One event: what a guest would see (title, when, where, capacity), its state, and, for a draft only, Edit and Remove.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.onEdit, required this.onRemove});

  final OrgEvent event;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = event.isDraft ? const Color(0xFFFFB300) : const Color(0xFF66BB6A);
    return Card(
      key: Key('event-${event.eventId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(event.title, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  key: Key('status-${event.eventId}'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: color.withValues(alpha: 0.6)),
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(event.status.label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(formatEventWhen(event.startDate, event.endDate), style: theme.textTheme.bodyMedium),
            Text(event.address == null ? event.venueName : '${event.venueName}, ${event.address}', style: theme.textTheme.bodySmall),
            if (event.capacity != null) Text('Capacity ${event.capacity}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(event.status.note, key: Key('note-${event.eventId}'), style: theme.textTheme.bodySmall),
            if (event.isDraft)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(key: Key('edit-${event.eventId}'), onPressed: onEdit, child: const Text('Edit')),
                  TextButton(
                    key: Key('remove-${event.eventId}'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF5350)),
                    onPressed: onRemove,
                    child: const Text('Remove'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
