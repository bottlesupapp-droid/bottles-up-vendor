import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/refund_rules.dart';

/// The refund calls (website repo, 20261023100000_refund_policy_and_requests.sql, and the cancel-table-booking edge function). The database decides who may do what (the club's
/// manager or owner), what can still be refunded, and refuses with a plain sentence; nothing here decides any of it. Money is never moved from the app: an approved refund to a card is
/// returned by BottlesUp through Stripe, and one paid back at the club is only recorded here once it has been paid.
class RefundService {
  RefundService({OpsRpc? rpc, RpcCaller? caller, EdgeInvoker? invoker}) : _rpc = rpc ?? OpsRpc(rpc: caller, invoker: invoker);

  final OpsRpc _rpc;

  // --- the policy (owner or manager) -------------------------------------------

  Future<RefundPolicy> policy(String venueId) => _rpc.one('venue_refund_policy', {'p_venue': venueId}, parseRefundPolicy, 'the refund policy');

  /// Saves the policy and answers with the sentences a guest will read.
  Future<List<String>> savePolicy(String venueId, RefundPolicyForm form) => _rpc.act(() async {
        final data = await _rpc.call('save_venue_refund_policy', {'p_venue': venueId, 'p_details': policyPayload(form)});
        return data is List ? [for (final l in data) l.toString()] : const <String>[];
      }, generic: 'The refund policy could not be saved. Check your connection and try again.');

  // --- the requests (club manager or owner) -------------------------------------

  /// The venue's requests, waiting ones first. [status] null = all of them.
  Future<List<RefundRequest>> requests(String venueId, {RefundStatus? status}) =>
      _rpc.list('desk_refund_requests', {'p_venue': venueId, 'p_status': status?.db}, parseRefundRequest, 'the refund requests');

  /// What the booking's own policy says right now and what can still be refunded.
  Future<RefundOptions> options(String bookingId) => _rpc.one('desk_refund_options', {'p_booking': bookingId}, (r) => parseRefundOptions(r), 'the refund details');

  /// Records that a refund is wanted (the guest asked at the club, or the venue offers one). Nothing is paid back until it is approved and returned.
  Future<String> ask(String bookingId, String reason) => _rpc.act(() async {
        final id = await _rpc.call('desk_request_refund', {'p_booking': bookingId, 'p_reason': reason.trim()});
        if (id is String && id.isNotEmpty) return id;
        throw const OpsActionException('We could not tell whether the request was recorded. Look at the booking before trying again.');
      }, generic: 'The refund request could not be recorded. Check your connection and look at the booking before trying again.');

  /// Approves (an amount and how it is paid back) or declines (a reason) a waiting request. Answers 'approved' or 'declined'.
  Future<String> decide(String requestId, DecisionForm form, RefundRequest request, {required bool paidOnline}) => _rpc.act(() async {
        final found = validateDecision(form, request, paidOnline: paidOnline);
        if (found.isNotEmpty) throw OpsActionException(found.first);
        final data = await _rpc.call('desk_decide_refund', decisionParams(requestId, form));
        if (data == 'approved' || data == 'declined') return data as String;
        throw const OpsActionException('We could not tell whether the decision was recorded. Look at the request before trying again.');
      }, generic: 'The decision could not be recorded. Check your connection and look at the request before trying again.');

  /// The venue paid the money back at the club: records it with the terminal or receipt reference and/or the receipt photo (already uploaded to [receiptPath]), and the booking's paid
  /// amount goes down. A repeated call changes nothing.
  Future<void> completeClubRefund(String requestId, String reference, {String? receiptPath}) => _rpc.act(() async {
        final problem = validateClubReference(reference, hasPhoto: receiptPath != null);
        if (problem != null) throw OpsActionException(problem);
        final ref = reference.trim();
        await _rpc.call('desk_complete_club_refund', {'p_request': requestId, 'p_pos_reference': ref.isEmpty ? null : ref, 'p_receipt_path': receiptPath});
      }, generic: 'The refund could not be recorded. Check your connection and look at the request before trying again.');

  // --- cancelling a booking ------------------------------------------------------

  /// Cancels a booking through the website's edge function (it keeps the paid bottle lines and the reason). Answers whether money had been paid on it, so a refund can be decided.
  /// A call that got no answer, or failed on the server, may have gone through: [OpsActionException] then says to look at the booking first.
  Future<bool> cancelBooking(String bookingId, String reason) async {
    final problem = validateCancelReason(reason);
    if (problem != null) throw OpsActionException(problem);
    try {
      final data = await _rpc.invoke('cancel-table-booking', {'booking_id': bookingId, 'reason': reason.trim()});
      if (data is Map && data['success'] == true) return data['refund_suggested'] == true;
      throw OpsActionException(cancelFailure());
    } on OpsActionException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] is String ? details['error'] as String : (details is String ? details : null);
      throw OpsActionException(cancelFailure(status: e.status, message: message));
    } catch (_) {
      throw OpsActionException(cancelFailure());
    }
  }
}
