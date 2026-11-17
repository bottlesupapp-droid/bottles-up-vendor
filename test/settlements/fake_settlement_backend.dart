import 'dart:async';

import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/settlements/services/settlement_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// A stand-in for the database's settlement functions: records every call, answers from [rows] and [detailJson], and lets a test change what the next answer is. It decides nothing: what the person
/// may do is whatever `can` says in the detail the test gives it, exactly as the database does.
class FakeSettlementBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];
  final Map<String, FutureOr<dynamic> Function(Map<String, dynamic>? params)> handlers = {};
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic> detailJson = detail();

  /// What the database says about the adjustments after payment of the settlement on screen (see [adjustmentsPayload]).
  Map<String, dynamic> adjustmentsJson = adjustmentsPayload();

  /// The two lists' badges (see [flagRow]).
  List<Map<String, dynamic>> flags = [];
  bool offline = false;
  bool missing = false;

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function public.$function does not exist', code: '42883');
    final handler = handlers[function];
    if (handler != null) return handler(params);
    return switch (function) {
      'settlements_for_venue' || 'settlements_for_organizer' => rows,
      'settlement_detail' => detailJson,
      'settlement_save_sales' => 's1',
      'settlement_adjust' => 35000,
      'settlement_review' => 'reviewed',
      'settlement_approve' => 'approved',
      'settlement_record_payment' => 'paid',
      'settlement_question' => 'disputed',
      'settlement_resolve' => 'estimated',
      'settlement_acknowledge' => true,
      'settlement_adjustments' => adjustmentsJson,
      'settlement_adjustment_flags_for_venue' || 'settlement_adjustment_flags_for_organizer' => flags,
      'settlement_adjustment_record' => 'x-new',
      'settlement_adjustment_question' => 'disputed',
      'settlement_adjustment_answer' => 'open',
      'settlement_adjustment_acknowledge' => true,
      'settlement_adjustment_settle' => 'settled',
      'settlement_adjustment_waive' => 'waived',
      _ => throw StateError('unexpected call $function'),
    };
  }

  SettlementService get service => SettlementService(rpc: OpsRpc(rpc: call));

  List<Map<String, dynamic>?> paramsOf(String function) => [
    for (final c in calls)
      if (c.$1 == function) c.$2,
  ];

  int count(String function) => calls.where((c) => c.$1 == function).length;
}

Map<String, dynamic> listRow({
  String agreement = 'a1',
  String event = 'Night One',
  String venue = 'Club A',
  String organizer = 'Night Events',
  String? status,
  String? settlement,
  int? payable,
  num percent = 10,
  int threshold = 500000,
  String formula = 'above_threshold',
}) => {
  'agreement_id': agreement,
  'event_id': 'e-$agreement',
  'event_title': event,
  'event_start': '2026-11-20T21:00:00Z',
  'venue_name': venue,
  'organizer_name': organizer,
  'agreement_status': 'active',
  'bar_percent': percent,
  'threshold_cents': threshold,
  'formula': formula,
  'settlement_id': settlement ?? (status == null ? null : 's-$agreement'),
  'status': status,
  'eligible_sales_cents': status == null ? null : 800000,
  'share_cents': status == null ? null : 30000,
  'adjustment_cents': status == null ? null : 0,
  'payable_cents': status == null ? null : (payable ?? 30000),
  'paid_on': status == 'paid' ? '2026-11-22' : null,
  'updated_at': '2026-11-21T10:00:00Z',
};

Map<String, dynamic> settlementJson({
  String status = 'estimated',
  int sales = 800000,
  int base = 300000,
  int share = 30000,
  int adjustment = 0,
  String? adjustmentNote,
  String? disputedReason,
  String? reviewedBy,
  String? approvedBy,
  int? paidAmount,
  String? paidOn,
  String? reference,
  String? evidence,
  String? ackAt,
}) => {
  'id': 's1',
  'status': status,
  'currency': 'cad',
  'eligible_sales_cents': sales,
  'sales_note': 'Closing report of Fri 14 Nov, reviewed',
  'base_cents': base,
  'share_cents': share,
  'adjustment_cents': adjustment,
  'adjustment_note': adjustmentNote,
  'payable_cents': share + adjustment,
  'entered_at': '2026-11-21T09:00:00Z',
  'entered_by_name': 'Mia Manager',
  'reviewed_at': reviewedBy == null ? null : '2026-11-21T10:00:00Z',
  'reviewed_by_name': reviewedBy,
  'approved_at': approvedBy == null ? null : '2026-11-21T11:00:00Z',
  'approved_by_name': approvedBy,
  'paid_amount_cents': paidAmount,
  'paid_on': paidOn,
  'payment_reference': reference,
  'payment_evidence': evidence,
  'paid_recorded_at': paidAmount == null ? null : '2026-11-22T12:00:00Z',
  'paid_recorded_by_name': paidAmount == null ? null : 'Olly Owner',
  'payment_label': status == 'paid' ? 'Recorded external payment' : null,
  'disputed_reason': disputedReason,
  'disputed_at': disputedReason == null ? null : '2026-11-21T12:00:00Z',
  'organizer_ack_at': ackAt,
  'organizer_ack_by_name': ackAt == null ? null : 'Olive Organizer',
  'updated_at': '2026-11-21T10:00:00Z',
};

Map<String, dynamic> logJson(
  String action, {
  String side = 'venue',
  String? from,
  String? to,
  int? amount,
  String? note,
  String by = 'Mia Manager',
  bool me = false,
  String at = '2026-11-21T09:00:00Z',
}) => {'at': at, 'side': side, 'action': action, 'from_status': from, 'to_status': to, 'amount_cents': amount, 'note': note, 'by_name': by, 'by_me': me};

