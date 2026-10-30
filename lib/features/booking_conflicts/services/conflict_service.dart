import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/conflict_rules.dart';

/// The double-booked table calls (website repo, 20261113100000_oversold_booking_queue.sql). The database decides who may see and close one (the club's manager or owner) and checks the
/// facts when one is closed; nothing here decides any of it. Money is never moved from here: a refund is the booking's own refund flow.
class BookingConflictService {
  BookingConflictService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  /// The club's conflicts: the open ones first. [includeSettled] adds the ones already dealt with.
  Future<List<BookingConflict>> list(String venueId, {bool includeSettled = false}) =>
      _rpc.list('desk_booking_conflicts', {'p_venue': venueId, 'p_include_resolved': includeSettled}, parseConflict, 'the double-booked tables');

  /// Closes one with how it was settled and a few words. The database refuses a "moved" that is still overbooked and a "refunded" that is not.
  Future<void> resolve(String conflictId, ConflictResolution? how, String note) => _rpc.act(() async {
        final problem = validateResolution(how, note);
        if (problem != null) throw OpsActionException(problem);
        await _rpc.call('desk_resolve_booking_conflict', resolveParams(conflictId, how!, note));
      }, generic: 'This could not be saved. Check your connection and look at the list before trying again.');
}
