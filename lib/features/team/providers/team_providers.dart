import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/team_rules.dart';
import '../services/team_service.dart';

final teamServiceProvider = Provider<TeamService>((ref) => TeamService());

/// The people of one business that this person may see. Not kept once the screen is gone: a stale list of who has access is worse
/// than a slow one.
final teamMembersProvider = FutureProvider.autoDispose.family<List<TeamMember>, String>((ref, orgId) => ref.watch(teamServiceProvider).team(orgId));

final teamInvitationsProvider =
    FutureProvider.autoDispose.family<List<TeamInvitation>, String>((ref, orgId) => ref.watch(teamServiceProvider).invitations(orgId));

/// What may be offered when inviting depends on the club.
class RoleQuery {
  const RoleQuery(this.orgId, this.venueId);

  final String orgId;
  final String venueId;

  @override
  bool operator ==(Object other) => other is RoleQuery && other.orgId == orgId && other.venueId == venueId;

  @override
  int get hashCode => Object.hash(orgId, venueId);
}

final invitableRolesProvider =
    FutureProvider.autoDispose.family<List<String>, RoleQuery>((ref, q) => ref.watch(teamServiceProvider).invitableRoles(q.orgId, q.venueId));

final venueShiftsProvider = FutureProvider.autoDispose.family<List<Shift>, String>((ref, venueId) => ref.watch(teamServiceProvider).shifts(venueId));
