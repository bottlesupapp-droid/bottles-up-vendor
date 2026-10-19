import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../organizer_events/logic/organizer_events_rules.dart';
import '../../organizer_events/providers/organizer_events_providers.dart';
import '../logic/agreement_rules.dart';
import '../providers/agreement_providers.dart';
import '../services/agreement_service.dart';

/// Ask a club to host an event (organizer): choose the event, find the club by name, add a message, send. The club's manager or owner
/// then proposes terms or declines. Asking again for the same event and club while a request is open is refused by the database.
class AskClubScreen extends ConsumerStatefulWidget {
  const AskClubScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<AskClubScreen> createState() => _AskClubScreenState();
}

class _AskClubScreenState extends ConsumerState<AskClubScreen> {
  final _search = TextEditingController();
  final _message = TextEditingController();
  String? _eventId;
  ClubMatch? _club;
  List<ClubMatch>? _results;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (_search.text.trim().length < 2) {
      setState(() => _problem = 'Type at least 2 letters of the club\'s name.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final found = await ref.read(agreementServiceProvider).searchClubs(_search.text);
      if (mounted) setState(() => _results = found);
    } on OpsActionException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_eventId == null) {
      setState(() => _problem = 'Choose the event.');
      return;
    }
    if (_club == null) {
      setState(() => _problem = 'Choose the club.');
      return;
    }
    final msg = checkRequestMessage(_message.text);
    if (msg != null) {
      setState(() => _problem = msg);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await ref.read(agreementServiceProvider).request(_eventId!, _club!.venueId, message: _message.text);
      if (mounted) Navigator.of(context).pop(true);
    } on OpsActionException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = ref.watch(organizerEventsProvider(widget.orgId));
    return Scaffold(
      appBar: AppBar(title: const Text('Ask a club to host')),
      body: SafeArea(
        child: ListView(
          key: const Key('ask-club'),
          padding: const EdgeInsets.all(16),
          children: [
            events.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Your events could not be loaded.', key: Key('ask-events-error')),
              data: (list) => list.isEmpty
                  ? const Text('Create an event first, then ask a club to host it.', key: Key('ask-no-events'))
                  : DropdownButtonFormField<String>(
                      key: const Key('ask-event'),
                      initialValue: _eventId,
                      decoration: const InputDecoration(labelText: 'Event'),
                      items: [for (final OrgEvent e in list) DropdownMenuItem(value: e.eventId, child: Text(e.title))],
                      onChanged: (v) => setState(() {
                        _eventId = v;
                        _problem = null;
                      }),
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ask-search'),
              controller: _search,
              decoration: InputDecoration(labelText: 'Find the club by name', suffixIcon: IconButton(key: const Key('ask-search-go'), icon: const Icon(Icons.search), onPressed: _busy ? null : _find)),
              onSubmitted: (_) => _find(),
            ),
            if (_results != null && _results!.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No club on BottlesUp matches that.', key: Key('ask-none'))),
            for (final c in _results ?? const <ClubMatch>[])
              ListTile(
                key: Key('ask-club-${c.venueId}'),
                contentPadding: EdgeInsets.zero,
                title: Text(c.name),
                subtitle: c.address == null ? null : Text(c.address!),
                trailing: _club?.venueId == c.venueId ? const Icon(Icons.check_circle) : null,
                onTap: () => setState(() {
                  _club = c;
                  _problem = null;
                }),
              ),
            if (_club != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Asking: ${_club!.name}', key: const Key('ask-chosen'), style: theme.textTheme.titleSmall)),
            const SizedBox(height: 12),
            TextField(key: const Key('ask-message'), controller: _message, minLines: 2, maxLines: 5, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Date, hours, rooms, tables, capacity (optional)', alignLabelWithHint: true)),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('ask-problem'), style: TextStyle(color: theme.colorScheme.error))),
            const SizedBox(height: 12),
            FilledButton(key: const Key('ask-send'), onPressed: _busy ? null : _send, child: Text(_busy ? 'Sending…' : 'Send request')),
          ],
        ),
      ),
    );
  }
}
