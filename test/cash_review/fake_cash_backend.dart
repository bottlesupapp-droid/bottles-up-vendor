import 'dart:async';

import 'package:bottles_up_vendor/features/cash_review/services/cash_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

String _dollars(int cents) => (cents / 100).toStringAsFixed(2);

class FakeHandover {
  FakeHandover(this.id, this.byUser, this.claimed, this.at, {this.note, this.status = 'submitted', this.counted, this.receivedBy, this.receiveNote});

  final String id;
  final String byUser;
  final int claimed;
  final DateTime at;
  final String? note;
  String status;
  int? counted;
  String? receivedBy;
  String? receiveNote;
}

class FakeFlag {
  FakeFlag(this.id, this.paymentId, this.customer, this.table, this.method, this.paid, this.reason, this.raisedBy, this.raisedAt,
      {this.status = 'open', this.resolution, this.resolutionNote, this.resolvedBy});

  final String id;
  final String paymentId;
  final String customer;
  final String table;
  final String method;
  final int paid;
  final String reason;
  final String raisedBy;
  final DateTime raisedAt;
  String status;
  String? resolution;
  String? resolutionNote;
  String? resolvedBy;
}

/// The database's cash and flag functions, as a fake. It answers with the same sentences the SQL raises, so a screen shows what the
/// real one would. [role] is who is signed in ('server', 'manager', 'owner' or 'verifier'); a server sees only their own cash.
class FakeCashBackend {
  FakeCashBackend({this.role = 'verifier', this.me = 'u-me'});

  String role;
  final String me;
  final Map<String, String> names = {'u-me': 'Me Myself', 'u-sam': 'Sam Server', 'u-bea': 'Bea Server'};

  /// Cash collected tonight, by person.
  final Map<String, int> collected = {};
  final List<FakeHandover> handovers = [];
  final List<FakeFlag> flags = [];
  final List<({String function, Map<String, dynamic>? params})> calls = [];

  /// Every call fails like a dropped connection.
  bool offline = false;

  /// The functions are not on this server.
  bool missing = false;

  int _seq = 0;
  DateTime now = DateTime(2026, 10, 9, 23, 30);

  bool get _all => role != 'server';
  bool get _canCount => role != 'server';
  bool get _canResolve => role == 'manager' || role == 'owner';

