import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/door_staff_rules.dart';

/// The calls behind organizer-provided door staff (website repo, 20261020130000_organizer_door_staff.sql). The database decides who may do what
/// and enforces the club's permission when an invitation is made; nothing here decides any of it.
class DoorStaffService {
  DoorStaffService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  /// The organizer's events and whether door staff may be invited to each.
  Future<List<EventDoorStatus>> status(String orgId) => _rpc.list('organizer_event_door_status', {'p_org': orgId}, parseEventDoorStatus, 'your events');

  /// The club's live agreements and whether each allows the organizer's door staff.
  Future<List<DoorPermission>> permissions(String venueId) => _rpc.list('venue_door_permissions', {'p_venue': venueId}, parseDoorPermission, 'the permissions');

  Future<List<ClubDoorStaff>> clubStaff(String venueId) => _rpc.list('venue_event_door_staff', {'p_venue': venueId}, parseClubDoorStaff, 'the door staff');

  Future<bool> setAllowed(String agreementId, bool allowed) => _rpc.act(() async {
        final data = await _rpc.call('set_organizer_door_staff', {'p_agreement': agreementId, 'p_allowed': allowed});
        return data == true;
      }, generic: 'The permission could not be saved. Check your connection and try again.');

  Future<void> revokeMember(String membershipId) => _rpc.act(() async {
        await _rpc.call('revoke_event_door_access', {'p_membership': membershipId, 'p_invitation': null});
      }, generic: 'Access could not be removed. Check your connection and try again.');

  Future<void> revokeInvitation(String invitationId) => _rpc.act(() async {
        await _rpc.call('revoke_event_door_access', {'p_membership': null, 'p_invitation': invitationId});
      }, generic: 'The invitation could not be cancelled. Check your connection and try again.');
}
