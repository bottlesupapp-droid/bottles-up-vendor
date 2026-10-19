import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/widgets/ops_async_view.dart';
import '../../organizer_events/logic/organizer_events_rules.dart';
import '../../organizer_events/providers/organizer_events_providers.dart';
import '../../workspace/models/workspace.dart';
import '../logic/guest_rules.dart';
import '../providers/guest_providers.dart';

/// Guests (organizer): pick an event and see how many tickets are sold and checked in (by ticket type), and search the people who bought
/// them. Read-only: names and tickets only, never an email address, phone number or payment. Sending invitations and issuing passes are
/// done on the website.
class OrganizerGuestsScreen extends ConsumerStatefulWidget {
  const OrganizerGuestsScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<OrganizerGuestsScreen> createState() => _OrganizerGuestsScreenState();
}

class _OrganizerGuestsScreenState extends ConsumerState<OrganizerGuestsScreen> {
  final _search = TextEditingController();
  String? _eventId;
  String _query = '';
  String? _problem;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _go() {
    final problem = checkGuestSearch(_search.text);
    setState(() {
      _problem = problem;
      if (problem == null) _query = _search.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = ref.watch(organizerEventsProvider(widget.workspace.orgId));
    return ListView(
      key: const Key('guests-list'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
      children: [
        Text('Guests', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        OpsAsyncView<List<OrgEvent>>(
          value: events,
          what: 'your events',
          isEmpty: (d) => d.isEmpty,
          emptyText: 'No events yet. Create one in Events, then its guests appear here.',
          emptyKey: const Key('guests-no-events'),
          errorKey: const Key('guests-events-error'),
          onRetry: () => ref.invalidate(organizerEventsProvider(widget.workspace.orgId)),
          builder: (list) {
            final selected = _eventId ?? list.first.eventId;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('guests-event'),
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Event'),
                  items: [for (final e in list) DropdownMenuItem(value: e.eventId, child: Text(e.title))],
                  onChanged: (v) => setState(() {
                    _eventId = v;
                    _query = '';
                    _search.clear();
                  }),
                ),
                const SizedBox(height: 12),
                _Summary(eventId: selected),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('guests-search'),
                  controller: _search,
                  decoration: InputDecoration(labelText: 'Search by name or ticket code', errorText: _problem, suffixIcon: IconButton(key: const Key('guests-search-go'), icon: const Icon(Icons.search), onPressed: _go)),
                  onSubmitted: (_) => _go(),
                ),
                const SizedBox(height: 8),
                _Guests(eventId: selected, query: _query),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return OpsAsyncView<GuestSummary>(
      value: ref.watch(guestSummaryProvider(eventId)),
      what: 'the guest numbers',
      errorKey: const Key('guests-summary-error'),
      onRetry: () => ref.invalidate(guestSummaryProvider(eventId)),
      builder: (s) => Card(
        key: const Key('guests-summary'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${s.ticketsSold} tickets sold', key: const Key('guests-sold'), style: theme.textTheme.titleMedium),
              Text(s.progress, key: const Key('guests-progress')),
              Text('${s.remaining} still to arrive', key: const Key('guests-remaining'), style: theme.textTheme.bodySmall),
              if (s.tiers.isNotEmpty) const Divider(height: 20),
              for (final (i, t) in s.tiers.indexed) Text('${t.tier}: ${t.checkedIn} of ${t.sold} checked in', key: Key('guests-tier-$i')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Guests extends ConsumerWidget {
  const _Guests({required this.eventId, required this.query});

  final String eventId;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final key = (eventId: eventId, query: query);
    return OpsAsyncView<List<Guest>>(
      value: ref.watch(guestListProvider(key)),
      what: 'guests',
      isEmpty: (d) => d.isEmpty,
      emptyText: query.isEmpty ? 'No tickets have been bought yet.' : 'No one matches that.',
      emptyKey: const Key('guests-empty'),
      errorKey: const Key('guests-error'),
      onRetry: () => ref.invalidate(guestListProvider(key)),
      builder: (guests) => Column(
        children: [
          for (final g in guests)
            ListTile(
              key: Key('guest-${g.orderId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(g.name),
              subtitle: Text('${g.ticketLine}${g.ticketCode == null ? '' : ' · ${g.ticketCode}'}'),
              trailing: Text(checkedInLabel(g.checkedInAt), key: Key('guest-state-${g.orderId}'), style: theme.textTheme.labelMedium?.copyWith(color: g.checkedIn ? theme.colorScheme.primary : null)),
            ),
          if (guests.length >= (query.isEmpty ? 100 : 50)) Padding(padding: const EdgeInsets.only(top: 8), child: Text(query.isEmpty ? 'Showing the latest 100. Search to find someone else.' : 'Showing the first 50 matches. Type more to narrow it.', key: const Key('guests-cut'), style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
