import 'package:bottles_up_vendor/features/discounts/services/discount_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeConcession {
  FakeConcession(this.id, this.booking, this.kind, this.requestedBy, this.requestedRole, this.reason, this.createdAt, {this.percent, required this.amount, this.base, this.bottleId, this.bottleName, this.quantity, this.night = '2026-10-19'});

  final String id;
  final String booking;
  final String kind;
  final String requestedBy;
  final String requestedRole;
  final String reason;
  final DateTime createdAt;
  final int? percent;
  final int amount;
  final int? base;
  final String? bottleId;
  final String? bottleName;
  final int? quantity;
  final String night;
  String status = 'pending';
  String? decidedBy;
  String? decidedRole;
  String? note;
}

class FakeDiscountBooking {
  FakeDiscountBooking(this.id, {this.venue = 'v1', this.base = 20000, this.total = 30000, this.paid = 0, this.status = 'paid', this.reconciled = false, this.assignedToMe = true});

  final String id;
  final String venue;
  int base;
  int total;
  int paid;
  String status;
  bool reconciled;
  bool assignedToMe;
  int discount = 0;
}

/// The website's discount and free-bottle functions (20261024100000_staff_discounts_and_complimentary.sql) as a fake with the same checks, in the same order, and the same sentences:
/// nothing can be given until the owner has set limits (the owner needs none); within a person's own limit it is applied at once, above it it waits; a discount cannot be more than the
/// table's bottles or than the table still owes; discounts do not combine unless allowed; nobody approves their own request; a manager only approves within the manager's limit; a
/// free bottle that has been served cannot be taken back. Ids: concessions c1.., users as given.
class FakeDiscountBackend {
  /// 'owner', 'manager', 'server', 'verifier' or 'none'.
  String role = 'manager';
  String me = 'u-me';

  /// The club's limits: null = never set.
  Map<String, dynamic>? limits;

  final Map<String, FakeDiscountBooking> bookings = {};
  final List<FakeConcession> concessions = [];

  /// The bottle menu: id, name, size, price_cents, left_count.
  final List<Map<String, dynamic>> menu = [
    {'bottle_id': 'bt1', 'name': 'Patron', 'size': '750ml', 'category': 'Tequila', 'price_cents': 25000, 'left_count': 6},
    {'bottle_id': 'bt2', 'name': 'Grey Goose', 'size': null, 'category': 'Vodka', 'price_cents': 20000, 'left_count': null},
    {'bottle_id': 'bt3', 'name': 'Last One', 'size': null, 'category': null, 'price_cents': 10000, 'left_count': 1},
  ];

  /// Free bottle lines that were served (a served one cannot be taken back).
  final Set<String> served = {};

  final List<(String, Map<String, dynamic>?)> calls = [];
  DateTime now = DateTime.utc(2026, 10, 19, 22);
  int _next = 0;

  Object? failAll;
  void Function(String function)? beforeCall;
  Future<void>? hold;

  DiscountService get service => DiscountService(caller: call);

  List<Map<String, dynamic>> paramsOf(String function) => [for (final c in calls) if (c.$1 == function) c.$2 ?? const {}];

  FakeDiscountBooking addBooking(String id, {int base = 20000, int total = 30000, int paid = 0, String status = 'paid', bool assignedToMe = true}) =>
      bookings[id] = FakeDiscountBooking(id, base: base, total: total, paid: paid, status: status, assignedToMe: assignedToMe);

  FakeConcession addConcession(String booking, {String kind = 'discount', String by = 'u-other', String byRole = 'server', int amount = 5000, int? percent = 25, String status = 'pending', String bottle = 'Patron', int quantity = 1}) {
    final c = FakeConcession('c${++_next}', booking, kind, by, byRole, 'Regular guest', now.add(Duration(minutes: _next)),
        percent: kind == 'discount' ? percent : null, amount: amount, base: kind == 'discount' ? 20000 : null, bottleId: kind == 'free_bottle' ? 'bt1' : null, bottleName: kind == 'free_bottle' ? bottle : null, quantity: kind == 'free_bottle' ? quantity : null)
      ..status = status;
    concessions.add(c);
    return c;
  }

  // --- who is who -----------------------------------------------------------------

  String? _role(FakeDiscountBooking? b) {
    if (role == 'owner') return 'owner';
    if (role == 'manager') return 'manager';
    if (role == 'server' && b != null && b.assignedToMe) return 'server';
    return null;
  }

  String? _clubRole() => role == 'owner' ? 'owner' : (role == 'manager' ? 'manager' : null);

  FakeDiscountBooking _booking(Object? id) {
    final b = bookings[id];
    if (b == null) throw refuse('not allowed');
    return b;
  }

