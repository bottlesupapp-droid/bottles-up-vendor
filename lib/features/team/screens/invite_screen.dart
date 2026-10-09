import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../owner/logic/owner_rules.dart' show OrgVenue, siteUrl;
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../../workspace/models/workspace.dart';
import '../logic/team_rules.dart';
import '../providers/team_providers.dart';
import '../services/team_service.dart';
import '../widgets/invite_result_card.dart';

/// Picks a date and time. Replaced in tests; in the app it is Flutter's date picker followed by its time picker.
typedef DateTimePicker = Future<DateTime?> Function(BuildContext context, DateTime initial);

Future<DateTime?> pickDateAndTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 730)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Invite someone to a club. The roles offered come from the database (invitable_roles), so a manager is never shown "Manager" and
/// nobody is offered something the server would refuse. Access can be ongoing or temporary, and can be tied to a shift. Pops the
/// issued invitation (the link and what happened to the email), or null if closed.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.workspace, required this.venues, this.pickDateTime = pickDateAndTime, this.clock = DateTime.now});

  final Workspace workspace;

  /// The clubs the person may invite to: every venue of the business for an owner, their own club for a manager.
  final List<OrgVenue> venues;
  final DateTimePicker pickDateTime;
  final DateTime Function() clock;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _email = TextEditingController();
  late String _venueId = widget.venues.first.id;
  String _role = '';
  String _shiftId = '';
  bool _temporary = false;
  DateTime? _start;
  DateTime? _end;
  List<String> _problems = const [];
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String get _orgId => widget.workspace.orgId;

  Future<void> _pick(bool start) async {
    final now = widget.clock();
    final initial = (start ? _start : _end) ?? (start ? now : (_start ?? now).add(const Duration(hours: 6)));
    final picked = await widget.pickDateTime(context, initial);
    if (picked == null || !mounted) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _submit(List<String> roles, List<Shift> shifts) async {
    if (_busy) return;
    final role = roles.contains(_role) ? _role : (roles.isEmpty ? '' : roles.first);
    final shift = shifts.any((s) => s.shiftId == _shiftId) ? _shiftId : '';
    final form = InviteForm(email: _email.text, role: role, venueId: _venueId, temporary: _temporary, start: _start, end: _end, shiftId: shift);
    final found = validateInvite(form, now: widget.clock());
    setState(() => _problems = found);
    if (found.isNotEmpty) return;

    setState(() => _busy = true);
    final service = ref.read(teamServiceProvider);
    try {
      final payload = buildInvitePayload(form);
      final issued = await service.invite(_orgId, payload);
      final outcome = await service.emailInvitation(issued.invitationId, issued.token);
      if (!mounted) return;
      Navigator.of(context).pop(IssuedInvite(
        email: payload.email,
        roleLabel: roleLabel(payload.role),
        businessName: widget.workspace.orgName,
        link: invitationLink(siteUrl, issued.token),
        outcome: outcome,
      ));
    } on TeamActionException catch (e) {
      if (mounted) {
        setState(() {
          _problems = [e.message];
          _busy = false;
        });
      }
    }
  }

  String _when(DateTime? t, String empty) => t == null ? empty : DateFormat('MMM d, h:mm a', 'en_US').format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rolesAsync = ref.watch(invitableRolesProvider(RoleQuery(_orgId, _venueId)));
    final shifts = ref.watch(venueShiftsProvider(_venueId)).valueOrNull ?? const <Shift>[];
    final roles = rolesAsync.valueOrNull ?? const <String>[];
    final effectiveRole = roles.contains(_role) ? _role : (roles.isEmpty ? '' : roles.first);
    final noRoles = rolesAsync.hasValue && roles.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Invite someone')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          TextField(
            key: const Key('invite-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email', helperText: 'They must sign in with this address to accept.', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          if (widget.venues.length > 1)
            DropdownButtonFormField<String>(
              key: const Key('invite-venue'),
              initialValue: _venueId,
              decoration: const InputDecoration(labelText: 'Club', border: OutlineInputBorder()),
              items: [for (final v in widget.venues) DropdownMenuItem(value: v.id, child: Text(v.name))],
              onChanged: (v) => setState(() {
                _venueId = v ?? _venueId;
                _shiftId = '';
              }),
            )
          else
            Text('Club: ${widget.venues.first.name}', key: const Key('invite-club'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text('Role', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (rolesAsync.isLoading) const LinearProgressIndicator(),
          if (rolesAsync.hasError) Text('The roles could not be loaded. Check your connection and try again.', key: const Key('roles-error'), style: theme.textTheme.bodySmall),
          if (noRoles) Text('You cannot appoint anyone at this club.', key: const Key('no-roles'), style: theme.textTheme.bodySmall),
          Wrap(
            spacing: 8,
            children: [
              for (final r in roles)
                ChoiceChip(
                  key: Key('role-$r'),
                  label: Text(roleLabel(r)),
                  selected: effectiveRole == r,
                  onSelected: (_) => setState(() => _role = r),
                ),
            ],
          ),
          if (shifts.isNotEmpty) ...[
            const SizedBox(height: 16),
            // initialValue only applies when the field is built, so a different club (a different list of shifts) builds a new one.
            KeyedSubtree(
              key: ValueKey('shifts-$_venueId'),
              child: DropdownButtonFormField<String>(
                key: const Key('invite-shift'),
                initialValue: shifts.any((s) => s.shiftId == _shiftId) ? _shiftId : '',
                decoration: const InputDecoration(labelText: 'Shift (optional)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '', child: Text('No shift')),
                  for (final s in shifts) DropdownMenuItem(value: s.shiftId, child: Text('${s.name} · ${_when(s.startsAt, '')}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _shiftId = v ?? ''),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('invite-temporary'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Temporary access'),
            subtitle: const Text('For a night or a shift. Otherwise it lasts until you remove them.'),
            value: _temporary,
            onChanged: (v) => setState(() => _temporary = v),
          ),
          if (_temporary)
            Row(
              children: [
                Expanded(child: OutlinedButton(key: const Key('pick-start'), onPressed: () => _pick(true), child: Text(_when(_start, 'Choose start')))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(key: const Key('pick-end'), onPressed: () => _pick(false), child: Text(_when(_end, 'Choose end')))),
              ],
            ),
          const SizedBox(height: 16),
          ProblemsBox(problems: _problems),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('send-invite'),
            onPressed: _busy || noRoles ? null : () => _submit(roles, shifts),
            child: Text(_busy ? 'Sending…' : 'Send invitation'),
          ),
        ],
      ),
    );
  }
}
