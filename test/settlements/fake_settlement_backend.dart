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
