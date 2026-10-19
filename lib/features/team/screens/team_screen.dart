import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../owner/logic/owner_rules.dart' show OrgVenue, siteUrl;
import '../../owner/providers/owner_providers.dart';
import '../../owner/widgets/setup_common.dart' show confirmRemove;
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/team_rules.dart';
import '../providers/team_providers.dart';
import '../services/team_service.dart';
import '../widgets/invite_result_card.dart';
import '../widgets/team_badge.dart';
import 'invite_screen.dart';
import 'shifts_screen.dart';

/// Team (owner and manager): who works for the business, who has been invited and in what state, and the actions to invite, send a
/// new link, cancel, or remove access. What each person sees, and what they may do, is decided by the database: an owner sees
/// everyone, a manager only the staff of their own club. Nothing here grants access.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key, required this.workspace, this.pickDateTime = pickDateAndTime, this.openUri = openExternally, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTimePicker pickDateTime;
  final UriOpener openUri;
  final DateTime Function() clock;

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  IssuedInvite? _issued;
  String? _busyId;

  String get _orgId => widget.workspace.orgId;

  void _refresh() {
    ref.invalidate(teamMembersProvider(_orgId));
    ref.invalidate(teamInvitationsProvider(_orgId));
  }

  /// The clubs an invitation can be for: every venue of the business for an owner, the manager's own club for a manager.
  List<OrgVenue>? _venues() {
    final w = widget.workspace;
    if (w.role == WorkspaceRole.manager) {
      final id = w.venueId;
      return id == null ? const [] : [OrgVenue(id: id, name: w.venueName ?? 'Your club', status: 'draft')];
    }
    return ref.watch(ownerVenuesProvider(_orgId)).valueOrNull;
  }

  void _say(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _invite(List<OrgVenue> venues) async {
    final issued = await Navigator.of(context, rootNavigator: true).push<IssuedInvite>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => InviteScreen(workspace: widget.workspace, venues: venues, pickDateTime: widget.pickDateTime, clock: widget.clock),
      ),
    );
    if (issued == null || !mounted) return;
    setState(() => _issued = issued);
    _refresh();
  }

  Future<void> _newLink(TeamInvitation inv) async {
    setState(() => _busyId = inv.invitationId);
    final service = ref.read(teamServiceProvider);
    try {
      final issued = await service.sendNewLink(inv.invitationId);
      final outcome = await service.emailInvitation(inv.invitationId, issued.token);
      if (!mounted) return;
      setState(() => _issued = IssuedInvite(
            email: inv.email,
            roleLabel: roleLabel(inv.role),
            businessName: widget.workspace.orgName,
            link: invitationLink(siteUrl, issued.token),
            outcome: outcome,
          ));
      _refresh();
    } on TeamActionException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _cancel(TeamInvitation inv) async {
    final yes = await confirmRemove(
      context,
      title: 'Cancel the invitation to ${inv.email}?',
      body: 'The link stops working. You can invite them again later.',
      confirmLabel: 'Cancel invitation',
    );
    if (!yes || !mounted) return;
    try {
      await ref.read(teamServiceProvider).cancelInvitation(inv.invitationId);
      if (!mounted) return;
      _say('Invitation cancelled.');
      _refresh();
    } on TeamActionException catch (e) {
      if (mounted) _say(e.message);
    }
  }

  Future<void> _remove(TeamMember m) async {
    final yes = await confirmRemove(
      context,
      title: 'Remove ${displayName(m.name, m.email)}?',
      body: 'They lose access immediately. This is recorded, and you can invite them again later.',
      confirmLabel: 'Remove access',
    );
    if (!yes || !mounted) return;
    try {
      await ref.read(teamServiceProvider).removeMember(m.membershipId);
      if (!mounted) return;
      _say('Access removed.');
      _refresh();
    } on TeamActionException catch (e) {
      if (mounted) _say(e.message);
    }
  }

  Future<void> _shifts(List<OrgVenue> venues) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ShiftsScreen(venues: venues, pickDateTime: widget.pickDateTime, clock: widget.clock)));
  }

  Future<void> _changeRole(TeamMember m) async {
    List<String> roles;
    try {
      roles = rolesToChangeTo(await ref.read(teamServiceProvider).invitableRoles(_orgId, m.venueId!), m.role);
    } on TeamLoadException catch (e) {
      if (mounted) _say(e.message);
      return;
    }
    if (!mounted) return;
    if (roles.isEmpty) {
      _say('There is no other role you can give ${displayName(m.name, m.email)} here.');
      return;
    }
    final role = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Change ${displayName(m.name, m.email)} from ${roleLabel(m.role)} to', style: Theme.of(ctx).textTheme.titleMedium),
            for (final r in roles) ListTile(key: Key('role-option-$r'), contentPadding: EdgeInsets.zero, title: Text(roleLabel(r)), onTap: () => Navigator.of(ctx).pop(r)),
          ],
        ),
      ),
    );
    if (role == null || !mounted) return;
    final yes = await confirmRemove(
      context,
      title: 'Make ${displayName(m.name, m.email)} ${roleLabel(role).toLowerCase()}?',
      body: 'Their ${roleLabel(m.role).toLowerCase()} access ends now and the new role starts now, at the same club. This is recorded.',
      confirmLabel: 'Change role',
    );
    if (!yes || !mounted) return;
    setState(() => _busyId = m.membershipId);
    try {
      await ref.read(teamServiceProvider).changeRole(m.membershipId, role);
      if (!mounted) return;
      _say('Role changed.');
      _refresh();
    } on TeamActionException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _error(Object error) {
    final e = error is TeamLoadException ? error : const TeamLoadException(unavailable: false, accessEnded: false);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.message, key: const Key('team-error'), textAlign: TextAlign.center),
            if (!e.unavailable) ...[
              const SizedBox(height: 12),
              OutlinedButton(key: const Key('team-retry'), onPressed: _refresh, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = ref.watch(teamMembersProvider(_orgId));
    final invitations = ref.watch(teamInvitationsProvider(_orgId));
    final venues = _venues();

    final failure = members.error ?? invitations.error;
    if (failure != null) return _error(failure);
    if (!members.hasValue || !invitations.hasValue) return const Center(child: CircularProgressIndicator());

    final split = splitTeam(members.value!);
    final waiting = invitations.value!.where((i) => i.state.canSendNewLink).toList();
    final earlier = invitations.value!.where((i) => !i.state.canSendNewLink).toList();
    final noVenues = venues != null && venues.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        Text('Appoint managers and staff, give temporary access for a night or a shift, and remove access at any time.', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilledButton.icon(
              key: const Key('invite-button'),
              onPressed: venues == null || noVenues ? null : () => _invite(venues),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Invite someone'),
            ),
            OutlinedButton.icon(
              key: const Key('shifts-button'),
              onPressed: venues == null || noVenues ? null : () => _shifts(venues),
              icon: const Icon(Icons.schedule, size: 18),
              label: const Text('Shifts'),
            ),
          ],
        ),
        if (noVenues)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Add a venue first. People are invited to work at a club.', key: const Key('no-venues'), style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFFFB300))),
          ),
        const SizedBox(height: 16),
        if (_issued != null) InviteResultCard(invite: _issued!, openUri: widget.openUri, onClose: () => setState(() => _issued = null)),
        _heading(context, 'Invitations waiting (${waiting.length})'),
        if (waiting.isEmpty) Text('No invitations are waiting.', key: const Key('no-waiting'), style: theme.textTheme.bodySmall),
        for (final inv in waiting) _invitationCard(context, inv),
        const SizedBox(height: 20),
        _heading(context, 'Team (${split.current.length})'),
        if (split.current.isEmpty) Text('Nobody is on the team yet.', key: const Key('no-team'), style: theme.textTheme.bodySmall),
        for (final m in split.current) _memberCard(context, m),
        if (split.history.isNotEmpty || earlier.isNotEmpty) ...[
          const SizedBox(height: 12),
          ExpansionTile(
            key: const Key('history'),
            tilePadding: EdgeInsets.zero,
            title: Text('History (${split.history.length + earlier.length})', style: theme.textTheme.bodyMedium),
            children: [
              for (final m in split.history)
                ListTile(
                  key: Key('past-${m.membershipId}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${displayName(m.name, m.email)} · ${roleLabel(m.role)} · ${describeScope(m.venueName, m.eventTitle, m.shiftName)}'),
                  trailing: TeamBadge(label: m.state.label, tone: m.state.tone),
                ),
              for (final i in earlier)
                ListTile(
                  key: Key('past-${i.invitationId}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Invitation to ${i.email} · ${roleLabel(i.role)}'),
                  trailing: TeamBadge(label: i.state.label, tone: i.state.tone),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 0.8)),
      );

  Widget _invitationCard(BuildContext context, TeamInvitation inv) {
    final theme = Theme.of(context);
    final expires = inv.expiresAt;
    final linkNote = inv.state == InvitationState.expired
        ? 'Link expired'
        : (expires == null ? 'Link is waiting' : 'Link works until ${DateFormat.yMMMd('en_US').format(expires.toLocal())}');
    return Card(
      key: Key('invitation-${inv.invitationId}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(inv.email, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
                TeamBadge(label: inv.state.label, tone: inv.state.tone),
              ],
            ),
            Text('${roleLabel(inv.role)} · ${describeScope(inv.venueName, inv.eventTitle, inv.shiftName)}', style: theme.textTheme.bodySmall),
            Text(
              'Access: ${describeAccess(inv.accessStartAt, inv.accessEndAt)} · $linkNote${inv.emailsSent > 0 ? ' · Emailed ${inv.emailsSent} time${inv.emailsSent == 1 ? '' : 's'}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            Row(
              children: [
                if (inv.state.canSendNewLink)
                  TextButton(
                    key: Key('new-link-${inv.invitationId}'),
                    onPressed: _busyId == inv.invitationId ? null : () => _newLink(inv),
                    child: Text(_busyId == inv.invitationId ? 'Sending…' : 'Send a new link'),
                  ),
                if (inv.state.canCancel) TextButton(key: Key('cancel-${inv.invitationId}'), onPressed: () => _cancel(inv), child: const Text('Cancel invitation')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberCard(BuildContext context, TeamMember m) {
    final theme = Theme.of(context);
    return Card(
      key: Key('member-${m.membershipId}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(displayName(m.name, m.email), style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
                TeamBadge(label: m.state.label, tone: m.state.tone),
              ],
            ),
            if (m.name != null && m.email != null) Text(m.email!, style: theme.textTheme.bodySmall),
            Text('${roleLabel(m.role)} · ${describeScope(m.venueName, m.eventTitle, m.shiftName)}', style: theme.textTheme.bodySmall),
            Text('Access: ${describeAccess(m.accessStartAt, m.accessEndAt)}', style: theme.textTheme.bodySmall),
            if (canRemoveMember(m.role, m.state))
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  children: [
                    if (canChangeRole(m.role, m.state, venueId: m.venueId))
                      TextButton(key: Key('change-role-${m.membershipId}'), onPressed: _busyId == m.membershipId ? null : () => _changeRole(m), child: const Text('Change role')),
                    TextButton(
                      key: Key('remove-${m.membershipId}'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF5350)),
                      onPressed: () => _remove(m),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