/// The detail the database would give. [can] names what is true; everything else is false.
Map<String, dynamic> detail({
  String side = 'venue',
  Map<String, dynamic>? settlement,
  Set<String> can = const {},
  bool hasShare = true,
  String agreementStatus = 'active',
  List<Map<String, dynamic>> log = const [],
}) => {
  'agreement_id': 'a1',
  'side': side,
  'event_title': 'Night One',
  'event_start': '2026-11-20T21:00:00Z',
  'venue_name': 'Club A',
  'organizer_name': 'Night Events',
  'agreement_status': agreementStatus,
  'agreement_version': 1,
  'terms':
      hasShare
          ? {
            'bar_percent': 10,
            'threshold_cents': 500000,
            'formula': 'above_threshold',
            'eligible_revenue': 'bar sales net of tax',
            'refunds': 'deducted',
            'taxes_tips_fees': 'excluded',
            'settlement_timing': 'within 7 days',
          }
          : {'bar_percent': 0},
  'has_share': hasShare,
  'settlement': settlement,
  'log': log,
  'can': {
    for (final k in const ['save_sales', 'adjust', 'review', 'approve', 'record_payment', 'acknowledge', 'question', 'resolve']) k: can.contains(k),
  },
};

/// One adjustment after payment, as the database sends it. [can] names what is true for the person; everything else is false.
Map<String, dynamic> adjustmentJson({
  String id = 'x1',
  String kind = 'refund',
  int amount = -5000,
  String status = 'open',
  String reason = 'Refund of a Friday bottle',
  String? ref = 'RF-2201',
  Set<String> can = const {},
  String? disputedReason,
  String? ackAt,
  String? resolvedOn,
  String? resolutionReference,
  String? resolutionNote,
  String recordedBy = 'Olly Owner',
}) => {
  'id': id,
  'kind': kind,
  'amount_cents': amount,
  'direction': amount < 0 ? 'organizer_owes_club' : 'club_owes_organizer',
  'reason': reason,
  'source_ref': ref,
  'status': status,
  'recorded_at': '2026-11-24T10:00:00Z',
  'recorded_by_name': recordedBy,
  'disputed_reason': status == 'disputed' ? (disputedReason ?? 'Which bottle was refunded?') : null,
  'disputed_at': status == 'disputed' ? '2026-11-24T11:00:00Z' : null,
  'organizer_ack_at': ackAt,
  'organizer_ack_by_name': ackAt == null ? null : 'Olive Organizer',
  'resolved_amount_cents': status == 'settled' ? amount.abs() : null,
  'resolved_on': resolvedOn,
  'resolution_reference': resolutionReference,
  'resolution_note': status == 'waived' ? (resolutionNote ?? 'Not worth recovering') : resolutionNote,
  'resolved_at': status == 'settled' || status == 'waived' ? '2026-11-25T09:00:00Z' : null,
  'resolved_by_name': status == 'settled' || status == 'waived' ? 'Olly Owner' : null,
  'resolution_label': status == 'settled' ? 'Recorded external payment' : (status == 'waived' ? 'Not recovered' : null),
  'can': {for (final k in const ['acknowledge', 'question', 'answer', 'settle', 'waive']) k: can.contains(k)},
};

Map<String, dynamic> adjustmentLogJson(
  String action, {
  String adjustment = 'x1',
  String side = 'venue',
  int? amount,
  String? note,
  String by = 'Olly Owner',
  bool me = false,
  String at = '2026-11-24T10:00:00Z',
}) => {'adjustment_id': adjustment, 'at': at, 'side': side, 'action': action, 'from_status': null, 'to_status': null, 'amount_cents': amount, 'note': note, 'by_name': by, 'by_me': me};

/// What `settlement_adjustments` gives for a settlement: the totals are worked out from [items] the way the database works them out.
Map<String, dynamic> adjustmentsPayload({
  String side = 'venue',
  bool applies = true,
  int paid = 30000,
  List<Map<String, dynamic>> items = const [],
  List<Map<String, dynamic>> log = const [],
  bool canRecord = false,
  String settlementId = 's1',
}) {
  int sum(bool Function(Map<String, dynamic>) test) => [for (final i in items) if (test(i)) i['amount_cents'] as int].fold(0, (a, b) => a + b);
  bool open(Map<String, dynamic> i) => i['status'] == 'open' || i['status'] == 'disputed';
  final total = sum((_) => true);
  return {
    'agreement_id': 'a1',
    'settlement_id': applies ? settlementId : null,
    'side': side,
    'applies': applies,
    if (applies) ...{
      'currency': 'cad',
      'paid_amount_cents': paid,
      'paid_on': '2026-11-22',
      'count': items.length,
      'adjustments_cents': total,
      'net_cents': paid + total,
      'open_to_organizer_cents': sum((i) => open(i) && (i['amount_cents'] as int) > 0),
      'open_to_club_cents': -sum((i) => open(i) && (i['amount_cents'] as int) < 0),
    },
    'items': items,
    'log': log,
    'can': {'record': canRecord},
  };
}

Map<String, dynamic> flagRow({String agreement = 'a1', int count = 1, int open = 1, int toOrganizer = 0, int toClub = 5000}) => {
  'agreement_id': agreement,
  'adjustment_count': count,
  'open_count': open,
  'open_to_organizer_cents': toOrganizer,
  'open_to_club_cents': toClub,
};
