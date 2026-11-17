import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/settlement_adjustment_rules.dart';
import '../logic/settlement_rules.dart';

/// The calls to the website's settlement functions (website repo, 20261122120000_organizer_settlements.sql, and 20261125100000_settlement_adjustments.sql for the adjustments after payment). The database decides who may do each (the club's manager or owner, the owner
/// alone for approving and recording a payment, the organizer for questions and acknowledging), keeps the history, and works out the share; nothing here decides any of it.
/// A server without the migration makes a list or the detail an "unavailable" load failure, which the screens say in words.
class SettlementService {
  SettlementService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<SettlementRow>> forVenue(String venueId) => _rpc.list('settlements_for_venue', {'p_venue': venueId}, parseSettlementRow, 'the settlements');

  Future<List<SettlementRow>> forOrganizer(String orgId) => _rpc.list('settlements_for_organizer', {'p_org': orgId}, parseSettlementRow, 'the settlements');

  Future<SettlementDetail> detail(String agreementId) => _rpc.one('settlement_detail', {'p_agreement': agreementId}, parseSettlementDetail, 'the settlement figures');

  /// The club enters (or changes) the eligible bar sales and where they come from. Returns the settlement's id.
  Future<String> saveSales(String agreementId, int eligibleSalesCents, String source) => _rpc.act(() async {
    final data = await _rpc.call('settlement_save_sales', {'p_agreement': agreementId, 'p_eligible_sales_cents': eligibleSalesCents, 'p_note': source.trim()});
    return '$data';
  }, generic: 'The sales could not be saved. Check your connection and look at the settlement before trying again.');

  /// A signed change to the amount owed, with the reason. Returns what is owed now.
  Future<int> adjust(String settlementId, int deltaCents, String reason) => _rpc.act(() async {
    final data = await _rpc.call('settlement_adjust', {'p_settlement': settlementId, 'p_amount_cents': deltaCents, 'p_note': reason.trim()});
    return data is int ? data : int.tryParse('$data') ?? 0;
  }, generic: 'The adjustment could not be saved. Check your connection and look at the settlement before trying again.');

  Future<void> review(String settlementId) => _rpc.act(() async {
    await _rpc.call('settlement_review', {'p_settlement': settlementId});
  }, generic: 'This could not be done. Check your connection and look at the settlement before trying again.');

  Future<void> approve(String settlementId) => _rpc.act(() async {
    await _rpc.call('settlement_approve', {'p_settlement': settlementId});
  }, generic: 'This could not be done. Check your connection and look at the settlement before trying again.');

  /// Records a payment that was made OUTSIDE BottlesUp. Nothing is sent anywhere.
  Future<void> recordPayment(String settlementId, {required int amountCents, required DateTime paidOn, required String reference, String? evidence}) => _rpc.act(() async {
    await _rpc.call('settlement_record_payment', {
      'p_settlement': settlementId,
      'p_amount_cents': amountCents,
      'p_paid_on': _day(paidOn),
      'p_reference': reference.trim(),
      'p_evidence': evidence == null || evidence.trim().isEmpty ? null : evidence.trim(),
    });
  }, generic: 'The payment could not be recorded. Check your connection and look at the settlement before trying again.');

  Future<void> question(String settlementId, String reason) => _rpc.act(() async {
    await _rpc.call('settlement_question', {'p_settlement': settlementId, 'p_reason': reason.trim()});
  }, generic: 'The question could not be sent. Check your connection and try again.');

  Future<void> resolve(String settlementId, String answer) => _rpc.act(() async {
    await _rpc.call('settlement_resolve', {'p_settlement': settlementId, 'p_note': answer.trim()});
  }, generic: 'The answer could not be saved. Check your connection and try again.');

  /// Returns whether anything changed (acknowledging twice changes nothing).
  Future<bool> acknowledge(String settlementId) => _rpc.act(() async {
    final data = await _rpc.call('settlement_acknowledge', {'p_settlement': settlementId});
    return data == true;
  }, generic: 'This could not be recorded. Check your connection and try again.');

