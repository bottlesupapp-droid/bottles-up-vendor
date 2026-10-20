import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/payout_rules.dart';

/// The payouts a business sees (website repo, 20261025100000_payout_settings_and_ledger.sql, `my_payouts`). Read only: BottlesUp sets the payout account, its percentage and the weekday
/// in the CMS, checks the details, makes each transfer and records it with a reference. The database lets only the business's owner or organizer read it.
class PayoutService {
  PayoutService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<MyPayouts> mine(String orgId) => _rpc.one('my_payouts', {'p_org': orgId}, (r) => parseMyPayouts(r), 'your payouts');
}
