import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/guest_rules.dart';

/// The calls to the website's organizer guest functions (website repo, 20261018190000_organizer_guests.sql).
class OrganizerGuestService {
  OrganizerGuestService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<GuestSummary> summary(String eventId) => _rpc.one('organizer_guest_summary', {'p_event': eventId}, parseGuestSummary, 'the guest numbers');

  Future<List<Guest>> guests(String eventId, {String? query}) =>
      _rpc.list('organizer_guests', {'p_event': eventId, 'p_query': query == null || query.trim().isEmpty ? null : query.trim()}, parseGuest, 'guests');
}
