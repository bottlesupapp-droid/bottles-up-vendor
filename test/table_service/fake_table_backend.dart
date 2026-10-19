import 'dart:async';

import 'package:bottles_up_vendor/features/table_service/services/table_service_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) =>
    PostgrestException(message: message, code: 'P0001');

class FakeBooking {
  FakeBooking(
    this.id, {
    this.venueId = 'v1',
    this.night = '2026-10-09',
    this.table = 'VIP booth',
    this.customer = 'Ada Lovelace',
    this.code,
    this.guests = 4,
    this.status = 'paid',
    this.total = 10000,
    this.paid = 0,
    this.reconciled = false,
    this.closeoutRequested = false,
    this.checkedIn = false,
    this.nightClosed = false,
  });

  final String id;
  String venueId;
  String night;
  String table;
  String customer;
  String? code;
  int guests;
  String status;
  int total;
  int paid;
  bool reconciled;
  bool closeoutRequested;
  bool checkedIn;

  /// The business night this table is on has been closed (close night).
  bool nightClosed;

  int get balance => total > paid ? total - paid : 0;
}

class FakeLine {
  FakeLine(
    this.id,
    this.bookingId,
    this.name,
    this.orderedAt, {
    this.qty = 1,
    this.price = 5000,
    this.pay = 'paid',
    this.state = 'awaiting_prep',
    this.size = '750ml',
    this.addon = false,
    this.cancelled = false,
    this.reason,
    this.delivered = 0,
    this.bottleId,
  });

  final String id;
  final String bookingId;
  final String name;
  final int qty;
  final int price;
  final String? size;
  final bool addon;
  String pay;
  String state;
  bool cancelled;
  String? reason;
  int delivered;
  final String? bottleId;
  final DateTime orderedAt;
}

/// A bottle on the club's menu.
class FakeBottle {
  FakeBottle(this.id, this.name, this.price, {this.size = '750ml', this.category = 'Spirits', this.stock, this.available = true, this.soldOut = false});

  final String id;
  final String name;
  final int price;
  final String? size;
  final String? category;
  final int? stock;
  bool available;
  bool soldOut;
}

class FakePayment {
  FakePayment(
    this.id,
    this.bookingId,
    this.billed,
    this.paid,
    this.method,
    this.recordedAt, {
    this.pos,
    this.path,
    this.hash,
    this.reason,
    this.recordedBy = 'u-other',
    this.customerStatus = 'pending',
    this.verifiedAt,
    this.verifiedBy,
    this.note,
    this.dispute,
    this.payer,
    this.tip = 0,
  });

  final String id;
  final String bookingId;
  final int billed;
  final int paid;
  final String method;
  final String? pos;
  final String? path;
  final String? hash;
  final String? reason;
  final String? payer;
  final int tip;
  final DateTime recordedAt;
  String? recordedBy;
  String customerStatus;
  DateTime? verifiedAt;
  String? verifiedBy;
  String? note;
  String? dispute;
}

