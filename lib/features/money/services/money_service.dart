import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/money_rules.dart';

/// The call to the website's owner money function (website repo, 20261018200000_owner_money.sql). Read-only; the owner only.
class MoneyService {
  MoneyService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<VenueMoney>> clubs(String orgId, String from, String to) =>
      _rpc.list('owner_money', {'p_org': orgId, 'p_from': from, 'p_to': to}, parseVenueMoney, 'the money figures');
}
