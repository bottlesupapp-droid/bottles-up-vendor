import '../../ops/services/ops_rpc.dart';
import '../../owner/services/db_errors.dart' show isMissingFunction, isNoAccess;
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/walkin_rules.dart';

/// The walk-in calls (website repo, 20261020140000_desk_walkin.sql). The database decides who may book one (the club's manager or owner), counts what is left
/// while it holds the table type, and refuses with a plain sentence; nothing here decides any of it.
class WalkinService {
  WalkinService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  /// The arrival times offered on [night] ('YYYY-MM-DD') with each table's seats, deposit and how many are left.
  Future<List<WalkinSlot>> options(String venueId, String night) async {
    final rows = <Map<String, dynamic>>[];
    try {
      rows.addAll(OpsRpc.rows(await _rpc.call('desk_walkin_options', {'p_venue': venueId, 'p_night': night})));
    } catch (error) {
      throw OpsLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error), what: 'the tables');
    }
    return parseWalkinOptions(rows);
  }

  Future<WalkinResult> create({
    required String venueId,
    required String night,
    required String tableTypeId,
    required String slotId,
    required int guests,
    int? hours,
    required String name,
    required String email,
    String phone = '',
  }) =>
      _rpc.act(() async {
        final data = await _rpc.call('desk_create_walkin', {
          'p_venue': venueId,
          'p_night': night,
          'p_table_type': tableTypeId,
          'p_slot': slotId,
          'p_guests': guests,
          'p_hours': hours,
          'p_name': name.trim(),
          'p_email': email.trim().toLowerCase(),
          'p_phone': phone.trim().isEmpty ? null : phone.trim(),
          'p_terms_confirmed': true,
        });
        final result = data is Map ? parseWalkinResult(Map<String, dynamic>.from(data)) : null;
        if (result == null) throw const OpsActionException('The booking could not be confirmed. Check the table\'s page before trying again.');
        return result;
      }, generic: 'The booking could not be made. Check your connection and try again. If you are not sure it went through, look for it on the Floor before booking again.');
}
