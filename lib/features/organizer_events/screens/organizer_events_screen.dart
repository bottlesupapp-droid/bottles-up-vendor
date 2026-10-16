import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_time_picker.dart';
import '../../owner/widgets/setup_common.dart' show confirmRemove;
import '../../workspace/models/workspace.dart';
import '../logic/organizer_events_rules.dart';
import '../providers/organizer_events_providers.dart';
import '../services/organizer_events_service.dart';
import '../widgets/event_card.dart';
import 'event_form_screen.dart';

/// Home and Events (organizer): the business's events, with a way to create one, change or remove a draft, and a plain "contact
/// BottlesUp" on a published one. The database decides what this person may do; nothing here grants access. Drafts stay private
/// until the BottlesUp team publishes them.
class OrganizerEventsScreen extends ConsumerStatefulWidget {
  const OrganizerEventsScreen({super.key, required this.workspace, this.pickDateTime = pickDateAndTime, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTimePicker pickDateTime;
  final DateTime Function() clock;

  @override
  ConsumerState<OrganizerEventsScreen> createState() => _OrganizerEventsScreenState();
}

class _OrganizerEventsScreenState extends ConsumerState<OrganizerEventsScreen> {
  String get _orgId => widget.workspace.orgId;

  void _say(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openForm(OrgEvent? event) async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EventFormScreen(orgId: _orgId, event: event, pickDateTime: widget.pickDateTime, clock: widget.clock),
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(organizerEventsProvider(_orgId));
    _say(event == null ? 'Draft created. It stays private until the BottlesUp team publishes it.' : 'Draft saved.');
  }

  Future<void> _remove(OrgEvent e) async {
    final yes = await confirmRemove(context, title: 'Remove ${e.title}?', body: 'The draft is deleted. This cannot be undone.');
    if (!yes || !mounted) return;
    try {
      await ref.read(organizerEventsServiceProvider).remove(_orgId, e.eventId);
      if (!mounted) return;
      ref.invalidate(organizerEventsProvider(_orgId));
      _say('Event removed.');
    } on OrganizerEventsActionException catch (ex) {
      if (mounted) _say(ex.message);
    }
  }

  Widget _heading(BuildContext context, String text) =>
      Padding(padding: const EdgeInsets.only(top: 12, bottom: 8), child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 0.8)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = ref.watch(organizerEventsProvider(_orgId));
    return events.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final e = error is OrganizerEventsLoadException ? error : const OrganizerEventsLoadException(unavailable: false, accessEnded: false);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.message, key: const Key('events-error'), textAlign: TextAlign.center),
                if (!e.unavailable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(key: const Key('events-retry'), onPressed: () => ref.invalidate(organizerEventsProvider(_orgId)), child: const Text('Try again')),
                ],
              ],
            ),
          ),
        );
      },
      data: (list) {
        final g = groupEvents(list, widget.clock());
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          children: [
            Text('Create your events here. They stay private drafts until the BottlesUp team publishes them and sets up tickets with you.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(key: const Key('create-event'), onPressed: () => _openForm(null), icon: const Icon(Icons.add, size: 18), label: const Text('Create event')),
            ),
            if (list.isEmpty)
              Container(
                key: const Key('no-events'),
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(14)),
                child: const Text('No events yet. Create your first event. It stays a private draft until the BottlesUp team publishes it.', textAlign: TextAlign.center),
              ),
            for (final (title, group) in [('Drafts', g.drafts), ('Upcoming', g.upcoming), ('Past', g.past)])
              if (group.isNotEmpty) ...[
                _heading(context, title),
                for (final e in group) EventCard(event: e, onEdit: () => _openForm(e), onRemove: () => _remove(e)),
              ],
          ],
        );
      },
    );
  }
}
