import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_time_picker.dart';
import '../../ops/services/ops_rpc.dart';
import '../../owner/widgets/setup_common.dart' show confirmRemove;
import '../../server_desk/widgets/desk_chip.dart';
import '../../team/logic/team_rules.dart';
import '../../team/providers/team_providers.dart';
import '../../team/services/team_service.dart';
import '../../team/widgets/invite_result_card.dart';
import '../../workspace/models/workspace.dart';
import '../logic/door_staff_rules.dart';
import '../providers/door_staff_providers.dart';
import 'invite_door_staff_screen.dart';

/// The organizer's Team: door staff, event by event. Each event says whether door staff may be invited (the event has no club, or the club has allowed it),
/// lists who is in and who has been invited, and offers Invite only when the database would accept it. Removing someone and cancelling an invitation are
/// the organizer's own. The club's permission is the club's: it is shown, never changed here.
class OrganizerTeamScreen extends ConsumerStatefulWidget {
  const OrganizerTeamScreen({super.key, required this.workspace, this.pickDateTime = pickDateAndTime, this.clock = DateTime.now, this.openUri = openExternally});

  final Workspace workspace;
  final DateTimePicker pickDateTime;
  final DateTime Function() clock;
  final UriOpener openUri;

  @override
  ConsumerState<OrganizerTeamScreen> createState() => _OrganizerTeamScreenState();
}

class _OrganizerTeamScreenState extends ConsumerState<OrganizerTeamScreen> {
  IssuedInvite? _issued;
  final Set<String> _busy = {};

  String get _orgId => widget.workspace.orgId;

  void _reload() {
    ref.invalidate(eventDoorStatusProvider(_orgId));
    ref.invalidate(teamMembersProvider(_orgId));
    ref.invalidate(teamInvitationsProvider(_orgId));
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _invite(EventDoorStatus e) async {
    final issued = await Navigator.of(context).push<IssuedInvite>(
      MaterialPageRoute(
        builder: (_) => InviteDoorStaffScreen(orgId: _orgId, orgName: widget.workspace.orgName, eventId: e.eventId, eventTitle: e.title, pickDateTime: widget.pickDateTime, clock: widget.clock),
      ),
    );
    if (!mounted) return;
    _reload();
    if (issued != null) setState(() => _issued = issued);
  }

  Future<void> _removeMember(TeamMember m) async {
    final yes = await confirmRemove(context, title: 'Remove ${m.name ?? m.email ?? 'this person'}?', body: 'They lose access to this event straight away.', confirmLabel: 'Remove', keepLabel: 'Keep');
    if (!yes || !mounted) return;
    setState(() => _busy.add(m.membershipId));
    try {
      await ref.read(teamServiceProvider).removeMember(m.membershipId);
      if (mounted) _say('Access removed.');
    } on TeamActionException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      _reload();
      if (mounted) setState(() => _busy.remove(m.membershipId));
    }
  }

  Future<void> _cancelInvitation(TeamInvitation i) async {
    setState(() => _busy.add(i.invitationId));
    try {
      await ref.read(teamServiceProvider).cancelInvitation(i.invitationId);
      if (mounted) _say('Invitation cancelled.');
    } on TeamActionException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      _reload();
      if (mounted) setState(() => _busy.remove(i.invitationId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ref.watch(eventDoorStatusProvider(_orgId));
    final members = ref.watch(teamMembersProvider(_orgId)).valueOrNull ?? const <TeamMember>[];
    final invitations = ref.watch(teamInvitationsProvider(_orgId)).valueOrNull ?? const <TeamInvitation>[];

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        try {
          await ref.read(eventDoorStatusProvider(_orgId).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        key: const Key('organizer-team'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Door staff for your events', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Door staff scan and admit your guests. You invite them for each event. If a club hosts the event, the club has to allow it first. $doorStaffLimits', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          if (_issued != null) InviteResultCard(invite: _issued!, openUri: widget.openUri, onClose: () => setState(() => _issued = null)),
          status.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            error: (error, _) {
              final e = opsLoadFailureFor(error, 'your events');
              return Column(
                children: [
                  Text(e.message, key: const Key('team-error'), textAlign: TextAlign.center),
                  if (!e.unavailable)
                    Padding(padding: const EdgeInsets.only(top: 12), child: OutlinedButton(key: const Key('team-retry'), onPressed: _reload, child: const Text('Try again'))),
                ],
              );
            },
            data: (events) => events.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('You have no events yet. Create an event first, then invite its door staff here.', key: const Key('team-no-events'), style: theme.textTheme.bodyMedium),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final e in events) _eventCard(context, e, members, invitations)],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(BuildContext context, EventDoorStatus e, List<TeamMember> members, List<TeamInvitation> invitations) {
    final theme = Theme.of(context);
    final staff = [for (final m in members) if (m.eventId == e.eventId && m.role == 'door' && m.state != MemberState.revoked) m];
    final waiting = [for (final i in invitations) if (i.eventId == e.eventId && i.role == 'door' && (i.state == InvitationState.pending || i.state == InvitationState.expired)) i];
    final color = switch (e.state) {
      EventDoorState.ownEvent || EventDoorState.allowed => const Color(0xFF66BB6A),
      EventDoorState.notAllowed => const Color(0xFFFFB300),
      EventDoorState.awaitingApproval => const Color(0xFF42A5F5),
    };
    return Card(
      key: Key('team-event-${e.eventId}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(e.title, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                DeskChip(key: Key('team-state-${e.eventId}'), text: doorStateLabel(e.state), color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(doorStateSentence(e), key: Key('team-sentence-${e.eventId}'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (staff.isEmpty && waiting.isEmpty) Text('No door staff yet.', key: Key('team-none-${e.eventId}'), style: theme.textTheme.bodyMedium),
            for (final m in staff)
              ListTile(
                key: Key('team-member-${m.membershipId}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(m.name ?? m.email ?? 'Door staff'),
                subtitle: Text(m.state == MemberState.active ? 'Has access' : m.state == MemberState.scheduled ? 'Access not started yet' : 'Access ended'),
                trailing: TextButton(
                  key: Key('team-remove-${m.membershipId}'),
                  onPressed: _busy.contains(m.membershipId) ? null : () => _removeMember(m),
                  child: const Text('Remove'),
                ),
              ),
            for (final i in waiting)
              ListTile(
                key: Key('team-invitation-${i.invitationId}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(i.email),
                subtitle: Text(i.state == InvitationState.expired ? 'Invitation expired' : 'Invited, not accepted yet'),
                trailing: TextButton(
                  key: Key('team-cancel-${i.invitationId}'),
                  onPressed: _busy.contains(i.invitationId) ? null : () => _cancelInvitation(i),
                  child: const Text('Cancel'),
                ),
              ),
            if (e.state.canInvite)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(key: Key('team-invite-${e.eventId}'), onPressed: () => _invite(e), icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Invite door staff')),
              ),
          ],
        ),
      ),
    );
  }
}
