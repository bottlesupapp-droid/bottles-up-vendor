import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/cash_rules.dart';

/// The calls to the website's cash and flag functions (website repo, 20261018100000_cash_handover_and_flags.sql): `desk_cash_position`,
/// `desk_submit_handover`, `desk_list_handovers`, `desk_receive_handover`, `desk_flag_payment`, `desk_resolve_flag`, `desk_list_flags`
/// and `desk_verifier_summary`. The database decides who sees what (a server only their own cash), that cash is handed in once, and that
/// nobody counts their own handover.
class CashService {
  CashService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<CashLine>> position(String venueId, String night) =>
      _rpc.list('desk_cash_position', {'p_venue': venueId, 'p_night': night}, parseCashLine, 'cash figures');

  Future<List<Handover>> handovers(String venueId, String night) =>
      _rpc.list('desk_list_handovers', {'p_venue': venueId, 'p_night': night}, parseHandover, 'handovers');

  Future<VerifierSummary> summary(String venueId, String night) =>
      _rpc.one('desk_verifier_summary', {'p_venue': venueId, 'p_night': night}, parseVerifierSummary, 'the summary');

  Future<List<PaymentFlag>> flags(String venueId, {bool resolved = false}) =>
      _rpc.list('desk_list_flags', {'p_venue': venueId, 'p_status': resolved ? 'resolved' : 'open'}, parseFlag, 'flagged payments');

  /// Hands in [cents] of the cash this person holds. Returns the handover's id.
  Future<String> submit(String venueId, String night, int cents, {String note = ''}) => _rpc.act(() async {
        final id = await _rpc.call('desk_submit_handover', submitHandoverParams(venueId, night, cents, note));
        return id.toString();
      }, generic: 'The handover could not be sent. Check your connection and try again.');

  /// Says what was actually counted. Returns the difference in cents (counted minus handed in).
  Future<int> receive(String handoverId, int countedCents, {String note = ''}) => _rpc.act(() async {
        final data = await _rpc.call('desk_receive_handover', receiveHandoverParams(handoverId, countedCents, note));
        return data is Map ? (data['difference_cents'] as num?)?.toInt() ?? 0 : 0;
      }, generic: 'The count could not be saved. Check your connection and try again.');

  Future<void> flagPayment(String paymentId, String reason) => _rpc.act(() async {
        await _rpc.call('desk_flag_payment', {'p_payment': paymentId, 'p_reason': reason.trim()});
      }, generic: 'The payment could not be flagged. Check your connection and try again.');

  Future<void> resolveFlag(String flagId, String resolution, {String note = ''}) => _rpc.act(() async {
        await _rpc.call('desk_resolve_flag', {
          'p_flag': flagId,
          'p_resolution': resolution,
          'p_note': note.trim().isEmpty ? null : note.trim(),
        });
      }, generic: 'The flag could not be resolved. Check your connection and try again.');
}
