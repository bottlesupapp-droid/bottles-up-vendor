import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../logic/door_rules.dart';
import '../providers/door_providers.dart';
import '../services/door_service.dart';
import '../widgets/door_event_bar.dart';
import '../widgets/door_message.dart';
import '../widgets/scan_result_panel.dart';

/// Guests (door role): find a paid guest of the selected event by name or ticket code and admit them from the list, through
/// exactly the same database checks as a scan, including the entry code for non-transferable tickets. For the guest whose QR
/// will not scan, or who left their phone at home.
class DoorGuestsScreen extends ConsumerStatefulWidget {
  const DoorGuestsScreen({super.key, required this.membershipId, this.debounce = const Duration(milliseconds: 350)});

  final String membershipId;

  /// How long typing must pause before a search runs. Short in tests.
  final Duration debounce;

  @override
  ConsumerState<DoorGuestsScreen> createState() => _DoorGuestsScreenState();
}

class _DoorGuestsScreenState extends ConsumerState<DoorGuestsScreen> {
  final _search = TextEditingController();
  Timer? _timer;
  int _seq = 0;

  List<Guest>? _guests;
  bool _loading = false;
  String? _error;

  bool _verifying = false;
  ScanOutcome? _outcome;
  String? _ticket;

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String text, DoorEvent event) {
    _timer?.cancel();
    if (text.trim().length < 2) {
      // Fewer than two characters is "no search": forget any search still on its way.
      _seq++;
      setState(() {
        _guests = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    _timer = Timer(widget.debounce, () => _run(text, event));
  }

  Future<void> _run(String text, DoorEvent event) async {
    final mine = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await ref.read(doorServiceProvider).guests(event.eventId, text);
      // A slower, older answer must not replace a newer one.
      if (!mounted || mine != _seq) return;
      setState(() {
        _guests = found;
        _loading = false;
      });
    } on DoorLoadException catch (e) {
      if (!mounted || mine != _seq) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _admit(Guest guest, DoorEvent event) async {
    final outcome = await ref.read(doorServiceProvider).scan(guest.ticketCode, event.eventId);
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      _ticket = guest.ticketCode;
    });
    _afterAnswer(outcome, guest.ticketCode);
  }

  Future<void> _verify(String entryCode, DoorEvent event) async {
    final ticket = _ticket;
    if (ticket == null || _verifying) return;
    setState(() => _verifying = true);
    final outcome = await ref.read(doorServiceProvider).verifyCode(ticket, entryCode, event.eventId);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _outcome = outcome;
    });
    _afterAnswer(outcome, ticket);
  }

  void _afterAnswer(ScanOutcome outcome, String ticketCode) {
    HapticFeedback.mediumImpact();
    if (!outcome.admitted) return;
    // The list shows this guest as in, without asking again; the count of guests in is read again.
    final guests = _guests;
    if (guests != null) {
      setState(() {
        _guests = [
          for (final g in guests)
            if (g.ticketCode == ticketCode)
              Guest(
                orderId: g.orderId,
                name: g.name,
                ticketCode: g.ticketCode,
                tierName: g.tierName,
                quantity: g.quantity,
                checkedInAt: DateTime.now(),
                needsCode: g.needsCode,
              )
            else
              g,
        ];
      });
    }
    ref.invalidate(doorEventsProvider(widget.membershipId));
  }

  void _done() => setState(() {
        _outcome = null;
        _ticket = null;
      });

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(doorEventsProvider(widget.membershipId));
    return events.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DoorMessage(
        text: error is DoorLoadException ? error.message : doorLoadMessage(unavailable: false, accessEnded: false),
        onRetry: error is DoorLoadException && error.unavailable ? null : () => ref.invalidate(doorEventsProvider(widget.membershipId)),
      ),
      data: (list) {
        final event = resolveEvent(list, ref.watch(selectedDoorEventProvider(widget.membershipId)));
        if (event == null) {
          return DoorMessage(
            text: 'No event to search right now.',
            onRetry: () => ref.invalidate(doorEventsProvider(widget.membershipId)),
          );
        }
        return _body(list, event);
      },
    );
  }

  Widget _body(List<DoorEvent> events, DoorEvent event) {
    final theme = Theme.of(context);
    final guests = _guests;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        DoorEventBar(
          events: events,
          selected: event,
          onSelect: (id) {
            ref.read(selectedDoorEventProvider(widget.membershipId).notifier).state = id;
            _seq++;
            _search.clear();
            setState(() {
              _guests = null;
              _outcome = null;
              _ticket = null;
              _error = null;
              _loading = false;
            });
          },
        ),
        const SizedBox(height: 16),
        if (_outcome != null) ...[
          ScanResultPanel(outcome: _outcome!, verifying: _verifying, onVerify: (c) => _verify(c, event), onNext: _done, nextLabel: 'Done'),
          const SizedBox(height: 16),
        ],
        TextField(
          key: const Key('guest-search-field'),
          controller: _search,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Search by name or ticket code',
            prefixIcon: Icon(Ionicons.search_outline),
            border: OutlineInputBorder(),
          ),
          onChanged: (t) => _onChanged(t, event),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(key: Key('searching')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('search-error'), style: TextStyle(color: theme.colorScheme.error))),
        if (guests == null && !_loading && _error == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Type at least two letters of a name, or part of a ticket code.', style: theme.textTheme.bodyMedium),
          ),
        if (guests != null && guests.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No paid guest matches. Check the spelling, or try the ticket code.', key: const Key('no-guests'), style: theme.textTheme.bodyMedium),
          ),
        if (guests != null)
          for (final g in guests) _GuestTile(guest: g, onAdmit: () => _admit(g, event)),
      ],
    );
  }
}

class _GuestTile extends StatelessWidget {
  const _GuestTile({required this.guest, required this.onAdmit});

  final Guest guest;
  final VoidCallback onAdmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('guest-${guest.ticketCode}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(guest.name, style: theme.textTheme.titleMedium),
                  Text('${guest.tierName.isEmpty ? 'Ticket' : guest.tierName} × ${guest.quantity}'),
                  Text(guest.ticketCode, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                  if (guest.needsCode && !guest.isIn) Text('Needs an entry code', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (guest.isIn)
              const Chip(key: Key('guest-in'), avatar: Icon(Ionicons.checkmark_circle, size: 18), label: Text('In'))
            else
              FilledButton(key: Key('admit-${guest.ticketCode}'), onPressed: onAdmit, child: const Text('Admit')),
          ],
        ),
      ),
    );
  }
}
