import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/providers/owner_providers.dart';
import '../../owner/services/owner_service.dart';
import '../../owner/widgets/setup_common.dart' show confirmRemove;
import '../../workspace/models/workspace.dart';
import '../logic/door_staff_rules.dart';
import '../providers/door_staff_providers.dart';

/// The club's side of organizer door staff (owner and manager): for each event hosted at the club, whether the organizer may invite its own door staff
/// (the club decides, per event, and can change its mind), and the organizers' door staff and invitations at the club's events, each of which the club can
/// take away. Turning a permission off cancels the invitations still waiting; people already in keep access until removed one by one.
class ClubDoorStaffScreen extends ConsumerStatefulWidget {
  const ClubDoorStaffScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<ClubDoorStaffScreen> createState() => _ClubDoorStaffScreenState();
}

class _ClubDoorStaffScreenState extends ConsumerState<ClubDoorStaffScreen> {
  String? _venueId;
  final Set<String> _busy = {};

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _reload(String venueId) {
    ref.invalidate(doorPermissionsProvider(venueId));
    ref.invalidate(clubDoorStaffProvider(venueId));
  }

  Future<void> _setAllowed(String venueId, DoorPermission p, bool allowed) async {
    if (!allowed) {
      final yes = await confirmRemove(
        context,
        title: 'Stop ${p.organizerName} inviting door staff?',
        body: 'Invitations still waiting for ${p.eventTitle} are cancelled. People already in keep their access until you remove them.',
        confirmLabel: 'Turn off',
        keepLabel: 'Keep it on',
      );
      if (!yes || !mounted) return;
    }
    setState(() => _busy.add(p.agreementId));
    try {
      await ref.read(doorStaffServiceProvider).setAllowed(p.agreementId, allowed);
      if (mounted) _say(allowed ? 'Allowed. ${p.organizerName} can invite door staff for ${p.eventTitle}.' : 'Turned off for ${p.eventTitle}.');
    } on OpsActionException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      _reload(venueId);
      if (mounted) setState(() => _busy.remove(p.agreementId));
    }
  }

  Future<void> _revoke(String venueId, ClubDoorStaff s) async {
    final key = s.membershipId ?? s.invitationId!;
    final yes = await confirmRemove(
      context,
      title: s.isInvitation ? 'Cancel the invitation to ${s.person}?' : 'Remove ${s.person}?',
      body: s.isInvitation ? 'The link stops working.' : 'They lose access to ${s.eventTitle} at your club straight away.',
      confirmLabel: s.isInvitation ? 'Cancel invitation' : 'Remove',
      keepLabel: 'Keep',
    );
    if (!yes || !mounted) return;
    setState(() => _busy.add(key));
    try {
      final service = ref.read(doorStaffServiceProvider);
      if (s.isInvitation) {
        await service.revokeInvitation(s.invitationId!);
      } else {
        await service.revokeMember(s.membershipId!);
      }
      if (mounted) _say(s.isInvitation ? 'Invitation cancelled.' : 'Access removed.');
    } on OpsActionException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      _reload(venueId);
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fixed = widget.workspace.venueId;
    if (fixed != null && fixed.isNotEmpty) return _content(context, fixed, theme);

    // An owner's workspace is not tied to a club: pick one.
    final venues = ref.watch(ownerVenuesProvider(widget.workspace.orgId));
    return venues.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final e = error is OwnerLoadException ? error : const OwnerLoadException(unavailable: false, accessEnded: false);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.message, key: const Key('club-door-error'), textAlign: TextAlign.center),
                if (!e.unavailable)
                  Padding(padding: const EdgeInsets.only(top: 12), child: OutlinedButton(key: const Key('club-door-retry'), onPressed: () => ref.invalidate(ownerVenuesProvider(widget.workspace.orgId)), child: const Text('Try again'))),
              ],
            ),
          ),
        );
      },
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No venues yet. Add a venue first.', key: const Key('club-door-no-venues'), style: theme.textTheme.bodyLarge)));
        }
        final chosen = list.firstWhere((v) => v.id == _venueId, orElse: () => list.first);
        return Column(
          children: [
            if (list.length > 1)
              SizedBox(
                height: 56,
                child: ListView(
                  key: const Key('club-door-venues'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  children: [
                    for (final v in list)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(key: Key('club-door-venue-${v.id}'), label: Text(v.name), selected: v.id == chosen.id, onSelected: (_) => setState(() => _venueId = v.id)),
                      ),
                  ],
                ),
              ),
            Expanded(child: _content(context, chosen.id, theme)),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, String venueId, ThemeData theme) {
    final permissions = ref.watch(doorPermissionsProvider(venueId));
    final staff = ref.watch(clubDoorStaffProvider(venueId));
    return RefreshIndicator(
      onRefresh: () async {
        _reload(venueId);
        try {
          await ref.read(doorPermissionsProvider(venueId).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        key: Key('club-door-$venueId'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Organizers\' door staff', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('An organizer can invite its own door staff to an event at your club only if you allow it for that event. $doorStaffLimits', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Text('Events at your club', style: theme.textTheme.titleMedium),
          permissions.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            error: (error, _) {
              final e = opsLoadFailureFor(error, 'the permissions');
              return Column(
                children: [
                  Text(e.message, key: const Key('club-door-permissions-error'), textAlign: TextAlign.center),
                  if (!e.unavailable) OutlinedButton(key: const Key('club-door-permissions-retry'), onPressed: () => _reload(venueId), child: const Text('Try again')),
                ],
              );
            },
            data: (list) => list.isEmpty
                ? Padding(padding: const EdgeInsets.only(top: 8), child: Text('No organizer has an event agreement with your club yet.', key: const Key('club-door-none'), style: theme.textTheme.bodyMedium))
                : Column(
                    children: [
                      for (final p in list)
                        SwitchListTile(
                          key: Key('club-door-switch-${p.agreementId}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.eventTitle),
                          subtitle: Text('${p.organizerName}${p.eventStart == null ? '' : ' · ${DateFormat('MMM d').format(p.eventStart!)}'}\n${permissionSentence(p)}'),
                          isThreeLine: true,
                          value: p.allowed,
                          onChanged: _busy.contains(p.agreementId) ? null : (v) => _setAllowed(venueId, p, v),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Text('Door staff at your events', style: theme.textTheme.titleMedium),
          staff.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            error: (error, _) {
              final e = opsLoadFailureFor(error, 'the door staff');
              return Column(
                children: [
                  Text(e.message, key: const Key('club-door-staff-error'), textAlign: TextAlign.center),
                  if (!e.unavailable) OutlinedButton(key: const Key('club-door-staff-retry'), onPressed: () => _reload(venueId), child: const Text('Try again')),
                ],
              );
            },
            data: (list) => list.isEmpty
                ? Padding(padding: const EdgeInsets.only(top: 8), child: Text('No door staff from organizers yet.', key: const Key('club-door-staff-none'), style: theme.textTheme.bodyMedium))
                : Column(
                    children: [
                      for (final s in list)
                        ListTile(
                          key: Key('club-door-staff-${s.membershipId ?? s.invitationId}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.person),
                          subtitle: Text('${s.eventTitle} · ${s.organizerName}\n${clubStaffStateLabel(s.state)}'),
                          isThreeLine: true,
                          trailing: s.canRevoke
                              ? TextButton(
                                  key: Key('club-door-revoke-${s.membershipId ?? s.invitationId}'),
                                  onPressed: _busy.contains(s.membershipId ?? s.invitationId) ? null : () => _revoke(venueId, s),
                                  child: Text(s.isInvitation ? 'Cancel' : 'Remove'),
                                )
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
