import 'package:flutter/material.dart';

import '../../owner/widgets/photo_field.dart';
import '../logic/event_states.dart';
import '../logic/organizer_events_rules.dart';

/// One event: what a guest would see (title, when, where, capacity), its state, and, for a draft only, Edit and Remove.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.onEdit, required this.onRemove, this.info, this.onBlockerAction, this.onCopyLink});

  final OrgEvent event;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  /// Copies the public link of a live event. Offered only for an event that is live on the website.
  final VoidCallback? onCopyLink;

  /// Where the event stands and what blocks publishing it, when the database could say. Without it the card shows the plain status.
  final EventStateInfo? info;

  /// Called with where to go when the person taps the button next to a blocker.
  final void Function(BlockerAction action)? onBlockerAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = info?.state;
    final label = state?.label ?? event.status.label;
    final note = state?.note ?? event.status.note;
    final color = switch (state) {
      EventState.live => const Color(0xFF66BB6A),
      EventState.readyToPublish => const Color(0xFF66BB6A),
      EventState.ended => const Color(0xFF9E9E9E),
      EventState.awaitingVenueApproval => const Color(0xFF42A5F5),
      EventState.draft => const Color(0xFFFFB300),
      null => event.isDraft ? const Color(0xFFFFB300) : const Color(0xFF66BB6A),
    };
    final blockers = info == null || event.isDraft == false ? const <String>[] : blockerSentences(info!);
    final action = info == null || !event.isDraft ? null : blockerAction(info!);
    return Card(
      key: Key('event-${event.eventId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.coverImageUrl != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: PhotoThumb(key: Key('thumb-${event.eventId}'), url: event.coverImageUrl!)),
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
                  child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(formatEventWhen(event.startDate, event.endDate), style: theme.textTheme.bodyMedium),
            Text(event.address == null ? event.venueName : '${event.venueName}, ${event.address}', style: theme.textTheme.bodySmall),
            if (event.capacity != null) Text('Capacity ${event.capacity}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(note, key: Key('note-${event.eventId}'), style: theme.textTheme.bodySmall),
            if (blockers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('What is blocking publishing', style: theme.textTheme.labelLarge),
              for (var i = 0; i < blockers.length; i++) Text('• ${blockers[i]}', key: Key('blocker-${event.eventId}-$i'), style: theme.textTheme.bodySmall),
              if (action != null && onBlockerAction != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(key: Key('blocker-action-${event.eventId}'), onPressed: () => onBlockerAction!(action.action), child: Text(action.label)),
                ),
            ],
            if (event.isLive && onCopyLink != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(key: Key('copy-link-${event.eventId}'), onPressed: onCopyLink, icon: const Icon(Icons.link, size: 18), label: const Text('Copy event link')),
              ),
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