/// A stand-in for the website's table-service functions that behaves the way they do (website repo, 20261014120000_desk_orders.sql and
/// 20261014130000_desk_payments.sql): who may call what, which lines a server sees, every refusal and its own sentence (raised as
/// P0001), a repeated tap changing nothing, a receipt photo tied to its booking, nobody verifying their own entry. A test compares
/// every sentence it raises with the SQL, so the two cannot drift apart unnoticed.
class FakeTableBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];

  /// The caller: 'server', 'manager' (a manager or the owner), 'verifier' or 'none'.
  String role = 'server';
  String me = 'u-me';
  String myMembership = 'm-me';

  DateTime now = DateTime.utc(2026, 10, 9, 22);

  final Map<String, FakeBooking> bookings = {};
  final List<FakeLine> lines = [];
  final List<FakePayment> payments = [];

  /// booking id -> the membership it was given to.
  final Map<String, String> assignments = {};

  /// The club's bottle menu (desk_bottle_menu), in the club's order.
  final List<FakeBottle> menu = [];

  /// Failure to inject into the add-bottles function call (a FunctionException, a socket error...).
  Object? failInvoke;
  final List<(String, Map<String, dynamic>)> invocations = [];

  /// Open service requests of the club (the database counts them for Tonight).
  int openRequests = 0;

  Object? failAll;
  final Map<String, Object> failOn = {};
  void Function(String function)? beforeCall;
  Future<void>? hold;

  int _next = 1;
  String id(String p) => '$p${_next++}';

  TableServiceService get service => TableServiceService(rpc: call, invoker: invoke);

  FakeBooking addBooking(
    String id, {
    String? name,
    String night = '2026-10-09',
    String venue = 'v1',
    String? code,
    int total = 10000,
    int paid = 0,
    String status = 'paid',
    String table = 'VIP booth',
    int guests = 4,
  }) =>
      bookings[id] = FakeBooking(
        id,
        venueId: venue,
        night: night,
        customer: name ?? 'Ada Lovelace',
        code: code,
        total: total,
        paid: paid,
        status: status,
        table: table,
        guests: guests,
      );

  FakeLine addLine(
    String bookingId,
    String name, {
    String pay = 'paid',
    String state = 'awaiting_prep',
    int minutesAgo = 10,
    int qty = 1,
    int price = 5000,
    bool cancelled = false,
    String? reason,
    bool addon = false,
    String? lineId,
    int delivered = 0,
    String? bottleId,
  }) {
    final l = FakeLine(
      lineId ?? id('l'),
      bookingId,
      name,
      now.subtract(Duration(minutes: minutesAgo)),
      pay: pay,
      state: state,
      qty: qty,
      price: price,
      cancelled: cancelled,
      reason: reason,
      addon: addon,
      delivered: delivered,
      bottleId: bottleId,
    );
    lines.add(l);
    return l;
  }

  FakePayment addPayment(
    String bookingId,
    int paid, {
    String status = 'pending',
    String? by,
    DateTime? at,
    String? path,
    String? reason = 'seeded',
    String? pos,
    String? paymentId,
    String method = 'cash',
    String? dispute,
    bool verified = false,
    String? payer,
    int? billed,
    int tip = 0,
  }) {
    final p = FakePayment(
      paymentId ?? id('p'),
      bookingId,
      billed ?? paid,
      paid,
      method,
      at ?? now,
      path: path,
      reason: path == null ? reason : null,
      pos: pos,
      recordedBy: by ?? 'u-other',
      customerStatus: status,
      dispute: dispute,
      payer: payer,
      tip: tip,
    );
    if (verified) {
      p.verifiedAt = now;
      p.verifiedBy = 'u-checker';
    }
    payments.add(p);
    return p;
  }

  List<Map<String, dynamic>?> get params => [for (final c in calls) c.$2];
  List<String> get functions => [for (final c in calls) c.$1];
  int count(String function) => functions.where((f) => f == function).length;

  FakeLine line(String id) => lines.firstWhere((l) => l.id == id);

  // -------------------------------------------------------------------------------------------------------------------------

  String? _level(String bookingId) {
    final b = bookings[bookingId];
    if (b == null) return null;
    if (b.venueId != 'v1') return null;
    switch (role) {
      case 'manager':
        return 'manager';
      case 'server':
        return assignments[bookingId] == myMembership ? 'server' : null;
      case 'verifier':
        return 'verifier';
    }
    return null;
  }

  /// desk_level: 'manager', 'server' or null (a verifier is nothing here).
  String? _clubLevel(String venue) {
    if (venue != 'v1') return null;
    return role == 'manager' ? 'manager' : (role == 'server' ? 'server' : null);
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    final failing = failOn[function];
    if (failing != null) throw failing;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    switch (function) {
      case 'desk_orders':
        return _orders(p);
      case 'desk_booking_orders':
        return _bookingOrders(p);
      case 'desk_set_service_status':
        return _setStatus(p);
      case 'desk_booking_money':
        return _money(p);
      case 'desk_record_payment':
        return _record(p);
      case 'desk_pending_verifications':
        return _pending(p);
      case 'desk_verify_payment':
        return _verify(p);
      case 'desk_table_status':
        return _tableStatus(p);
      case 'desk_tonight':
        return _tonight(p);
      case 'desk_booking_deliveries':
        return _deliveries(p);
      case 'desk_deliver_part':
        return _deliverPart(p);
      case 'desk_bottle_menu':
        return _menu(p);
    }
    throw StateError('unexpected call to $function');
  }

  String? _trim(Object? v) {
    final t = (v as String?)?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Map<String, dynamic> _lineRow(FakeLine l, FakeBooking b) => {
    'line_id': l.id,
    'booking_id': b.id,
    'confirmation_code': b.code,
    'customer_name': b.customer,
    'table_name': b.table,
    'guest_count': b.guests,
    'bottle_name': l.name,
    'size': l.size,
    'quantity': l.qty,
    'line_total_cents': l.price * l.qty,
    'is_addon': l.addon,
    'payment_status': l.pay,
    'service_status': l.state,
    'ordered_at': l.orderedAt.toIso8601String(),
    'checked_in_at': b.checkedIn ? now.toIso8601String() : null,
    'balance_due_cents': b.balance,
    'server_membership_id': assignments[b.id],
    'server_is_me': assignments[b.id] == myMembership,
  };

  List<Map<String, dynamic>> _orders(Map<String, dynamic> p) {
    final venue = p['p_venue'] as String;
    final level = _clubLevel(venue);
    if (level == null) throw refuse('not allowed');
    final night = p['p_night'] as String?;
    if (night == null) throw refuse('choose a night');
    final rows = <(FakeLine, FakeBooking)>[
      for (final l in lines)
        if (bookings[l.bookingId] case final b?)
          if (b.venueId == venue &&
              b.status == 'paid' &&
              !b.reconciled &&
              b.night == night &&
              !l.cancelled &&
              l.pay != 'pending_payment' &&
              (level == 'manager' || assignments[b.id] == myMembership))
            (l, b),
    ];
    rows.sort((a, b) {
      final d =
          (a.$1.state == 'served' ? 1 : 0) - (b.$1.state == 'served' ? 1 : 0);
      if (d != 0) return d;
      return a.$1.orderedAt.compareTo(b.$1.orderedAt);
    });
    return [for (final r in rows.take(1000)) _lineRow(r.$1, r.$2)];
  }

  List<Map<String, dynamic>> _bookingOrders(Map<String, dynamic> p) {
    final bid = p['p_booking'] as String;
    final level = _level(bid);
    if (level == null || level == 'verifier') throw refuse('not allowed');
    final rows = [
      for (final l in lines)
        if (l.bookingId == bid && l.pay != 'pending_payment') l,
    ]..sort((a, b) => a.orderedAt.compareTo(b.orderedAt));
    return [
      for (final l in rows)
        {
          'line_id': l.id,
          'bottle_name': l.name,
          'size': l.size,
          'quantity': l.qty,
          'unit_price_cents': l.price,
          'line_total_cents': l.price * l.qty,
          'is_addon': l.addon,
          'payment_status': l.pay,
          'service_status': l.state,
          'ordered_at': l.orderedAt.toIso8601String(),
          'cancelled_at': l.cancelled ? now.toIso8601String() : null,
          'cancellation_reason': l.reason,
        },
    ];
  }

  bool _setStatus(Map<String, dynamic> p) {
    final status = p['p_status'] as String?;
    if (status == null ||
        !const [
          'awaiting_prep',
          'preparing',
          'ready',
          'picked_up',
          'served',
        ].contains(status)) {
      throw refuse('invalid status');
    }
    final line = lines.where((l) => l.id == p['p_line']).firstOrNull;
    final level = line == null ? null : _level(line.bookingId);
    if (line == null || level == null || level == 'verifier') {
      throw refuse('not allowed');
    }
    final b = bookings[line.bookingId]!;
    if (b.status != 'paid') {
      throw refuse('only a paid booking has orders to serve');
    }
    if (b.reconciled) throw refuse('this table has already been closed out');
    if (line.cancelled) throw refuse('this item was cancelled');
    if (line.pay == 'pending_payment') {
      throw refuse('payment not yet verified for this item');
    }
    if (line.state == status) return false;
    if (level == 'server' && line.state == 'served') {
      throw refuse('a delivered item can only be changed by a manager');
    }
    if (status == 'served' && line.pay == 'due_at_venue') {
      if (b.balance > 0) {
        throw refuse(
          'cannot mark delivered - this table still has a balance due at the venue',
        );
      }
      if (!payments.any((x) => x.bookingId == b.id)) {
        throw refuse(
          'cannot mark delivered - no payment has been recorded for this table',
        );
      }
    }
    line.state = status;
    return true;
  }

  // --- partial delivery and adding bottles (website 20261020150000_add_bottles_checks.sql and 20261020160000_partial_delivery.sql) ---

  List<Map<String, dynamic>> _deliveries(Map<String, dynamic> p) {
    final bid = p['p_booking'] as String;
    final level = _level(bid);
    if (level == null || level == 'verifier') throw refuse('not allowed');
    final rows = [
      for (final l in lines)
        if (l.bookingId == bid && l.pay != 'pending_payment') l,
    ]..sort((a, b) => a.orderedAt.compareTo(b.orderedAt));
    return [for (final l in rows) {'line_id': l.id, 'delivered_quantity': l.delivered}];
  }

  Map<String, dynamic> _deliverPart(Map<String, dynamic> p) {
    final line = lines.where((l) => l.id == p['p_line']).firstOrNull;
    final level = line == null ? null : _level(line.bookingId);
    if (line == null || level == null || level == 'verifier') throw refuse('not allowed');
    final b = bookings[line.bookingId]!;
    if (b.status != 'paid') throw refuse('only a paid booking has orders to serve');
    if (b.reconciled) throw refuse('this table has already been closed out');
    if (line.cancelled) throw refuse('this item was cancelled');
    if (line.pay == 'pending_payment') throw refuse('payment not yet verified for this item');
    if (line.state == 'served') throw refuse('this item has already been delivered');
    if (line.state != 'ready' && line.state != 'picked_up') throw refuse('this item is not ready to be delivered yet');
    if (p['p_already'] != line.delivered) throw refuse('someone else has just changed this item, look at it again');
    final qty = p['p_quantity'] as int?;
    if (qty == null || qty < 1) throw refuse('choose how many were delivered');
    if (qty > line.qty - line.delivered) throw refuse('only ${line.qty - line.delivered} of this item are left to deliver');
    if (line.pay == 'due_at_venue') {
      if (b.balance > 0) throw refuse('cannot mark delivered - this table still has a balance due at the venue');
      if (!payments.any((x) => x.bookingId == b.id)) throw refuse('cannot mark delivered - no payment has been recorded for this table');
    }
    line.delivered += qty;
    line.state = line.delivered >= line.qty ? 'served' : 'picked_up';
    return {'delivered': line.delivered, 'quantity': line.qty, 'service_status': line.state};
  }

  /// desk_may_add_bottles: who and when. Raises the sentence the database would raise.
  void _requireMayAddBottles(String bookingId) {
    final level = _level(bookingId);
    if (level == null || level == 'verifier') throw refuse('not allowed');
    final b = bookings[bookingId]!;
    if (b.status != 'paid') throw refuse('only a confirmed booking can have bottles added');
    if (b.reconciled) throw refuse('this table has already been closed out');
    if (b.nightClosed) throw refuse('this night has been closed, so no bottles can be added');
  }

  int _committed(String bottleId) {
    var n = 0;
    for (final l in lines) {
      if (l.bottleId == bottleId && (l.pay == 'paid' || l.pay == 'due_at_venue') && bookings[l.bookingId]?.status == 'paid') n += l.qty;
    }
    return n;
  }

  List<Map<String, dynamic>> _menu(Map<String, dynamic> p) {
    _requireMayAddBottles(p['p_booking'] as String);
    return [
      for (final m in menu)
        if (m.available && !m.soldOut)
          {
            'bottle_id': m.id,
            'name': m.name,
            'size': m.size,
            'category': m.category,
            'price_cents': m.price,
            'left_count': m.stock == null ? null : (m.stock! - _committed(m.id)).clamp(0, 1 << 30),
          },
    ];
  }

  /// The add-table-booking-bottles edge function for table staff: asks desk_may_add_bottles first, then checks the bottles and stock, adds due-at-the-club lines
  /// and raises the table's total.
  Future<dynamic> invoke(String name, Map<String, dynamic> body) async {
    invocations.add((name, body));
    final broken = failInvoke;
    if (broken != null) throw broken;
    final waiting = hold;
    if (waiting != null) await waiting;
    if (name != 'add-table-booking-bottles') throw StateError('unexpected function $name');
    final bid = body['booking_id'] as String;
    try {
      _requireMayAddBottles(bid);
    } on PostgrestException catch (e) {
      if (e.message == 'not allowed') throw FunctionException(status: 403, details: {'error': 'Forbidden'});
      throw FunctionException(status: 409, details: {'error': e.message});
    }
    final requested = (body['bottles'] as List).cast<Map<String, dynamic>>();
    if (requested.isEmpty) throw FunctionException(status: 400, details: {'error': 'Select at least one bottle'});
    final chosen = <(FakeBottle, int)>[];
    for (final r in requested) {
      final m = menu.where((x) => x.id == r['bottle_id']).firstOrNull;
      if (m == null || !m.available || m.soldOut) throw FunctionException(status: 400, details: {'error': 'One of the selected bottles is no longer available'});
      final qty = r['quantity'] as int;
      if (m.stock != null && _committed(m.id) + qty > m.stock!) throw FunctionException(status: 409, details: {'error': 'Not enough "${m.name}" left in stock'});
      chosen.add((m, qty));
    }
    final b = bookings[bid]!;
    for (final (m, qty) in chosen) {
      addLine(bid, m.name, pay: 'due_at_venue', qty: qty, price: m.price, addon: true, bottleId: m.id, minutesAgo: 0);
      b.total += m.price * qty;
    }
    return {'success': true, 'mode': 'due_at_venue'};
  }

  String _verification(FakePayment x) {
    if (x.customerStatus == 'disputed') return 'disputed';
    if (x.verifiedAt != null) return 'verified';
    if (x.customerStatus == 'confirmed') return 'customer_confirmed';
    return 'pending';
  }

  Map<String, dynamic> _money(Map<String, dynamic> p) {
    final bid = p['p_booking'] as String;
    final level = _level(bid);
    if (level == null) throw refuse('not allowed');
    final b = bookings[bid]!;
    final list = [
      for (final x in payments)
        if (x.bookingId == bid) x,
    ]..sort((a, c) => a.recordedAt.compareTo(c.recordedAt));
    return {
      'level': level,
      'confirmation_code': b.code,
      'customer_name': b.customer,
      'table_name': b.table,
      'guest_count': b.guests,
      'currency': 'cad',
      'status': b.status,
      'amount_total_cents': b.total,
      'amount_paid_cents': b.paid,
      'balance_due_cents': b.balance,
      'closed_out': b.reconciled,
      'closeout_requested': b.closeoutRequested,
      'payments': [
        for (final x in list)
          {
            'id': x.id,
            'billed_amount_cents': x.billed,
            'amount_paid_cents': x.paid,
            'payment_method': x.method,
            'pos_reference': x.pos,
            'receipt_photo_path': x.path,
            'missing_receipt_reason': x.reason,
            'payer_name': x.payer,
            'recorded_at': x.recordedAt.toIso8601String(),
            'recorded_by_me': x.recordedBy == me,
            'gratuity_cents': x.tip,
            'customer_confirmation_status': x.customerStatus,
            'manager_verified_at': x.verifiedAt?.toIso8601String(),
            'manager_verified_note': x.note,
            'verification': _verification(x),
          },
      ],
    };
  }

  Map<String, dynamic> _record(Map<String, dynamic> p) {
    final bid = p['p_booking'] as String;
    final level = _level(bid);
    if (level == null || level == 'verifier') throw refuse('not allowed');
    final method = p['p_payment_method'] as String?;
    if (method == null ||
        !const ['cash', 'debit', 'credit', 'split'].contains(method)) {
      throw refuse('choose how it was paid');
    }
    final nums = [
      p['p_billed_amount_cents'],
      p['p_amount_paid_cents'],
      p['p_bottle_subtotal_cents'],
      p['p_discount_cents'],
      p['p_tax_cents'],
      p['p_gratuity_cents'],
    ];
    if (nums.any((n) => n == null)) throw refuse('enter the amounts');
    final ints = nums.cast<int>();
    if (ints.any((n) => n < 0)) throw refuse('amounts cannot be negative');
    if (ints.any((n) => n > 10000000)) throw refuse('that amount is too large');
    final billed = ints[0];
    final paid = ints[1];
    if (paid == 0) throw refuse('enter the amount collected');
    final split = p['p_split_breakdown'];
    if (method == 'split' &&
        (split == null ||
            (split is! List && split is! Map) ||
            split.toString().length > 2000)) {
      throw refuse('say how the split was paid');
    }
    final pos = _trim(p['p_pos_reference']);
    if (pos != null && pos.length > 80) {
      throw refuse('the receipt number is too long');
    }
    final payer = _trim(p['p_payer_name']);
    if (payer != null && payer.length > 120) {
      throw refuse("the payer's name is too long");
    }
    final email = _trim(p['p_payer_email']);
    if (email != null &&
        (email.length > 200 || !RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(email))) {
      throw refuse('that email address does not look right');
    }
    final device = _trim(p['p_device_id']);
    if (device != null && device.length > 100) {
      throw refuse('the device id is too long');
    }
    var reason = _trim(p['p_missing_receipt_reason']);
    if (reason != null && reason.length > 300) {
      throw refuse('keep the reason to 300 characters or fewer');
    }
    final path = p['p_receipt_photo_path'] as String?;
    final hash = p['p_receipt_photo_hash'] as String?;
    if (path == null) {
      if (level != 'manager') throw refuse('a receipt photo is required');
      if (reason == null) {
        throw refuse('a reason is required when recording without a receipt');
      }
    } else {
      if (path.length > 300 ||
          !RegExp('^$bid/[^/].*\$').hasMatch(path) ||
          path.contains('..')) {
        throw refuse('the receipt photo does not belong to this booking');
      }
      reason = null;
      if (hash != null && !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
        throw refuse('the receipt photo could not be checked');
      }
    }
    final b = bookings[bid]!;
    if (b.status != 'paid') {
      throw refuse('only a confirmed booking can take a payment');
    }
    if (b.reconciled) throw refuse('this table has already been closed out');

    FakePayment? existing;
    if (path != null) {
      existing =
          payments
              .where((x) => x.bookingId == bid && x.path == path)
              .firstOrNull;
    } else {
      existing =
          payments
              .where(
                (x) =>
                    x.bookingId == bid &&
                    x.path == null &&
                    x.recordedBy == me &&
                    x.method == method &&
                    x.billed == billed &&
                    x.paid == paid &&
                    x.reason == reason &&
                    now.difference(x.recordedAt) < const Duration(minutes: 1),
              )
              .firstOrNull;
    }
    if (existing != null) {
      return {
        'success': true,
        'duplicate': true,
        'payment_id': existing.id,
        'new_amount_paid_cents': b.paid,
        'balance_due_cents': b.balance,
      };
    }

    bool sameClub(FakePayment x) => bookings[x.bookingId]?.venueId == b.venueId;
    if (pos != null && payments.any((x) => sameClub(x) && x.pos == pos)) {
      throw refuse(
        'this POS receipt number has already been recorded for another payment at this venue',
      );
    }
    if (hash != null && payments.any((x) => sameClub(x) && x.hash == hash)) {
      throw refuse(
        'this receipt photo has already been used for another payment at this venue',
      );
    }

    final payment = FakePayment(
      id('p'),
      bid,
      billed,
      paid,
      method,
      now,
      pos: pos,
      path: path,
      hash: hash,
      reason: reason,
      recordedBy: me,
      payer: payer,
      tip: ints[5],
    );
    payments.add(payment);
    b.paid = (b.paid + paid) > b.total ? b.total : b.paid + paid;
    return {
      'success': true,
      'duplicate': false,
      'payment_id': payment.id,
      'new_amount_paid_cents': b.paid,
      'balance_due_cents': b.balance,
    };
  }

  bool _isQueued(FakePayment x) =>
      x.customerStatus == 'disputed' ||
      (x.verifiedAt == null && x.customerStatus == 'pending');

  List<Map<String, dynamic>> _pending(Map<String, dynamic> p) {
    final venue = p['p_venue'] as String;
    if (venue != 'v1' || (role != 'manager' && role != 'verifier')) {
      throw refuse('not allowed');
    }
    final rows = [
      for (final x in payments)
        if (bookings[x.bookingId]?.venueId == venue && _isQueued(x)) x,
    ]..sort((a, c) {
      final d =
          (c.customerStatus == 'disputed' ? 1 : 0) -
          (a.customerStatus == 'disputed' ? 1 : 0);
      return d != 0 ? d : a.recordedAt.compareTo(c.recordedAt);
    });
    return [
      for (final x in rows.take(300))
        {
          'payment_id': x.id,
          'booking_id': x.bookingId,
          'confirmation_code': bookings[x.bookingId]!.code,
          'customer_name': bookings[x.bookingId]!.customer,
          'table_name': bookings[x.bookingId]!.table,
          'payment_method': x.method,
          'billed_amount_cents': x.billed,
          'amount_paid_cents': x.paid,
          'pos_reference': x.pos,
          'receipt_photo_path': x.path,
          'missing_receipt_reason': x.reason,
          'recorded_at': x.recordedAt.toIso8601String(),
          'recorded_by_name':
              x.recordedBy == me
                  ? 'Me Myself'
                  : (x.recordedBy == null ? null : 'Sam Server'),
          'recorded_by_me': x.recordedBy == me,
          'customer_confirmation_status': x.customerStatus,
          'dispute_reason': x.dispute,
        },
    ];
  }

  Map<String, dynamic> _verify(Map<String, dynamic> p) {
    final pay = payments.where((x) => x.id == p['p_payment']).firstOrNull;
    final b = pay == null ? null : bookings[pay.bookingId];
    if (pay == null ||
        b == null ||
        b.venueId != 'v1' ||
        (role != 'manager' && role != 'verifier')) {
      throw refuse('not allowed');
    }
    final note = _trim(p['p_note']);
    if (note != null && note.length > 300) {
      throw refuse('keep the note to 300 characters or fewer');
    }
    if (pay.verifiedAt != null) {
      throw refuse('this payment was already verified');
    }
    if (pay.recordedBy != null && pay.recordedBy == me) {
      throw refuse(
        'you recorded this payment, so someone else has to verify it',
      );
    }
    if (pay.customerStatus != 'pending') {
      throw refuse('the customer already responded to this payment');
    }
    pay.verifiedAt = now;
    pay.verifiedBy = me;
    pay.note = note;
    return {'success': true};
  }

  List<FakeBooking> _night(String venue, String night) => [
    for (final b in bookings.values)
      if (b.venueId == venue && b.status == 'paid' && b.night == night) b,
  ];

  List<Map<String, dynamic>> _tableStatus(Map<String, dynamic> p) {
    final venue = p['p_venue'] as String;
    final level = _clubLevel(venue);
    if (level == null) throw refuse('not allowed');
    final night = p['p_night'] as String?;
    if (night == null) throw refuse('choose a night');
    return [
      for (final b in _night(venue, night))
        if (level == 'manager' || assignments[b.id] == myMembership)
          {
            'booking_id': b.id,
            'balance_due_cents': b.balance,
            'items_open':
                lines
                    .where(
                      (l) =>
                          l.bookingId == b.id &&
                          !l.cancelled &&
                          l.pay != 'pending_payment' &&
                          l.state != 'served',
                    )
                    .length,
            'items_delivered':
                lines
                    .where(
                      (l) =>
                          l.bookingId == b.id &&
                          !l.cancelled &&
                          l.pay != 'pending_payment' &&
                          l.state == 'served',
                    )
                    .length,
            'payments_recorded':
                payments.where((x) => x.bookingId == b.id).length,
            'payments_unchecked':
                payments
                    .where((x) => x.bookingId == b.id && _isQueued(x))
                    .length,
            'closed_out': b.reconciled,
            'closeout_requested': b.closeoutRequested,
          },
    ];
  }

  List<Map<String, dynamic>> _tonight(Map<String, dynamic> p) {
    final venue = p['p_venue'] as String;
    if (_clubLevel(venue) != 'manager') throw refuse('not allowed');
    final night = p['p_night'] as String?;
    if (night == null) throw refuse('choose a night');
    final nb = _night(venue, night);
    final ln = [
      for (final l in lines)
        if (nb.any((b) => b.id == l.bookingId) &&
            !l.cancelled &&
            l.pay != 'pending_payment')
          l,
    ];
    final club = [
      for (final x in payments)
        if (bookings[x.bookingId]?.venueId == venue) x,
    ];
    return [
      {
        'tables': nb.length,
        'guests': nb.fold<int>(0, (s, b) => s + b.guests),
        'arrived': nb.where((b) => b.checkedIn).length,
        'without_server':
            nb.where((b) => !assignments.containsKey(b.id)).length,
        'with_balance': nb.where((b) => b.total > b.paid).length,
        'balance_due_cents': nb.fold<int>(0, (s, b) => s + b.balance),
        'orders_new': ln.where((l) => l.state == 'awaiting_prep').length,
        'orders_in_progress':
            ln
                .where(
                  (l) => const [
                    'preparing',
                    'ready',
                    'picked_up',
                  ].contains(l.state),
                )
                .length,
        'orders_delivered': ln.where((l) => l.state == 'served').length,
        'payments_to_check':
            club
                .where(
                  (x) => x.verifiedAt == null && x.customerStatus == 'pending',
                )
                .length,
        'payments_disputed':
            club.where((x) => x.customerStatus == 'disputed').length,
        'closeouts_requested':
            bookings.values
                .where(
                  (b) =>
                      b.venueId == venue &&
                      b.closeoutRequested &&
                      !b.reconciled,
                )
                .length,
        'requests_open': openRequests,
      },
    ];
  }
}
