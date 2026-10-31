import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/access_rules.dart';

/// The calls to the website's venue access functions (website repo, 20261117100000_agreement_access.sql). The database decides who may allow what, whether the agreement is in force, and what
/// each side may see; nothing here decides any of it.
class VenueAccessService {
  VenueAccessService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  /// The six things of one agreement. [side] says which side to read it as when the person is on both.
  Future<AgreementGrants> grants(String agreementId, {String? side}) =>
      _rpc.one('agreement_grants', {'p_agreement': agreementId, 'p_side': side}, parseAgreementGrants, 'what the club shares');

  /// The club allows or withdraws one thing. Returns whether anything changed.
  Future<bool> setGrant(String agreementId, AccessKey key, bool allowed) => _rpc.act(() async {
        final data = await _rpc.call('set_agreement_grant', {'p_agreement': agreementId, 'p_grant': key.value, 'p_allowed': allowed});
        return data == true;
      }, generic: 'That could not be saved. Check your connection and try again.');

  /// The organizer's "Your Venue Access": every open agreement of the business's events.
  Future<List<VenueAccessRow>> venueAccess(String orgId) => _rpc.list('organizer_venue_access', {'p_org': orgId}, parseVenueAccessRow, 'your venue access');

  /// The organizer's read-only Sales for one event.
  Future<EventSales> eventSales(String eventId) => _rpc.one('organizer_event_sales', {'p_event': eventId}, parseEventSales, 'the sales');
}