  int handedIn(String user) => handovers.where((h) => h.byUser == user).fold(0, (a, h) => a + h.claimed);
  int held(String user) => (collected[user] ?? 0) - handedIn(user);

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    switch (function) {
      case 'desk_cash_position':
        {
          final users = {...collected.keys, ...handovers.map((h) => h.byUser)}.where((u) => _all || u == me).toList()
            ..sort((a, b) => a == me ? -1 : (b == me ? 1 : held(b).compareTo(held(a))));
          return [
            for (final u in users)
              {
                'collector_name': names[u],
                'is_me': u == me,
                'collected_cents': collected[u] ?? 0,
                'handed_in_cents': handedIn(u),
                'held_cents': held(u) < 0 ? 0 : held(u),
              },
          ];
        }
      case 'desk_submit_handover':
        {
          final cents = params!['p_amount_cents'] as int?;
          if (cents == null || cents <= 0) throw refuse('enter the amount you are handing over');
          if (held(me) <= 0) throw refuse('you are not holding any cash for this night');
          if (cents > held(me)) throw refuse('you only hold ${_dollars(held(me))} for this night');
          final id = 'h${++_seq}';
          handovers.add(FakeHandover(id, me, cents, now, note: params['p_note'] as String?));
          return id;
        }
      case 'desk_list_handovers':
        return [
          for (final h in handovers.where((h) => _all || h.byUser == me))
            {
              'handover_id': h.id,
              'collector_name': names[h.byUser],
              'is_mine': h.byUser == me,
              'claimed_cents': h.claimed,
              'status': h.status,
              'submitted_at': h.at.toIso8601String(),
              'note': h.note,
              'received_by_name': h.receivedBy == null ? null : names[h.receivedBy],
              'received_at': h.status == 'acknowledged' ? now.toIso8601String() : null,
              'counted_cents': h.counted,
              'difference_cents': h.counted == null ? null : h.counted! - h.claimed,
              'receive_note': h.receiveNote,
            },
        ];
      case 'desk_receive_handover':
        {
          final h = handovers.where((h) => h.id == params!['p_handover']).firstOrNull;
          if (h == null || !_canCount) throw refuse('not allowed');
          if (h.status != 'submitted') throw refuse('this handover was already acknowledged');
          if (h.byUser == me) throw refuse('you handed this in, so someone else has to count it');
          final counted = params!['p_counted_cents'] as int?;
          if (counted == null || counted < 0) throw refuse('enter the amount you counted');
          final note = (params['p_note'] as String?)?.trim();
          if (counted != h.claimed && (note == null || note.length < 3)) {
            throw refuse('the amount counted differs from the amount handed in: say why');
          }
          h
            ..status = 'acknowledged'
            ..counted = counted
            ..receivedBy = me
            ..receiveNote = note;
          return {'difference_cents': counted - h.claimed, 'claimed_cents': h.claimed, 'counted_cents': counted};
        }
      case 'desk_list_flags':
        {
          if (!_canCount) throw refuse('not allowed');
          final status = params!['p_status'];
          return [
            for (final f in flags.where((f) => status == null || f.status == status))
              {
                'flag_id': f.id,
                'payment_id': f.paymentId,
                'booking_id': 'b-${f.paymentId}',
                'confirmation_code': 'AB12CD',
                'customer_name': f.customer,
                'table_name': f.table,
                'payment_method': f.method,
                'amount_paid_cents': f.paid,
                'reason': f.reason,
                'raised_by_name': names[f.raisedBy],
                'raised_by_me': f.raisedBy == me,
                'raised_at': f.raisedAt.toIso8601String(),
                'status': f.status,
                'resolution': f.resolution,
                'resolution_note': f.resolutionNote,
                'resolved_by_name': f.resolvedBy == null ? null : names[f.resolvedBy],
                'resolved_at': f.status == 'resolved' ? now.toIso8601String() : null,
              },
          ];
        }
      case 'desk_flag_payment':
        {
          if (!_canCount) throw refuse('not allowed');
          final reason = (params!['p_reason'] as String?)?.trim() ?? '';
          if (reason.length < 3) throw refuse('say what is wrong with this payment');
          final payment = params['p_payment'] as String;
          if (flags.any((f) => f.paymentId == payment && f.status == 'open')) throw refuse('this payment is already flagged');
          flags.add(FakeFlag('f${++_seq}', payment, 'Ada Lovelace', 'VIP booth', 'debit', 3000, reason, me, now));
          return 'f$_seq';
        }
      case 'desk_resolve_flag':
        {
          final f = flags.where((f) => f.id == params!['p_flag']).firstOrNull;
          if (f == null || !_canResolve) throw refuse('not allowed');
          if (f.status != 'open') throw refuse('this flag was already resolved');
          final resolution = params!['p_resolution'] as String?;
          final note = (params['p_note'] as String?)?.trim();
          if (resolution != 'confirmed_ok' && (note == null || note.length < 3)) throw refuse('say what was done');
          f
            ..status = 'resolved'
            ..resolution = resolution
            ..resolutionNote = note
            ..resolvedBy = me;
          return null;
        }
      case 'desk_verifier_summary':
        {
          if (!_canCount) throw refuse('not allowed');
          final acknowledged = handovers.where((h) => h.status == 'acknowledged');
          return [
            {
              'payments_recorded': 6,
              'payments_checked': 2,
              'payments_to_check': 4,
              'payments_disputed': 1,
              'checked_by_me': 1,
              'flags_open': flags.where((f) => f.status == 'open').length,
              'flags_resolved': flags.where((f) => f.status == 'resolved').length,
              'handovers_waiting': handovers.where((h) => h.status == 'submitted').length,
              'handovers_acknowledged': acknowledged.length,
              'cash_difference_cents': acknowledged.fold<int>(0, (a, h) => a + (h.counted! - h.claimed)),
            },
          ];
        }
    }
    throw StateError('unexpected call $function');
  }

  CashService get service => CashService(caller: call);
}