  // ---- adjustments after payment (a paid settlement is never changed: each is a separate record)

  /// The adjustments of one paid settlement, with the totals, the history and what the person may do about each.
  Future<SettlementAdjustments> adjustments(String agreementId) =>
      _rpc.one('settlement_adjustments', {'p_agreement': agreementId}, parseSettlementAdjustments, 'the adjustments after payment');

  /// For the lists: which agreements have adjustments, keyed by agreement. A list does not fail because a badge could not be read: an unreadable answer is "no badges".
  Future<Map<String, AdjustmentFlag>> adjustmentFlagsForVenue(String venueId) => _flags('settlement_adjustment_flags_for_venue', {'p_venue': venueId});

  Future<Map<String, AdjustmentFlag>> adjustmentFlagsForOrganizer(String orgId) => _flags('settlement_adjustment_flags_for_organizer', {'p_org': orgId});

  Future<Map<String, AdjustmentFlag>> _flags(String function, Map<String, dynamic> params) async {
    try {
      final flags = await _rpc.list(function, params, parseAdjustmentFlag, 'the adjustments');
      return {for (final f in flags) f.agreementId: f};
    } on OpsLoadException {
      return const {};
    }
  }

  /// The club's owner records an adjustment: [amountCents] is signed (a refund or a chargeback is a minus). Returns the new adjustment's id.
  Future<String> recordAdjustment(String settlementId, {required String kind, required int amountCents, required String reason, String? reference}) => _rpc.act(() async {
    final data = await _rpc.call('settlement_adjustment_record', {'p_settlement': settlementId, 'p_kind': kind, 'p_amount_cents': amountCents, 'p_reason': reason.trim(), 'p_ref': reference == null || reference.trim().isEmpty ? null : reference.trim()});
    return '$data';
  }, generic: 'The adjustment could not be recorded. Check your connection and look at the settlement before trying again.');

  Future<void> questionAdjustment(String adjustmentId, String reason) => _rpc.act(() async {
    await _rpc.call('settlement_adjustment_question', {'p_adjustment': adjustmentId, 'p_reason': reason.trim()});
  }, generic: 'The question could not be sent. Check your connection and try again.');

  Future<void> answerAdjustment(String adjustmentId, String answer) => _rpc.act(() async {
    await _rpc.call('settlement_adjustment_answer', {'p_adjustment': adjustmentId, 'p_note': answer.trim()});
  }, generic: 'The answer could not be saved. Check your connection and try again.');

  /// Returns whether anything changed (acknowledging twice changes nothing).
  Future<bool> acknowledgeAdjustment(String adjustmentId) => _rpc.act(() async {
    final data = await _rpc.call('settlement_adjustment_acknowledge', {'p_adjustment': adjustmentId});
    return data == true;
  }, generic: 'This could not be recorded. Check your connection and try again.');

  /// Records the payment that settles an adjustment, made OUTSIDE BottlesUp. Nothing is sent anywhere.
  Future<void> settleAdjustment(String adjustmentId, {required int amountCents, required DateTime paidOn, required String reference, String? evidence}) => _rpc.act(() async {
    await _rpc.call('settlement_adjustment_settle', {
      'p_adjustment': adjustmentId,
      'p_amount_cents': amountCents,
      'p_paid_on': _day(paidOn),
      'p_reference': reference.trim(),
      'p_evidence': evidence == null || evidence.trim().isEmpty ? null : evidence.trim(),
    });
  }, generic: 'The payment could not be recorded. Check your connection and look at the settlement before trying again.');

  /// The club chooses not to recover an amount the organizer was paid too much.
  Future<void> waiveAdjustment(String adjustmentId, String reason) => _rpc.act(() async {
    await _rpc.call('settlement_adjustment_waive', {'p_adjustment': adjustmentId, 'p_reason': reason.trim()});
  }, generic: 'This could not be saved. Check your connection and look at the settlement before trying again.');
}

/// The date the database expects, yyyy-mm-dd, from the local day chosen.
String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