  int _serverUsed() => concessions.where((c) => c.kind == 'free_bottle' && c.status == 'applied' && c.requestedBy == me && c.requestedRole == 'server' && c.decidedBy == null).fold(0, (a, c) => a + c.quantity!);
  int _poolUsed() => concessions
      .where((c) => c.kind == 'free_bottle' && c.status == 'applied' && ((c.requestedRole == 'manager' && c.decidedBy == null) || c.decidedRole == 'manager'))
      .fold(0, (a, c) => a + c.quantity!);

  String _money(int cents) => (cents / 100).toStringAsFixed(2);

  void _bookingCheck(FakeDiscountBooking b) {
    if (b.status != 'paid') throw refuse('only a confirmed booking can have a discount or a free bottle');
    if (b.reconciled) throw refuse('this table has already been closed out');
  }

  void _apply(FakeConcession c) {
    final b = bookings[c.booking]!;
    if (c.kind == 'discount') {
      final due = (b.total - b.paid) < 0 ? 0 : b.total - b.paid;
      if (c.amount > due) throw refuse('a discount of ${_money(c.amount)} is more than this table still owes (${_money(due)})');
      b.discount += c.amount;
      b.total -= c.amount;
    }
  }

  // --- the calls -------------------------------------------------------------------

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
      case 'desk_concession_limits':
        final b = _booking(p['p_booking']);
        final r = _role(b);
        if (r == null) throw refuse('not allowed');
        final l = limits;
        return {
          'role': r,
          'limits_set': l != null || r == 'owner',
          'max_percent': r == 'owner' ? 100 : (r == 'manager' ? (l?['manager_max_percent'] ?? 0) : (l?['server_max_percent'] ?? 0)),
          'free_bottles_allowed': r == 'owner' ? null : (r == 'manager' ? (l?['manager_free_bottles_per_night'] ?? 0) : (l?['server_free_bottles_per_night'] ?? 0)),
          'free_bottles_used': r == 'owner' ? 0 : (r == 'manager' ? _poolUsed() : _serverUsed()),
          'allow_stacking': l?['allow_stacking'] ?? false,
          'bottle_subtotal_cents': b.base,
          'balance_due_cents': (b.total - b.paid) < 0 ? 0 : b.total - b.paid,
          'discounted_cents': b.discount,
        };
      case 'desk_booking_concessions':
        final b = _booking(p['p_booking']);
        if (_role(b) == null) throw refuse('not allowed');
        return [
          for (final c in concessions)
            if (c.booking == b.id)
              {
                'concession_id': c.id,
                'kind': c.kind,
                'percent': c.percent,
                'amount_cents': c.amount,
                'bottle_name': c.bottleName,
                'quantity': c.quantity,
                'status': c.status,
                'reason': c.reason,
                'requested_by_name': c.requestedBy == me ? 'Me Myself' : 'Sam Server',
                'requested_role': c.requestedRole,
                'decided_by_name': c.decidedBy == null ? null : 'Mo Manager',
                'decision_note': c.note,
                'created_at': c.createdAt.toIso8601String(),
              },
        ];
      case 'desk_bottle_menu':
        final b = _booking(p['p_booking']);
        if (_role(b) == null) throw refuse('not allowed');
        if (b.status != 'paid') throw refuse('only a confirmed booking can have bottles added');
        return [for (final m in menu) Map<String, dynamic>.from(m)];
      case 'desk_request_discount':
        return _requestDiscount(p);
      case 'desk_request_free_bottle':
        return _requestFreeBottle(p);
      case 'desk_pending_concessions':
        final r = _clubRole();
        if (r == null) throw refuse('not allowed');
        final l = limits;
        return [
          for (final c in concessions)
            if (c.status == 'pending' && bookings[c.booking]!.venue == p['p_venue'])
              {
                'concession_id': c.id,
                'booking_id': c.booking,
                'confirmation_code': 'AB12CD',
                'guest_name': 'Ada Lovelace',
                'table_name': 'VIP booth',
                'kind': c.kind,
                'percent': c.percent,
                'amount_cents': c.amount,
                'bottle_name': c.bottleName,
                'quantity': c.quantity,
                'reason': c.reason,
                'requested_by_name': c.requestedBy == me ? 'Me Myself' : 'Sam Server',
                'requested_role': c.requestedRole,
                'created_at': c.createdAt.toIso8601String(),
                'can_decide': c.requestedBy != me &&
                    (r == 'owner' ||
                        (r == 'manager' &&
                            ((c.kind == 'discount' && (c.amount * 100 / c.base!).ceil() <= (l?['manager_max_percent'] ?? 0)) ||
                                (c.kind == 'free_bottle' && _poolUsed() + c.quantity! <= (l?['manager_free_bottles_per_night'] ?? 0))))),
              },
        ];
      case 'desk_decide_concession':
        return _decide(p);
      case 'desk_void_concession':
        return _void(p);
      case 'venue_discount_limits':
        if (_clubRole() == null) throw refuse('not allowed');
        final l = limits;
        return [
          {
            'has_limits': l != null,
            'server_max_percent': l?['server_max_percent'] ?? 0,
            'manager_max_percent': l?['manager_max_percent'] ?? 0,
            'server_free_bottles_per_night': l?['server_free_bottles_per_night'] ?? 0,
            'manager_free_bottles_per_night': l?['manager_free_bottles_per_night'] ?? 0,
            'allow_stacking': l?['allow_stacking'] ?? false,
          },
        ];
      case 'save_venue_discount_limits':
        return _saveLimits(p);
    }
    throw StateError('unexpected call $function');
  }

  Map<String, dynamic> _saveLimits(Map<String, dynamic> p) {
    if (role != 'owner') throw refuse('not allowed');
    final d = p['p_details'] as Map<String, dynamic>;
    const keys = {'server_max_percent', 'manager_max_percent', 'server_free_bottles_per_night', 'manager_free_bottles_per_night', 'allow_stacking'};
    for (final k in d.keys) {
      if (!keys.contains(k)) throw refuse('unknown field: $k');
    }
    int? intOf(String key, String label, int max) {
      if (!d.containsKey(key)) return (limits?[key] as int?) ?? 0;
      final v = d[key];
      if (v == null) return null;
      if (v is! int) throw refuse('$label must be a whole number');
      if (v < 0 || v > max) throw refuse('$label must be between 0 and $max');
      return v;
    }

    final sp = intOf('server_max_percent', 'the server\'s discount limit', 100);
    final mp = intOf('manager_max_percent', 'the manager\'s discount limit', 100);
    final sf = intOf('server_free_bottles_per_night', 'the server\'s free bottles per night', 100);
    final mf = intOf('manager_free_bottles_per_night', 'the managers\' free bottles per night', 500);
    final stack = d.containsKey('allow_stacking') ? d['allow_stacking'] : (limits?['allow_stacking'] ?? false);
    if (stack is! bool) throw refuse('allow discounts to combine must be true or false');
    if (sp == null || mp == null || sf == null || mf == null) throw refuse('every limit needs a value');
    if (sp > mp) throw refuse('a server cannot be allowed a bigger discount than a manager');
    if (sf > mf) throw refuse('a server cannot be allowed more free bottles a night than the managers\' pool');
    limits = {'server_max_percent': sp, 'manager_max_percent': mp, 'server_free_bottles_per_night': sf, 'manager_free_bottles_per_night': mf, 'allow_stacking': stack};
    return limits!;
  }

  Map<String, dynamic> _requestDiscount(Map<String, dynamic> p) {
    final b = _booking(p['p_booking']);
    final r = _role(b);
    if (r == null) throw refuse('not allowed');
    final reason = ((p['p_reason'] as String?) ?? '').trim();
    if (reason.length < 3 || reason.length > 300) throw refuse('give a reason of 3 to 300 characters');
    _bookingCheck(b);
    final l = limits;
    if (r != 'owner' && l == null) throw refuse('discounts are not set up for this club yet: the owner sets the limits first');
    final base = b.base;
    if (base <= 0) throw refuse('there are no bottles on this table to discount');
    final kind = p['p_kind'];
    final value = p['p_value'] as int?;
    int amount;
    if (kind == 'percent') {
      if (value == null || value < 1 || value > 100) throw refuse('a percent discount is between 1 and 100');
      amount = (base * value / 100).floor();
      if (amount < 1) throw refuse('that discount is less than one cent');
    } else if (kind == 'amount') {
      if (value == null || value < 1) throw refuse('how much is the discount?');
      if (value > base) throw refuse('a discount cannot be more than the table\'s bottles (${_money(base)})');
      amount = value;
    } else {
      throw refuse('choose a percent or an amount');
    }
    final pct = (amount * 100 / base).ceil();
    final due = (b.total - b.paid) < 0 ? 0 : b.total - b.paid;
    if (amount > due) throw refuse('a discount of ${_money(amount)} is more than this table still owes (${_money(due)})');
    if (!(l?['allow_stacking'] ?? false) && concessions.any((c) => c.booking == b.id && c.kind == 'discount' && (c.status == 'applied' || c.status == 'pending'))) {
      throw refuse('this table already has a discount: discounts do not combine at this club');
    }
    final myMax = r == 'owner' ? 100 : (r == 'manager' ? l!['manager_max_percent'] as int : l!['server_max_percent'] as int);
    final status = pct <= myMax ? 'applied' : 'pending';
    final c = FakeConcession('c${++_next}', b.id, 'discount', me, r, reason, now.add(Duration(minutes: _next)), percent: kind == 'percent' ? value : null, amount: amount, base: base)..status = status;
    concessions.add(c);
    if (status == 'applied') _apply(c);
    return {'id': c.id, 'status': status, 'amount_cents': amount, 'percent': pct};
  }

  Map<String, dynamic> _requestFreeBottle(Map<String, dynamic> p) {
    final b = _booking(p['p_booking']);
    final r = _role(b);
    if (r == null) throw refuse('not allowed');
    final reason = ((p['p_reason'] as String?) ?? '').trim();
    if (reason.length < 3 || reason.length > 300) throw refuse('give a reason of 3 to 300 characters');
    final qty = p['p_quantity'] as int?;
    if (qty == null || qty < 1 || qty > 100) throw refuse('how many bottles?');
    _bookingCheck(b);
    final l = limits;
    if (r != 'owner' && l == null) throw refuse('free bottles are not set up for this club yet: the owner sets the limits first');
    final bt = menu.where((m) => m['bottle_id'] == p['p_bottle']).firstOrNull;
    if (bt == null) throw refuse('bottle not found');
    String status;
    if (r == 'owner') {
      status = 'applied';
    } else if (r == 'manager') {
      status = _poolUsed() + qty <= (l!['manager_free_bottles_per_night'] as int) ? 'applied' : 'pending';
    } else {
      status = _serverUsed() + qty <= (l!['server_free_bottles_per_night'] as int) ? 'applied' : 'pending';
    }
    if (status == 'applied' && bt['left_count'] != null && qty > (bt['left_count'] as int)) {
      throw refuse('only ${bt['left_count']} of that bottle are left');
    }
    final value = (bt['price_cents'] as int) * qty;
    final c = FakeConcession('c${++_next}', b.id, 'free_bottle', me, r, reason, now.add(Duration(minutes: _next)), amount: value, bottleId: bt['bottle_id'] as String, bottleName: bt['name'] as String, quantity: qty)
      ..status = status;
    concessions.add(c);
    return {'id': c.id, 'status': status, 'value_cents': value};
  }

  String _decide(Map<String, dynamic> p) {
    final c = concessions.where((x) => x.id == p['p_id']).firstOrNull;
    if (c == null) throw refuse('not allowed');
    final r = _clubRole();
    if (r == null) throw refuse('not allowed');
    if (c.status != 'pending') throw refuse('this request has already been decided');
    final approve = p['p_approve'];
    if (approve == null) throw refuse('approve or decline');
    final note = ((p['p_note'] as String?) ?? '').trim();
    final n = note.isEmpty ? null : note;
    if (n != null && n.length > 300) throw refuse('the note can be up to 300 characters');
    if (c.requestedBy == me) throw refuse('you cannot approve your own request: another manager or the owner decides');
    if (approve == false) {
      if (n == null || n.length < 3) throw refuse('say why it is declined, so the person can be told');
      c.status = 'declined';
      c.decidedBy = me;
      c.decidedRole = r;
      c.note = n;
      return 'declined';
    }
    final l = limits;
    if (r == 'manager') {
      if (c.kind == 'discount' && (c.amount * 100 / c.base!).ceil() > (l?['manager_max_percent'] ?? 0)) throw refuse('this is more than a manager may approve: the owner decides');
      if (c.kind == 'free_bottle' && _poolUsed() + c.quantity! > (l?['manager_free_bottles_per_night'] ?? 0)) {
        throw refuse('this is more than the managers\' free bottles for the night: the owner decides');
      }
    }
    final b = bookings[c.booking]!;
    _bookingCheck(b);
    if (c.kind == 'discount' && !(l?['allow_stacking'] ?? false) && concessions.any((o) => o.booking == c.booking && o.kind == 'discount' && o.status == 'applied' && o.id != c.id)) {
      throw refuse('this table already has a discount: discounts do not combine at this club');
    }
    c.status = 'applied';
    c.decidedBy = me;
    c.decidedRole = r;
    c.note = n;
    _apply(c);
    return 'applied';
  }

  String _void(Map<String, dynamic> p) {
    final c = concessions.where((x) => x.id == p['p_id']).firstOrNull;
    if (c == null) throw refuse('not allowed');
    if (_clubRole() == null) throw refuse('not allowed');
    final note = ((p['p_note'] as String?) ?? '').trim();
    if (c.status == 'voided') return 'voided';
    if (c.status != 'applied') throw refuse('only something that has been applied can be taken back');
    if (note.length < 3) throw refuse('say why it is taken back');
    final b = bookings[c.booking]!;
    if (b.reconciled) throw refuse('this table has already been closed out');
    if (c.kind == 'discount') {
      b.discount = (b.discount - c.amount) < 0 ? 0 : b.discount - c.amount;
      b.total += c.amount;
    } else if (served.contains(c.id)) {
      throw refuse('that bottle has already been served, so it cannot be taken back');
    }
    c.status = 'voided';
    c.note ??= note;
    return 'voided';
  }
}
