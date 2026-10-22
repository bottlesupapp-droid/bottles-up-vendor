import 'package:bottles_up_vendor/features/refunds/services/refund_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeRefundBooking {
  FakeRefundBooking(
    this.id, {
    this.venue = 'v1',
    this.code = 'AB12CD',
    this.guest = 'Ada Lovelace',
    this.table = 'VIP booth',
    this.date = '2026-10-24',
    this.status = 'paid',
    this.paid = 10000,
    this.deposit = 10000,
    this.checkedIn = false,
    this.paidOnline = true,
    this.hours = 72.0,
    this.policy,
  });

  final String id;
  final String venue;
  final String code;
  final String guest;
  final String table;
  final String date;
  String status;
  int paid;
  final int deposit;
  final bool checkedIn;
  final bool paidOnline;
  final double hours;

  /// The policy the booking was made under ({tiers, no_refund_after_check_in, note}), or null.
  final Map<String, dynamic>? policy;
}

class FakeRefundRequest {
  FakeRefundRequest(this.id, this.booking, this.kind, this.reason, this.createdAt, {this.percent, this.suggested = 0});

  final String id;
  final String booking;
  final String kind;
  final String reason;
  final DateTime createdAt;
  final int? percent;
  final int suggested;
  String status = 'requested';
  int? approved;
  String? method;
  String? note;
  String? failure;
  String? refundId;
  String? reference;
  String? receipt;
}

/// The website's refund functions (20261023100000_refund_policy_and_requests.sql) and the cancel-table-booking edge function as a fake with the same checks, in the same order, and
/// the same sentences: only a manager of the club decides, a policy's rules are checked, a decision cannot refund more than is left, a refund above the policy needs a reason, a card
/// refund needs an online payment, a club refund is recorded once with a reference, and a repeated tap changes nothing. Ids: requests rq1.., bookings as given.
class FakeRefundBackend {
  /// 'manager' (a manager or owner of the club), 'server' or 'none'.
  String role = 'manager';

  /// The venue's policy as stored: null = never set.
  Map<String, dynamic>? stored;

  final Map<String, FakeRefundBooking> bookings = {};
  final List<FakeRefundRequest> requests = [];
  final List<(String, Map<String, dynamic>?)> calls = [];
  final List<(String, Map<String, dynamic>)> invocations = [];
  DateTime now = DateTime.utc(2026, 10, 21, 12);
  int _next = 0;

  Object? failAll;
  Object? failInvoke;
  void Function(String function)? beforeCall;
  Future<void>? hold;

  RefundService get service => RefundService(caller: call, invoker: invoke);

  List<Map<String, dynamic>> paramsOf(String function) => [for (final c in calls) if (c.$1 == function) c.$2 ?? const {}];

  FakeRefundBooking addBooking(String id, {FakeRefundBooking? like, String status = 'paid', int paid = 10000, int deposit = 10000, double hours = 72, bool paidOnline = true, bool checkedIn = false, Map<String, dynamic>? policy, String guest = 'Ada Lovelace'}) =>
      bookings[id] = FakeRefundBooking(id, status: status, paid: paid, deposit: deposit, hours: hours, paidOnline: paidOnline, checkedIn: checkedIn, policy: policy ?? _standard, guest: guest);

  static const Map<String, dynamic> _standard = {
    'tiers': [
      {'hours': 48, 'percent': 100},
      {'hours': 24, 'percent': 50},
    ],
    'no_refund_after_check_in': true,
    'note': null,
  };

  FakeRefundRequest addRequest(String booking, {String kind = 'guest', String reason = 'I am ill', int? percent = 100, int suggested = 10000}) {
    final r = FakeRefundRequest('rq${++_next}', booking, kind, reason, now.add(Duration(minutes: _next)), percent: percent, suggested: suggested);
    requests.add(r);
    return r;
  }

  void _manager() {
    if (role != 'manager') throw refuse('not allowed');
  }

  // --- the policy words ---------------------------------------------------------

