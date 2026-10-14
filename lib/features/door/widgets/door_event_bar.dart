import 'package:flutter/material.dart';

import '../logic/door_rules.dart';

/// Which event the door is working, and how many guests are in. The brief asks that the active event stay visible on
/// every operational screen; with several events the person chooses, and the choice is the one place a scan is aimed.
class DoorEventBar extends StatelessWidget {
  const DoorEventBar({super.key, required this.events, required this.selected, required this.onSelect});

  final List<DoorEvent> events;
  final DoorEvent selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('door-event-bar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (events.length > 1)
          DropdownButton<String>(
            key: const Key('event-picker'),
            isExpanded: true,
            value: selected.eventId,
            items: [
              for (final e in events) DropdownMenuItem(value: e.eventId, child: Text(e.title, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (id) {
              if (id != null) onSelect(id);
            },
          )
        else
          Text(selected.title, style: theme.textTheme.titleLarge),
        if (selected.venueName.isNotEmpty)
          Text(
            '${selected.venueName} · ${selected.scope == 'event' ? 'this event' : 'whole club'}',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            key: const Key('admitted-progress'),
            minHeight: 8,
            // A neutral track: the theme's default one is teal, which next to the orange fill reads as "nearly full".
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            value: admittedPercent(selected) / 100,
          ),
        ),
        const SizedBox(height: 4),
        Text(admittedSummary(selected), key: const Key('admitted-summary'), style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
