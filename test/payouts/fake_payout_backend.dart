import 'package:bottles_up_vendor/features/payouts/services/payout_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// The website's `my_payouts` (20261025100000_payout_settings_and_ledger.sql) as a fake with the same access rule (only the business's owner or organizer) and the same answer shape.
class FakePayoutBackend {
  /// 'owner', 'organizer', 'manager' or 'none'.
  String role = 'owner';
  String orgKind = 'venue_owner';
  Map<String, dynamic> account = {'status': 'ready', 'account_holder': 'Club Co Inc.', 'masked_account': '•••• 1234', 'note': null};
  Map<String, dynamic> settings = {
    'payout_method': 'manual_transfer',
    'commission_set': true,
    'commission_bps': 1250,
    'payout_weekday': 3,
    'hold_days': 2,
    'next_payout_on': '2026-10-28',
    'own_arrangement': false,
  };
  Map<String, dynamic>? waiting = {'bookings': 3, 'gross_cents': 45000};
  List<Map<String, dynamic>> items = [];
  final List<(String, Map<String, dynamic>?)> calls = [];
  Object? failAll;
  void Function(String function)? beforeCall;

  PayoutService get service => PayoutService(caller: call);

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    if (role == 'none') throw refuse('not authenticated');
    if (function != 'my_payouts') throw StateError('unexpected call $function');
    if (role != 'owner' && role != 'organizer') throw refuse('not allowed');
    return {'org_kind': orgKind, 'account': account, 'settings': settings, 'waiting': orgKind == 'venue_owner' ? waiting : null, 'items': items};
  }

  static Map<String, dynamic> item(String id, {String status = 'paid', int gross = 100000, int commission = 12500, int adjustment = 0, String? note, String? reference = 'TRF-1001', String? failure, String? expected}) => {
        'id': id,
        'period_start': '2026-10-05',
        'period_end': '2026-10-11',
        'gross_cents': gross,
        'commission_cents': commission,
        'adjustments_cents': adjustment,
        'adjustment_note': note,
        'net_cents': gross - commission + adjustment,
        'status': status,
        'expected_on': expected,
        'reference': reference,
        'paid_at': status == 'paid' ? '2026-10-14T15:00:00Z' : null,
        'failure_note': failure,
      };
}
