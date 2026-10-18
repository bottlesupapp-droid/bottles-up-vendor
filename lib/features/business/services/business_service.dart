import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/business_status.dart';

/// The businesses of the signed-in person with their verification state: the website's `my_businesses()`
/// (20261007100000_accounts_onboarding.sql). The database decides which businesses these are; nothing here decides anything.
class BusinessService {
  BusinessService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<BusinessStatus>> mine() => _rpc.list('my_businesses', const {}, parseBusinessStatus, 'your business');
}
