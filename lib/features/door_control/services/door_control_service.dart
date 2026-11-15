import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/door_control_rules.dart';

/// The owner's and the manager's door calls (website repo, 20261122100000_door_exits_and_overrides.sql). The database decides who may do each (owner, organizer, or the club's
/// manager; never door staff) and which refusals an override may lift; nothing here decides any of it.
class DoorControlService {
  DoorControlService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  /// The club's nights that are on or only just ended.
  Future<List<ClubNight>> nights(String venueId) => _rpc.list('door_club_nights', {'p_venue': venueId}, parseClubNight, 'the club\'s nights');

  /// Turns exit tracking on or off for a night. Exits already recorded are kept either way.
  Future<void> setExitTracking(String eventId, bool on) => _rpc.act(() async {
    await _rpc.call('set_event_exit_tracking', {'p_event': eventId, 'p_on': on});
  }, generic: 'This could not be saved. Check your connection and look at the night before trying again.');

  /// Admits a guest the scan held back only because of the entry code, with a reason that is kept. [count] is for a group ticket (the answer says when it must be chosen).
  Future<OverrideOutcome> override(String ticketCode, String reason, {int? count, String? eventId}) => _rpc.act(() async {
    final problem = validateOverrideReason(reason);
    if (problem != null) throw OpsActionException(problem);
    final code = ticketCode.trim();
    if (code.isEmpty) throw const OpsActionException('Type or scan the ticket code first.');
    final data = await _rpc.call('door_override_entry', {'p_ticket_code': code, 'p_reason': reason.trim(), 'p_count': count, 'p_event': eventId});
    final rows = OpsRpc.rows(data);
    final outcome = parseOverrideOutcome(rows.isEmpty ? null : rows.first);
    if (outcome == null) throw const OpsActionException('The answer could not be read. Look at the guest list before trying again.');
    return outcome;
  }, generic: 'This could not be done. Check your connection and look at the guest list before trying again.');

  /// The overrides recorded for a night, newest first.
  Future<List<OverrideLogEntry>> log(String eventId) => _rpc.list('door_override_log', {'p_event': eventId}, parseOverrideLogEntry, 'the overrides');
}