  static List<String> lines(Map<String, dynamic>? p) {
    if (p == null) return ['This venue has not set a refund policy: refunds are decided by the venue.'];
    final tiers = [...(p['tiers'] as List).cast<Map<String, dynamic>>()]..sort((a, b) => (b['hours'] as int).compareTo(a['hours'] as int));
    final out = <String>[];
    if (tiers.isEmpty) {
      out.add('The deposit is not refundable.');
    } else {
      for (final t in tiers) {
        final h = t['hours'] as int;
        final pct = t['percent'] as int;
        final head = h == 0
            ? 'Cancel any time before you arrive: '
            : h % 24 == 0
                ? 'Cancel at least ${h ~/ 24} ${h == 24 ? 'day' : 'days'} before you arrive: '
                : 'Cancel at least $h ${h == 1 ? 'hour' : 'hours'} before you arrive: ';
        out.add('$head${pct == 100 ? 'the whole deposit is refunded.' : (pct == 0 ? 'no refund.' : '$pct% of the deposit is refunded.')}');
      }
      if ((tiers.last['hours'] as int) > 0) out.add('Later than that: no refund.');
    }
    if (p['no_refund_after_check_in'] != false) out.add('Once the guests have arrived there is no refund.');
    final note = (p['note'] as String?)?.trim() ?? '';
    if (note.isNotEmpty) out.add(note);
    return out;
  }

  int _left(FakeRefundBooking b, {String? except}) {
    final claimed = requests.where((r) => r.booking == b.id && (r.status == 'approved' || r.status == 'processing') && r.id != except).fold<int>(0, (a, r) => a + (r.approved ?? 0));
    final left = b.paid - claimed;
    return left < 0 ? 0 : left;
  }

  Map<String, dynamic> _suggestion(FakeRefundBooking b) {
    final p = b.policy;
    if (p == null) return {'percent': null, 'suggested_cents': 0, 'why': 'This booking was made without a refund policy, so the amount is the venue\'s decision.'};
    if (b.checkedIn && p['no_refund_after_check_in'] != false) {
      return {'percent': 0, 'suggested_cents': 0, 'why': 'The guests have already arrived, and the policy gives no refund after that.'};
    }
    final tiers = [...(p['tiers'] as List).cast<Map<String, dynamic>>()]..sort((a, c) => (c['hours'] as int).compareTo(a['hours'] as int));
    var pct = 0;
    for (final t in tiers) {
      if (b.hours >= (t['hours'] as int)) {
        pct = t['percent'] as int;
        break;
      }
    }
    final s = (b.deposit * pct / 100).floor();
    return {
      'percent': pct,
      'suggested_cents': s < _left(b) ? s : _left(b),
      'why': pct == 0 ? 'The notice given is shorter than the policy allows a refund for.' : 'The policy refunds $pct% of the deposit for this much notice.',
    };
  }

  FakeRefundBooking _booking(Object? id) {
    final b = bookings[id];
    if (b == null) throw refuse('not allowed');
    return b;
  }

  // --- the edge function ---------------------------------------------------------

  Future<dynamic> invoke(String name, Map<String, dynamic> body) async {
    invocations.add((name, body));
    final broken = failInvoke;
    if (broken != null) throw broken;
    final waiting = hold;
    if (waiting != null) await waiting;
    if (name != 'cancel-table-booking') throw StateError('unexpected function $name');
    if (role != 'manager') throw FunctionException(status: 403, details: {'error': 'Forbidden'});
    final reason = (body['reason'] as String?)?.trim() ?? '';
    if (reason.isEmpty) throw FunctionException(status: 400, details: {'error': 'A reason is required'});
    final b = bookings[body['booking_id']];
    if (b == null) throw FunctionException(status: 404, details: {'error': 'Booking not found'});
    if (b.status == 'cancelled') throw FunctionException(status: 400, details: {'error': 'This booking is already cancelled'});
    b.status = 'cancelled';
    return {'success': true, 'refund_suggested': b.paid > 0};
  }

