import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_time_picker.dart';
import '../../owner/logic/owner_rules.dart' show siteUrl;
import '../../team/logic/team_rules.dart';
import '../../team/providers/team_providers.dart';
import '../../team/services/team_service.dart';
import '../../team/widgets/invite_result_card.dart';

/// Invite door staff for one event (organizer). The email, and optionally a time window for the access. The database refuses the invitation unless the
/// event has no club or the club has allowed it, and its sentence is shown as it is; what was typed is kept. On success the link is shown once.
class InviteDoorStaffScreen extends ConsumerStatefulWidget {
  const InviteDoorStaffScreen({
    super.key,
    required this.orgId,
    required this.orgName,
    required this.eventId,
    required this.eventTitle,
    this.pickDateTime = pickDateAndTime,
    this.clock = DateTime.now,
  });

  final String orgId;
  final String orgName;
  final String eventId;
  final String eventTitle;
  final DateTimePicker pickDateTime;
  final DateTime Function() clock;

  @override
  ConsumerState<InviteDoorStaffScreen> createState() => _InviteDoorStaffScreenState();
}

class _InviteDoorStaffScreenState extends ConsumerState<InviteDoorStaffScreen> {
  final _email = TextEditingController();
  bool _limit = false;
  DateTime? _start;
  DateTime? _end;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final now = widget.clock();
    final initial = (start ? _start : _end) ?? (start ? now : (_start ?? now).add(const Duration(hours: 8)));
    final picked = await widget.pickDateTime(context, initial);
    if (picked == null || !mounted) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  String? _check() {
    if (!isValidEmail(_email.text)) return 'Enter a valid email address.';
    if (_limit) {
      if (_start == null || _end == null) return 'Choose when the access starts and ends, or turn the time limit off.';
      if (!_end!.isAfter(_start!)) return 'The access must end after it starts.';
      if (!_end!.isAfter(widget.clock())) return 'The access must end in the future.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final found = _check();
    setState(() => _problem = found);
    if (found != null) return;
    setState(() => _busy = true);
    final service = ref.read(teamServiceProvider);
    try {
      final issued = await service.inviteEventDoor(widget.orgId, widget.eventId, _email.text, accessStartAt: _limit ? _start : null, accessEndAt: _limit ? _end : null);
      final outcome = await service.emailInvitation(issued.invitationId, issued.token);
      if (!mounted) return;
      Navigator.of(context).pop(IssuedInvite(
        email: _email.text.trim().toLowerCase(),
        roleLabel: roleLabel('door'),
        businessName: widget.orgName,
        link: invitationLink(siteUrl, issued.token),
        outcome: outcome,
      ));
    } on TeamActionException catch (e) {
      if (mounted) {
        setState(() {
          _problem = e.message;
          _busy = false;
        });
      }
    }
  }

  String _when(DateTime? t) => t == null ? 'Choose' : DateFormat('MMM d, h:mm a', 'en_US').format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Invite door staff')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(widget.eventTitle, key: const Key('invite-door-event'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('They will be able to scan and admit guests for this event only. They cannot change prices, issue refunds or reach banking.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            key: const Key('invite-door-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Email', helperText: 'They must sign in with this address to accept.', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            key: const Key('invite-door-limit'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Limit access to a time window'),
            subtitle: const Text('Otherwise they have access until you remove them.'),
            value: _limit,
            onChanged: _busy ? null : (v) => setState(() => _limit = v),
          ),
          if (_limit)
            Row(
              children: [
                Expanded(child: OutlinedButton(key: const Key('invite-door-start'), onPressed: _busy ? null : () => _pick(true), child: Text('From: ${_when(_start)}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(key: const Key('invite-door-end'), onPressed: _busy ? null : () => _pick(false), child: Text('Until: ${_when(_end)}'))),
              ],
            ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_problem!, key: const Key('invite-door-problem'), style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton(key: const Key('invite-door-submit'), onPressed: _busy ? null : _submit, child: Text(_busy ? 'Sending...' : 'Send invitation')),
        ],
      ),
    );
  }
}