  // --- the database functions ------------------------------------------------------

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    if (role == 'none') throw refuse('not authenticated');
    switch (function) {
      case 'venue_refund_policy':
        _manager();
        final s = stored;
        return [
          {
            'has_policy': s != null,
            'tiers': s?['tiers'] ?? [],
            'no_refund_after_check_in': s?['no_refund_after_check_in'] ?? true,
            'note': s?['note'],
            'lines': lines(s),
          },
        ];
      case 'save_venue_refund_policy':
        _manager();
        return _savePolicy(p['p_details'] as Map<String, dynamic>);
      case 'desk_refund_options':
        _manager();
        final b = _booking(p['p_booking']);
        final s = _suggestion(b);
        final open = requests.where((r) => r.booking == b.id && const {'requested', 'approved', 'processing'}.contains(r.status));
        return {
          'paid_cents': b.paid,
          'deposit_cents': b.deposit,
          'available_cents': _left(b),
          'hours_to_arrival': b.hours,
          'checked_in': b.checkedIn,
          'paid_online': b.paidOnline,
          'status': b.status,
          'policy_lines': lines(b.policy),
          'percent': s['percent'],
          'suggested_cents': s['suggested_cents'],
          'why': s['why'],
          'open_request_id': open.isEmpty ? null : open.first.id,
        };
      case 'desk_request_refund':
        _manager();
        final reason = ((p['p_reason'] as String?) ?? '').trim();
        if (reason.length < 3 || reason.length > 500) throw refuse('give a reason of 3 to 500 characters');
        final b = _booking(p['p_booking']);
        if (b.status != 'paid' && b.status != 'cancelled') throw refuse('only a confirmed or cancelled booking can be refunded');
        if (_left(b) <= 0) throw refuse('nothing is left to refund on this booking');
        if (requests.any((r) => r.booking == b.id && const {'requested', 'approved', 'processing'}.contains(r.status))) {
          throw refuse('a refund request for this booking is already open');
        }
        final s = _suggestion(b);
        return addRequest(b.id, kind: 'staff', reason: reason, percent: s['percent'] as int?, suggested: s['suggested_cents'] as int).id;
      case 'desk_refund_requests':
        _manager();
        final status = p['p_status'] as String?;
        if (status != null && !const {'requested', 'approved', 'declined', 'processing', 'completed', 'failed'}.contains(status)) throw refuse('unknown status');
        final list = [for (final r in requests) if (bookings[r.booking]!.venue == p['p_venue'] && (status == null || r.status == status)) r]
          ..sort((a, b) {
            final aw = a.status == 'requested' ? 0 : 1;
            final bw = b.status == 'requested' ? 0 : 1;
            return aw != bw ? aw - bw : b.createdAt.compareTo(a.createdAt);
          });
        return [
          for (final r in list)
            {
              'request_id': r.id,
              'booking_id': r.booking,
              'confirmation_code': bookings[r.booking]!.code,
              'guest_name': bookings[r.booking]!.guest,
              'table_name': bookings[r.booking]!.table,
              'booking_date': bookings[r.booking]!.date,
              'requested_by_kind': r.kind,
              'reason': r.reason,
              'status': r.status,
              'paid_cents': bookings[r.booking]!.paid,
              'available_cents': _left(bookings[r.booking]!, except: r.id),
              'policy_percent': r.percent,
              'suggested_cents': r.suggested,
              'approved_cents': r.approved,
              'method': r.method,
              'decision_note': r.note,
              'failure_note': r.failure,
              'decided_at': null,
              'created_at': r.createdAt.toIso8601String(),
              'completed_at': null,
              'refund_reference': r.reference,
              'refund_receipt_path': r.receipt,
            },
        ];
      case 'desk_decide_refund':
        _manager();
        return _decide(p);
      case 'desk_complete_club_refund':
        _manager();
        final r = requests.where((x) => x.id == p['p_request']).firstOrNull;
        if (r == null) throw refuse('not allowed');
        final ref = ((p['p_pos_reference'] as String?) ?? '').trim();
        final path = ((p['p_receipt_path'] as String?) ?? '').trim();
        if (r.status == 'completed') return r.refundId;
        if (r.status != 'approved' || r.method != 'club') throw refuse('only an approved refund that is paid back at the club can be recorded here');
        if (ref.isEmpty && path.isEmpty) throw refuse('add the terminal or receipt reference, or a photo of the receipt, as evidence');
        if (ref.length > 200) throw refuse('the reference is too long');
        if (path.isNotEmpty && (path.length > 300 || !path.startsWith('${r.booking}/') || path.contains('..'))) throw refuse('the receipt photo does not belong to this booking');
        final b = bookings[r.booking]!;
        b.paid = (b.paid - r.approved!) < 0 ? 0 : b.paid - r.approved!;
        r.status = 'completed';
        r.refundId = 'rf${++_next}';
        r.reference = ref.isEmpty ? null : ref;
        r.receipt = path.isEmpty ? null : path;
        return r.refundId;
    }
    throw StateError('unexpected call $function');
  }

  List<String> _savePolicy(Map<String, dynamic> d) {
    for (final k in d.keys) {
      if (!const {'tiers', 'no_refund_after_check_in', 'note'}.contains(k)) throw refuse('unknown field: $k');
    }
    final exists = stored != null;
    List<Map<String, dynamic>> tiers;
    if (d.containsKey('tiers')) {
      final raw = d['tiers'];
      if (raw is! List) throw refuse('the refund rules must be a list');
      if (raw.length > 6) throw refuse('a refund policy can have 6 rules at most');
      for (final t in raw) {
        if (t is! Map) throw refuse('each refund rule needs the hours of notice and the percent refunded');
        for (final k in t.keys) {
          if (k != 'hours' && k != 'percent') throw refuse('unknown field: $k');
        }
        final h = t['hours'];
        final pc = t['percent'];
        if (h != null && (h is! int)) throw refuse('the hours of notice must be a whole number');
        if (h is int && (h < 0 || h > 2160)) throw refuse('the hours of notice must be between 0 and 2160');
        if (pc != null && (pc is! int)) throw refuse('the percent refunded must be a whole number');
        if (pc is int && (pc < 0 || pc > 100)) throw refuse('the percent refunded must be between 0 and 100');
        if (h == null || pc == null) throw refuse('each refund rule needs the hours of notice and the percent refunded');
      }
      final hours = raw.map((t) => t['hours']).toList();
      if (hours.toSet().length != hours.length) throw refuse('two refund rules cannot have the same hours of notice');
      final sorted = [for (final t in raw) {'hours': t['hours'] as int, 'percent': t['percent'] as int}]..sort((a, b) => (b['hours'] as int).compareTo(a['hours'] as int));
      for (var i = 1; i < sorted.length; i++) {
        if ((sorted[i]['percent'] as int) > (sorted[i - 1]['percent'] as int)) {
          throw refuse('giving more notice cannot get less back: a rule with fewer hours cannot refund a larger percent');
        }
      }
      tiers = sorted;
    } else if (exists) {
      tiers = (stored!['tiers'] as List).cast<Map<String, dynamic>>();
    } else {
      throw refuse('set the refund rules (an empty list means the deposit is not refundable)');
    }
    final flag = d.containsKey('no_refund_after_check_in') ? d['no_refund_after_check_in'] : (stored?['no_refund_after_check_in'] ?? true);
    if (flag is! bool) throw refuse('no refund after arrival must be true or false');
    String? note;
    if (d.containsKey('note')) {
      final n = d['note'];
      if (n != null && n is! String) throw refuse('the note must be text');
      final t = (n as String?)?.trim();
      if (t != null && t.length > 300) throw refuse('the note must be 300 characters or fewer');
      note = t == null || t.isEmpty ? null : t;
    } else {
      note = stored?['note'] as String?;
    }
    stored = {'tiers': tiers, 'no_refund_after_check_in': flag, 'note': note};
    return lines(stored);
  }

  String _decide(Map<String, dynamic> p) {
    final r = requests.where((x) => x.id == p['p_request']).firstOrNull;
    if (r == null) throw refuse('not allowed');
    final note = ((p['p_note'] as String?) ?? '').trim();
    final noteOrNull = note.isEmpty ? null : note;
    if (r.status != 'requested') throw refuse('this request has already been decided');
    final approve = p['p_approve'];
    if (approve == null) throw refuse('approve or decline');
    if (noteOrNull != null && noteOrNull.length > 500) throw refuse('the note can be up to 500 characters');
    final b = bookings[r.booking]!;
    if (approve == false) {
      if (noteOrNull == null || noteOrNull.length < 3) throw refuse('say why the refund is declined, so the guest can be told');
      r.status = 'declined';
      r.note = noteOrNull;
      return 'declined';
    }
    final method = p['p_method'];
    final cents = p['p_amount_cents'] as int?;
    if (method != 'online' && method != 'club') throw refuse('choose how it is paid back: online, or at the club');
    if (cents == null || cents < 1) throw refuse('how much is refunded?');
    final left = _left(b, except: r.id);
    if (cents > left) throw refuse('only ${(left / 100).toStringAsFixed(2)} can still be refunded on this booking');
    if (method == 'online' && !b.paidOnline) throw refuse('there is no online payment on this booking to return; record a refund made at the club instead');
    if (cents > r.suggested && (noteOrNull == null || noteOrNull.length < 3)) {
      throw refuse('this is more than the refund policy suggests (${(r.suggested / 100).toStringAsFixed(2)}): say why');
    }
    r.status = 'approved';
    r.approved = cents;
    r.method = method as String;
    r.note = noteOrNull;
    return 'approved';
  }
}
